import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meu_app/notification_service.dart';

class ServicoRecomendacao {
  // Chave para armazenar lista de receitas IA geradas
  static const String keyReceitasIA = 'receitas_ia_geradas';

  // Função principal que retorna a lista de receitas recomendadas
  Future<List<Map<String, dynamic>>> getRecomendacoes() async {
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> receitasRecomendadas = [];

    // 1. Carrega todas as receitas IA geradas (acumuladas)
    final receitasIAJson = prefs.getString(keyReceitasIA);
    if (receitasIAJson != null) {
      try {
        final List<dynamic> receitasList = jsonDecode(receitasIAJson);
        for (var receitaJson in receitasList) {
          final receita = Map<String, dynamic>.from(receitaJson as Map);
          receita['pontuacao'] = 999; // Coloca todas as IA no topo
          receitasRecomendadas.add(receita);
        }
      } catch (e) {
        print('Erro ao carregar receitas IA: $e');
      }
    }

    return receitasRecomendadas;
  }

  // Adiciona uma nova receita gerada pela IA à lista
  Future<void> adicionarReceitaIA(Map<String, dynamic> novaReceita) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Carrega as receitas existentes
    List<Map<String, dynamic>> receitasExistentes = [];
    final receitasIAJson = prefs.getString(keyReceitasIA);
    
    if (receitasIAJson != null) {
      try {
        final List<dynamic> receitasList = jsonDecode(receitasIAJson);
        receitasExistentes = List<Map<String, dynamic>>.from(
          receitasList.map((r) => Map<String, dynamic>.from(r as Map))
        );
      } catch (e) {
        print('Erro ao carregar receitas existentes: $e');
      }
    }

    // 2. Verifica duplicidade por nome (normalizado) e não adiciona se já existir
    final normalize = (String s) {
      var t = s.toLowerCase().trim();
      t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), '');
      t = t.replaceAll(RegExp(r'\s+'), ' ');
      return t;
    };
    final nomeNovo = (novaReceita['nome'] ?? novaReceita['name'] ?? '').toString();
    final nomeNovoNorm = normalize(nomeNovo);
    final exists = receitasExistentes.any((r) {
      final n = (r['nome'] ?? r['name'] ?? '').toString();
      return normalize(n) == nomeNovoNorm;
    });
    if (exists) {
      print('⚠️ Receita IA duplicada não adicionada: $nomeNovo');
      return;
    }

    // 3. Adiciona a nova receita no início da lista
    receitasExistentes.insert(0, novaReceita);

    // 3. Salva novamente (limit de 10 receitas para não ficar muito grande)
    if (receitasExistentes.length > 10) {
      receitasExistentes = receitasExistentes.sublist(0, 10);
    }

    await prefs.setString(keyReceitasIA, jsonEncode(receitasExistentes));
    print('✅ Receita IA adicionada à lista (total: ${receitasExistentes.length})');
    // Notifica a UI que a lista de receitas IA foi atualizada
    try {
      NotificationService.instance.notify('receitas_updated');
    } catch (e) {}
  }

  // Limpa todas as receitas IA geradas
  Future<void> limparReceitasIA() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyReceitasIA);
    print('🗑️ Receitas IA limpas');
  }
}