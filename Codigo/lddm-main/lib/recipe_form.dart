import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/recipe.dart';
import 'package:meu_app/models/category.dart';
import 'package:meu_app/image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meu_app/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RecipeForm extends StatefulWidget {
  final Recipe? recipe;
  const RecipeForm({super.key, this.recipe});

  @override
  State<RecipeForm> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _preparationController = TextEditingController();
  final _restrictionsController = TextEditingController();

  String? _selectedImagePath;
  bool _isLoading = false;
  List<Category> _categories = [];
  Category? _selectedCategory;
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _nameController.text = widget.recipe!.name;
      _ingredientsController.text = widget.recipe!.ingredients;
      _preparationController.text = widget.recipe!.preparationMode;
      _restrictionsController.text = widget.recipe!.restrictions;
      _selectedImagePath = widget.recipe!.imagePath;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientsController.dispose();
    _preparationController.dispose();
    _restrictionsController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final db = DatabaseHelper();
    final categories = await db.getAllCategories();
    setState(() {
      _categories = categories;
      if (widget.recipe != null && widget.recipe!.categoryId != null) {
        _selectedCategory = categories.firstWhere(
          (cat) => cat.id == widget.recipe!.categoryId,
          orElse: () => categories.first,
        );
      }
    });
  }

  Future<void> _createNewCategory() async {
    final categoryName = _newCategoryController.text.trim();
    if (categoryName.isEmpty) return;

    final db = DatabaseHelper();
    final newCategory = Category(name: categoryName);
    final id = await db.insertCategory(newCategory);

    if (id > 0) {
      _newCategoryController.clear();
      await _loadCategories();
      setState(() {
        _selectedCategory = _categories.firstWhere((cat) => cat.id == id);
      });
    }
  }

  void _showCreateCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            labelText: 'Nome da Categoria',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _createNewCategory();
              Navigator.of(context).pop();
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImageService().pickImage();
      if (image != null) {
        setState(() => _isLoading = true);

        final savedPath = await ImageService().saveImage(
          image,
          customName: 'recipe_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        if (mounted) {
          setState(() {
            _selectedImagePath = savedPath;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao selecionar imagem: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('userId') ?? 0;

    if (userId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, faça login para salvar receitas.'),
          backgroundColor: Colors.red,
        ),
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final recipe = Recipe(
      id: widget.recipe?.id,
      name: _nameController.text.trim(),
      preparationMode: _preparationController.text.trim(),
      ingredients: _ingredientsController.text.trim(),
      restrictions: _restrictionsController.text.trim(),
      imagePath: _selectedImagePath,
      userId: userId,
      categoryId: _selectedCategory?.id,
    );

    final db = DatabaseHelper();
    try {
      if (widget.recipe == null) {
        await db.insertRecipe(recipe);
      } else {
        await db.updateRecipe(recipe);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receita salva com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      NotificationService.instance.notify('recipes_db_updated');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar receita: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corAmareloPrincipal = Color(0xFFFBC02D);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? 'Nova Receita' : 'Editar Receita'),
        backgroundColor: corAmareloPrincipal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Seleção de Imagem
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: corAmareloPrincipal, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: !kIsWeb
                              ? Image.file(
                                  File(_selectedImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            size: 60,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Erro ao carregar imagem'),
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : Image.network(
                                  _selectedImagePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            size: 60,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Erro ao carregar imagem'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.image_not_supported,
                              size: 60,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nenhuma imagem selecionada',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),

                // Botão para selecionar imagem
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                      _isLoading ? 'Carregando...' : 'Selecionar Imagem',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: corAmareloPrincipal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Nome da Receita
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Receita',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.restaurant),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: 12),

                // Ingredientes
                TextFormField(
                  controller: _ingredientsController,
                  decoration: const InputDecoration(
                    labelText: 'Ingredientes (cada item em nova linha)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_cart),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Informe ao menos um ingrediente'
                      : null,
                ),
                const SizedBox(height: 12),

                // Modo de Preparo
                TextFormField(
                  controller: _preparationController,
                  decoration: const InputDecoration(
                    labelText: 'Modo de Preparo (linhas separadas)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_fire_department),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Informe o modo de preparo'
                      : null,
                ),
                const SizedBox(height: 12),

                // Restrições
                TextFormField(
                  controller: _restrictionsController,
                  decoration: const InputDecoration(
                    labelText: 'Restrições (ex: sem glúten, vegana)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // Categoria
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Category>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoria',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<Category>(
                            value: category,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (Category? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        hint: const Text('Selecione uma categoria (opcional)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _showCreateCategoryDialog,
                      icon: const Icon(Icons.add),
                      tooltip: 'Criar nova categoria',
                      style: IconButton.styleFrom(
                        backgroundColor: corAmareloPrincipal,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Botões de Ação
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corAmareloPrincipal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Salvar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
