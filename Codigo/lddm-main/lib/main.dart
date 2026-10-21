import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'dart:io';
import 'dart:convert' show base64Decode;
import 'dart:async';

// Importa todos os nossos arquivos de tela e lógica
import 'theme_provider.dart';
import 'perfil_screen.dart';
import 'perfil_list_screen.dart';
import 'recomendacao_screen.dart';
import 'configuracoes_screen.dart';
// import 'splash_screen.dart'; // Tela inicial | NOTE: No necessary anymore
import 'servico_recomendacao.dart'; // Adicionado para mockup
import 'servico_ia_receita.dart'; // Importar o serviço de IA
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/recipe.dart';
import 'package:meu_app/models/category.dart';
import 'package:meu_app/models/profile.dart'; // Adicionado para o modelo de Perfil
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe_form.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'category_management_screen.dart';
import 'notification_service.dart';

// Cores personalizadas
const Color corAmareloClaro = Color(0xFFFFFDE7);
const Color corAmareloPrincipal = Color(0xFFFBC02D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().initializeHive();
  await dotenv.load(fileName: ".env"); // Carrega as chaves | TODO: Remove this properly
  
  // remover dps
  //  faz coisas de mockup
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('userId', 1);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'RangoLegal',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: corAmareloPrincipal, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: corAmareloPrincipal, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const HomePage(),
        );
      },
    );
  }
}

// =====================================================
// ================== HomePage ========================
// =====================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _gerandoComIA = false;
  

  late PageController _pageController;

  static const List<Widget> _widgetOptions = <Widget>[
    TelaReceitas(),
    RecomendacaoScreen(),
    PerfilListScreen(),
    ConfiguracoesScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {

    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _gerarReceitaComIA() async {
    if (_gerandoComIA) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;

    if (userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      return;
    }

    final db = DatabaseHelper();
    final profiles = await db.getProfilesByUserId(userId);

    // Verifica se existe algum perfil criado
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, crie um perfil nutricional primeiro.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Profile selectedProfile = profiles.first;

    // Se tiver mais de um perfil, abre um dialog para o usuário escolher
    if (profiles.length > 1) {
      final Profile? chosen = await showDialog<Profile>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Selecione o Perfil Nutricional'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final p = profiles[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: corAmareloPrincipal,
                      child: Text(
                        p.firstName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${p.firstName} ${p.lastName}'),
                    subtitle: Text(p.nutritionalGoal),
                    onTap: () {
                      Navigator.pop(context, p);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      );

      // Se o usuário fechar o dialog sem escolher, cancelamos a geração
      if (chosen == null) return;
      selectedProfile = chosen;
    }

    setState(() => _gerandoComIA = true);

    try {
      print('⏳ Iniciando geração de receita com IA...');
      final servicoIA = ServicoIAReceita();
      
      // Agora passamos o perfil selecionado para o serviço
      final receitaIA = await servicoIA.gerarReceitaComIA(selectedProfile);

      if (receitaIA != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receita gerada com IA com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _selectedIndex = 1; // Vai para aba de recomendações
          _gerandoComIA = false;
        });

        _pageController.jumpToPage(1);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao gerar receita com IA'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _gerandoComIA = false);
      }
    } catch (e) {
      print('❌ Erro ao gerar receita: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _gerandoComIA = false);
    }
  }

  void _handleFabPress() {
    switch (_selectedIndex) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecipeForm()),
        );
        break;
      case 1:
        // Gerar receita com IA
        _gerarReceitaComIA();
        break;
      case 2:
        // Abrir formulário de novo perfil nutricional
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PerfilNutricionalScreen(key: UniqueKey())),
        );
        break;
      case 3:
        break;
    }
  }

  final iconList = <IconData>[
    Icons.list_alt_outlined,
    Icons.star_outline,
    Icons.person_outline,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final navBarBackgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final appBarBackgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: appBarBackgroundColor,
        title: const Text(
          'RangoLegal',
          style: TextStyle(
            fontFamily: 'Pacifico',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: corAmareloPrincipal,
          ),
        ),
      ),

      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _widgetOptions,
      ),
      floatingActionButton: _selectedIndex == 3
          ? null
          : FloatingActionButton(
              onPressed: _gerandoComIA ? null : _handleFabPress,
              backgroundColor: corAmareloPrincipal,
              shape: const CircleBorder(),
              heroTag: null,
              child: _gerandoComIA && _selectedIndex == 1
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        strokeWidth: 2,
                      ),
                    )
                  : (_selectedIndex == 1
                      ? const Icon(Icons.auto_awesome, color: Colors.black)
                      : const Icon(Icons.add, color: Colors.black)),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          return Icon(
            iconList[index],
            size: 24,
            color: isActive
                ? corAmareloPrincipal
                : (isDarkMode ? Colors.white70 : Colors.grey.shade600),
          );
        },
        activeIndex: _selectedIndex,
        gapLocation: _selectedIndex == 3 ? GapLocation.none : GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        onTap: _onItemTapped,
        backgroundColor: navBarBackgroundColor,
      ),
    );
  }
}

