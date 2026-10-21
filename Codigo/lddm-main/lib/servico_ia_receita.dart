import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meu_app/models/profile.dart';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/servico_recomendacao.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServicoIAReceita {
  late String geminiApiKey;

  ServicoIAReceita() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GEMINI_API_KEYS'] ?? '';
    geminiApiKey = key.replaceAll('"', '').replaceAll("'", '').trim();
  }

  /// Gera uma receita usando IA baseada no perfil nutricional do usuário
  Future<Map<String, dynamic>?> gerarReceitaComIA(Profile profile) async {
    try {
      print('⏳ Iniciando geração de receita com IA para ${profile.firstName}...');

      final receitaFormatada = await _gerarReceitaComRetry(
        profile,
        userId: profile.userId,
        maxTentativas: 3,
      );

      if (receitaFormatada == null) {
        throw Exception('Não foi possível gerar uma receita válida após 3 tentativas.');
      }

      print('5️⃣ Salvando receita nas recomendações...');
      final servicoRecomendacao = ServicoRecomendacao();
      await servicoRecomendacao.adicionarReceitaIA(receitaFormatada);

      print('   ✅ Receita salva!');
      return receitaFormatada;
    } catch (e) {
      rethrow;
    }
  }

  /// Retry automático — tenta gerar receita até [maxTentativas] vezes
  Future<Map<String, dynamic>?> _gerarReceitaComRetry(
    Profile profile, {
    required int userId,
    int maxTentativas = 3,
  }) async {
    final db = DatabaseHelper();
    final servicoRecomendacao = ServicoRecomendacao();
    List<String> existingNames = [];

    try {
      final userRecipes = await db.getRecipesByUserId(userId);
      existingNames.addAll(userRecipes.map((r) => _normalize(r.name ?? '')));
    } catch (e) {
      print('⚠️ Não foi possível buscar receitas do usuário: $e');
    }
    try {
      final iaList = await servicoRecomendacao.getRecomendacoes();
      existingNames.addAll(
        iaList.map((r) => _normalize(r['nome']?.toString() ?? r['name']?.toString() ?? '')),
      );
    } catch (e) {
      print('⚠️ Não foi possível buscar receitas IA existentes: $e');
    }

    existingNames = existingNames.toSet().where((n) => n.isNotEmpty).toList();

    for (int tentativa = 1; tentativa <= maxTentativas; tentativa++) {
      try {
        print('🔄 Tentativa $tentativa/$maxTentativas...');

        final receita = await _pedirReceitaAoGemini(profile, existingNames);

        if (receita != null) {
          print('   ✅ Receita gerada com sucesso: ${receita['nome']}');
          return receita;
        }

        if (tentativa < maxTentativas) {
          print('   🔄 Resposta inválida, tentando novamente...');
          await Future.delayed(const Duration(seconds: 2));
        }
      } catch (e) {
        print('   ❌ Erro na tentativa $tentativa: $e');
        if (tentativa < maxTentativas) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    return null;
  }

  /// Pede uma receita completa diretamente ao Gemini em uma única requisição
  Future<Map<String, dynamic>?> _pedirReceitaAoGemini(
    Profile profile,
    List<String> existingRecipeNames,
  ) async {
    try {
      final restricoes = profile.restrictions.isEmpty ? 'Nenhuma' : profile.restrictions;

      final buffer = StringBuffer();
      buffer.writeln('Você é um nutricionista e chef de cozinha brasileiro.');
      buffer.writeln('Crie UMA receita saudável com ingredientes fáceis de encontrar em qualquer supermercado do Brasil.');
      buffer.writeln('');
      buffer.writeln('PERFIL NUTRICIONAL DO USUÁRIO:');
      buffer.writeln('- Objetivo: ${profile.nutritionalGoal}');
      buffer.writeln('- Restrições alimentares: $restricoes');
      buffer.writeln('- Nível de atividade física: ${profile.activityLevel}');
      buffer.writeln('- Idade: ${profile.age} anos');
      buffer.writeln('');
      buffer.writeln('REGRAS OBRIGATÓRIAS:');
      buffer.writeln('1. Use apenas ingredientes comuns e baratos no Brasil (ex: arroz, feijão, frango, ovos, legumes, etc).');
      buffer.writeln('2. A receita deve ser fácil de preparar, com no máximo 10 passos simples.');
      buffer.writeln('3. A receita deve ajudar diretamente no objetivo: ${profile.nutritionalGoal}.');
      buffer.writeln('4. Respeite TODAS as restrições alimentares declaradas.');

      if (existingRecipeNames.isNotEmpty) {
        buffer.writeln('5. NÃO crie uma receita com nome igual ou muito parecido com estas que já existem:');
        for (final name in existingRecipeNames.take(20)) {
          buffer.writeln('   - $name');
        }
      }

      buffer.writeln('');
      buffer.writeln('FORMATO DE RESPOSTA OBRIGATÓRIO:');
      buffer.writeln('Retorne APENAS o JSON abaixo, sem nenhum texto antes ou depois, sem markdown, sem blocos de código:');
      buffer.writeln('{');
      buffer.writeln('  "nome": "Nome da receita em português",');
      buffer.writeln('  "categoria": "Café da manhã | Almoço | Jantar | Lanche | Sobremesa",');
      buffer.writeln('  "ingredientes": [');
      buffer.writeln('    "quantidade + ingrediente (ex: 2 ovos)",');
      buffer.writeln('    "quantidade + ingrediente"');
      buffer.writeln('  ],');
      buffer.writeln('  "modo_preparo": [');
      buffer.writeln('    "Passo 1: descrição clara",');
      buffer.writeln('    "Passo 2: descrição clara"');
      buffer.writeln('  ],');
      buffer.writeln('  "restricoes": "liste aqui as restrições atendidas, ou Nenhuma"');
      buffer.writeln('}');

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$geminiApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': buffer.toString()}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String responseText =
            data['candidates'][0]['content']['parts'][0]['text'].toString().trim();

        // Remove qualquer marcação markdown que o modelo possa ter incluído
        responseText = responseText.replaceAll(RegExp(r'```json\s*'), '');
        responseText = responseText.replaceAll(RegExp(r'```\s*'), '');
        responseText = responseText.trim();

        final receitaFormatada = jsonDecode(responseText) as Map<String, dynamic>;

        // Valida que os campos essenciais estão presentes
        if (receitaFormatada['nome'] == null ||
            receitaFormatada['ingredientes'] == null ||
            receitaFormatada['modo_preparo'] == null) {
          print('   ⚠️ JSON retornado está incompleto.');
          return null;
        }

        return receitaFormatada;
      } else {
        print('❌ Status Gemini: ${response.statusCode}');
        print('❌ Body: ${response.body}');
        throw Exception('Erro ao chamar Gemini: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao pedir receita ao Gemini: $e');
      return null;
    }
  }

  String _normalize(String s) {
    String t = s.toLowerCase().trim();
    final replacements = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    replacements.forEach((k, v) {
      t = t.replaceAll(k, v);
    });
    t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }
}