import 'package:flutter/material.dart';
import 'package:meu_app/database_helper.dart';
import 'package:meu_app/models/category.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Category> _categories = [];
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await _db.getAllCategories();
    setState(() {
      _categories = categories;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Categoria "$categoryName" criada com sucesso!')),
        );
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria'),
        content: Text('Deseja realmente excluir a categoria "${category.name}"? '
                     'As receitas associadas a esta categoria não serão afetadas, '
                     'mas perderão a associação com a categoria.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _db.deleteCategory(category.id!);
      if (result > 0) {
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Categoria "${category.name}" excluída com sucesso!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao excluir categoria')),
          );
        }
      }
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

  @override
  Widget build(BuildContext context) {
    const Color corAmareloPrincipal = Color(0xFFFBC02D);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Categorias'),
        backgroundColor: corAmareloPrincipal,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateCategoryDialog,
            tooltip: 'Adicionar categoria',
          ),
        ],
      ),
      body: _categories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nenhuma categoria encontrada.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _showCreateCategoryDialog,
                      child: const Text('Criar primeira categoria'),
                    )
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    leading: CircleAvatar(
                      backgroundColor: corAmareloPrincipal,
                      child: Text(
                        category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Categoria de receitas'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteCategory(category),
                      tooltip: 'Excluir categoria',
                    ),
                  ),
                );
              },
            ),
    );
  }
}