// =====================================================
// ================== TelaReceitas ====================
// =====================================================

class TelaReceitas extends StatefulWidget {
  const TelaReceitas({super.key});

  @override
  State<TelaReceitas> createState() => _TelaReceitasState();
}


class _TelaReceitasState extends State<TelaReceitas> with AutomaticKeepAliveClientMixin {
  final DatabaseHelper _db = DatabaseHelper();
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  List<Category> _categories = [];
  Category? _selectedCategoryFilter;
  StreamSubscription<String>? _notificationSubscription;

  @override
  bool get wantKeepAlive => true; // Mantém a tela na memória ao deslizar

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _loadCategories();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationListener() {
    _notificationSubscription = NotificationService.instance.stream.listen((event) {
      if (event == 'recipes_db_updated') {
        _loadRecipes();
        _loadCategories();
      }
    });
  }

  Future<void> _loadRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;
    List<Recipe> recs;
    if (userId > 0) {
      recs = await _db.getRecipesByUserId(userId);
    } else {
      recs = [];
    }
    setState(() {
      _allRecipes = recs;
      _applyFilter();
    });
  }

  Future<void> _loadCategories() async {
    final categories = await _db.getAllCategories();
    setState(() {
      _categories = categories;
      if (_selectedCategoryFilter != null) {
        _selectedCategoryFilter = _categories.firstWhere(
          (cat) => cat.id == _selectedCategoryFilter!.id,
          orElse: () => _selectedCategoryFilter!,
        );
      }
    });
  }

  void _applyFilter() {
    if (_selectedCategoryFilter == null) {
      _filteredRecipes = List.from(_allRecipes);
    } else {
      _filteredRecipes = _allRecipes.where((recipe) => recipe.categoryId == _selectedCategoryFilter!.id).toList();
    }
  }

  Future<Category?> _getCategoryById(int categoryId) async {
    return _categories.firstWhere((cat) => cat.id == categoryId, orElse: () => Category(id: null, name: ''));
  }

  void _openRecipeForm([Recipe? recipe]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RecipeForm(recipe: recipe)),
    );
    if (result == true) {
      await _loadRecipes();
      await _loadCategories();
    }
  }

  void _openCategoryManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
    );
    // Recarrega as categorias após voltar da tela de gerenciamento
    await _loadCategories();
  }

  Widget _buildRecipeImage(Recipe receita) {
    if (receita.imagePath != null && receita.imagePath!.isNotEmpty) {
      if (receita.imagePath!.contains('assets/')) {
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          child: ClipOval(
            child: Image.asset(
              receita.imagePath!,
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(receita),
            ),
          ),
        );
      } else if (receita.imagePath!.startsWith('data:image/')) {
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          backgroundImage: MemoryImage(base64Decode(receita.imagePath!.split(',').last)),
        );
      } else {
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.grey[200],
          backgroundImage: FileImage(File(receita.imagePath!)),
          child: _buildFallbackAvatar(receita),
        );
      }
    }
    return _buildFallbackAvatar(receita);
  }

  Widget _buildFallbackAvatar(Recipe receita) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: Colors.grey[200],
      child: Text(
        receita.name.isNotEmpty ? receita.name[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para o AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Receitas'),
        backgroundColor: corAmareloPrincipal,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _openCategoryManagement,
            tooltip: 'Gerenciar categorias',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openRecipeForm(),
            tooltip: 'Adicionar receita',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro por categoria
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Theme.of(context).scaffoldBackgroundColor 
                  : corAmareloPrincipal.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Filtrar por categoria:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Category?>(
                    value: _selectedCategoryFilter,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: corAmareloPrincipal,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark 
                          ? Theme.of(context).cardColor 
                          : Colors.white,
                      isDense: true,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 14,
                    ),
                    dropdownColor: Theme.of(context).brightness == Brightness.dark 
                        ? Theme.of(context).cardColor 
                        : Colors.white,
                    items: [
                      const DropdownMenuItem<Category?>(
                        value: null,
                        child: Text('Todas as categorias'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem<Category?>(
                          value: category,
                          child: Text(category.name),
                        );
                      }),
                    ],
                    onChanged: (Category? newValue) {
                      setState(() {
                        _selectedCategoryFilter = newValue;
                        _applyFilter();
                      });
                    },
                    hint: const Text('Selecione uma categoria'),
                  ),
                ),
              ],
            ),
          ),
          // Lista de receitas
          Expanded(
            child: _filteredRecipes.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedCategoryFilter != null 
                              ? 'Nenhuma receita encontrada para a categoria "${_selectedCategoryFilter!.name}".' 
                              : 'Nenhuma receita encontrada.'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _openRecipeForm(),
                            child: const Text('Adicionar primeira receita'),
                          )
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final receita = _filteredRecipes[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12.0),
                          leading: _buildRecipeImage(receita),
                          title: Text(receita.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(receita.restrictions),
                              if (receita.categoryId != null) ...[
                                const SizedBox(height: 4),
                                FutureBuilder<Category?>(
                                  future: _getCategoryById(receita.categoryId!),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: corAmareloPrincipal.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          snapshot.data!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: corAmareloPrincipal,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => DetalheReceitaScreen(receita: receita)),
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _openRecipeForm(receita)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Excluir receita'),
                                      content: const Text('Deseja realmente excluir esta receita?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _db.deleteRecipe(receita.id ?? 0);
                                    await _loadRecipes();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// =============== DetalheReceitaScreen ===============
// =====================================================

class DetalheReceitaScreen extends StatefulWidget {
  final Recipe receita;
  const DetalheReceitaScreen({super.key, required this.receita});

  @override
  State<DetalheReceitaScreen> createState() => _DetalheReceitaScreenState();
}

class _DetalheReceitaScreenState extends State<DetalheReceitaScreen> {
  @override
  Widget build(BuildContext context) {
    final receita = widget.receita;
    final List<String> ingredientes = receita.ingredients.split('\n');
    final List<String> modoPreparo = receita.preparationMode.split('\n');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBackgroundColor = isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Colors.white;

    Widget imageWidget;
    if (receita.imagePath != null && receita.imagePath!.isNotEmpty) {
      if (receita.imagePath!.contains('assets/')) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.asset(receita.imagePath!, width: double.infinity, height: 250, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
          ),
        );
      } else if (receita.imagePath!.startsWith('data:image/')) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.memory(base64Decode(receita.imagePath!.split(',').last), width: double.infinity, height: 250, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
          ),
        );
      } else if (!kIsWeb) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.file(File(receita.imagePath!), width: double.infinity, height: 250, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
          ),
        );
      } else if (receita.imagePath!.startsWith('http')) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Image.network(receita.imagePath!, width: double.infinity, height: 250, fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
          ),
        );
      } else {
        imageWidget = _buildImagePlaceholder();
      }
    } else {
      imageWidget = _buildImagePlaceholder();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        title: Text(receita.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              if (receita.id == null) return;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Excluir receita'),
                  content: const Text('Deseja realmente excluir esta receita?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Excluir')),
                  ],
                ),
              );
              if (confirmed == true) {
                await DatabaseHelper().deleteRecipe(receita.id!);
                if (!mounted) return;
                Navigator.pop(context, true);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imageWidget,
              const SizedBox(height: 24),
              Text('Ingredientes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (String ingrediente in ingredientes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18, color: corAmareloPrincipal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ingrediente)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text('Modo de Preparo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (int i = 0; i < modoPreparo.length; i++)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: corAmareloClaro,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.black87)),
                  ),
                  title: Text(modoPreparo[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity, height: 250, color: Colors.grey[200],
      child: const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
    );
  }
}

// =====================================================
// ================== PlaceholderScreen ================
// =====================================================

class PlaceholderScreen extends StatelessWidget {
  final String texto;
  const PlaceholderScreen({super.key, required this.texto});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(texto, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}