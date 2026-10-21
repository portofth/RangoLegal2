import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'servico_recomendacao.dart'; // Importa nossa lógica
import 'package:meu_app/notification_service.dart';
import 'main.dart'; // Para acessar a tela de detalhes
import 'package:meu_app/models/recipe.dart';

const Color corAmareloPrincipal = Color(0xFFFBC02D);

class RecomendacaoScreen extends StatefulWidget {
  const RecomendacaoScreen({super.key});

  @override
  State<RecomendacaoScreen> createState() => _RecomendacaoScreenState();
}

class _RecomendacaoScreenState extends State<RecomendacaoScreen> with WidgetsBindingObserver {
  late Future<List<Map<String, dynamic>>> _recomendacoes;
  late final StreamSubscription<String> _notifSub;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicia o processo de obter as recomendações
    _carregarRecomendacoes();
    // Inscreve para eventos globais (perfil/receitas atualizadas)
    _notifSub = NotificationService.instance.stream.listen((event) {
      if (event == 'profile_updated' || event == 'receitas_updated' || event == 'recipes_db_updated') {
        // Debounce reloads to avoid setState during build or spamming
        _reloadDebounce?.cancel();
        _reloadDebounce = Timer(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          _carregarRecomendacoes();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }

  void _carregarRecomendacoes() {
    _recomendacoes = ServicoRecomendacao().getRecomendacoes();
    // schedule setState after frame to be safe if currently building
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quando a tela reaparece após navegar para outra, recarrega
      _carregarRecomendacoes();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recarrega as recomendações sempre que a tela aparecer
    _carregarRecomendacoes();
  }

  // Função para construir imagem da receita (suporta múltiplos tipos)
  Widget _buildRecipeImage(Map<String, dynamic> receita) {
    final imagemPath = receita['imagem'];
    
    if (imagemPath == null || imagemPath.isEmpty) {
      return _buildFallbackAvatar(receita);
    }

    // Se for asset (começa com 'assets/')
    if (imagemPath.contains('assets/')) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[200],
        backgroundImage: AssetImage(imagemPath),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback silencioso
        },
        child: _buildFallbackAvatar(receita),
      );
    }
    // Se for URL de rede (http/https)
    else if (imagemPath.startsWith('http://') || imagemPath.startsWith('https://')) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(
          imagemPath,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          },
        ),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback silencioso
        },
        child: _buildFallbackAvatar(receita),
      );
    }
    // Se for Base64 (web)
    else if (imagemPath.startsWith('data:image/')) {
      try {
        final base64Data = imagemPath.split(',').last;
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          backgroundImage: MemoryImage(base64Decode(base64Data)),
          child: _buildFallbackAvatar(receita),
        );
      } catch (e) {
        return _buildFallbackAvatar(receita);
      }
    }
    
    return _buildFallbackAvatar(receita);
  }

  Widget _buildFallbackAvatar(Map<String, dynamic> receita) {
    final nome = (receita['nome'] ?? '?') as String;
    return Text(
      nome.isNotEmpty ? nome[0].toUpperCase() : '?',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recomendações para Você',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: corAmareloPrincipal,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      // FutureBuilder é perfeito para lidar com dados que demoram a chegar
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recomendacoes,
        builder: (context, snapshot) {
          // 1. Enquanto os dados estão carregando, mostra um indicador de progresso
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // 2. Se deu algum erro
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar recomendações: ${snapshot.error}'));
          }
          // 3. Se os dados chegaram com sucesso, mas a lista está vazia
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nenhuma recomendação encontrada para seu perfil.'));
          }

          // 4. Se tudo deu certo, mostra a lista
          final receitas = snapshot.data!;
          return ListView.builder(
            itemCount: receitas.length,
            itemBuilder: (context, index) {
              final receita = receitas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12.0),
                  leading: _buildRecipeImage(receita),
                  title: Text(receita['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(receita['categoria']),
                  onTap: () {
                    // Converte o mapa de receita para o modelo Recipe temporário
                    final tempRecipe = Recipe(
                      id: null,
                      name: receita['nome'] ?? 'Receita',
                      preparationMode: (receita['modo_preparo'] is List)
                          ? (receita['modo_preparo'] as List).join('\n')
                          : (receita['modo_preparo']?.toString() ?? ''),
                      ingredients: (receita['ingredientes'] is List)
                          ? (receita['ingredientes'] as List).join('\n')
                          : (receita['ingredientes']?.toString() ?? ''),
                      restrictions: receita['restricoes'] ?? '',
                      imagePath: receita['imagem'],
                      userId: 0,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalheReceitaScreen(receita: tempRecipe),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}