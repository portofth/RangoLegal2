import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';

import 'package:meu_app/models/user.dart';
import 'package:meu_app/models/profile.dart';
import 'package:meu_app/models/recipe.dart';
import 'package:meu_app/models/category.dart';
import 'package:meu_app/dados_receitas.dart';
import 'package:meu_app/notification_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static Box<Map>? _hiveUsersBox;
  static Box<Map>? _hiveProfilesBox;
  static Box<Map>? _hiveRecipesBox;
  static Box<Map>? _hiveCategoriesBox;
  static Box<dynamic>? _hiveCountersBox;

  Future<void> initializeHive() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      _hiveUsersBox = await Hive.openBox<Map>('users');
      _hiveProfilesBox = await Hive.openBox<Map>('profiles');
      _hiveRecipesBox = await Hive.openBox<Map>('recipes');
      _hiveCategoriesBox = await Hive.openBox<Map>('categories');
      _hiveCountersBox = await Hive.openBox('counters');

      // Inicializa contadores se não existirem
      if (!_hiveCountersBox!.containsKey('user_id')) {
        _hiveCountersBox!.put('user_id', 1);
      }
      if (!_hiveCountersBox!.containsKey('profile_id')) {
        _hiveCountersBox!.put('profile_id', 1);
      }
      if (!_hiveCountersBox!.containsKey('recipe_id')) {
        _hiveCountersBox!.put('recipe_id', 1);
      }
      if (!_hiveCountersBox!.containsKey('category_id')) {
        _hiveCountersBox!.put('category_id', 1);
      }

      // ignore: avoid_print
      print('✅ Hive inicializado para Web');
      await _seedHiveRecipes();
    }
  }

  int _getNextUserId() {
    int id = _hiveCountersBox!.get('user_id', defaultValue: 1) as int;
    _hiveCountersBox!.put('user_id', id + 1);
    return id;
  }

  int _getNextProfileId() {
    int id = _hiveCountersBox!.get('profile_id', defaultValue: 1) as int;
    _hiveCountersBox!.put('profile_id', id + 1);
    return id;
  }

  int _getNextRecipeId() {
    int id = _hiveCountersBox!.get('recipe_id', defaultValue: 1) as int;
    _hiveCountersBox!.put('recipe_id', id + 1);
    return id;
  }

  int _getNextCategoryId() {
    int id = _hiveCountersBox!.get('category_id', defaultValue: 1) as int;
    _hiveCountersBox!.put('category_id', id + 1);
    return id;
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Use Hive em Web! Chame initializeHive() primeiro.');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      // Em dispositivos (Android/iOS/Windows), usar arquivo no documentDir
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'rango_legal.db');
      return await openDatabase(
        path,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          await _ensureRecipeSchema(db);
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Erro ao inicializar SQLite: $e');
      rethrow;
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE User (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        preferences TEXT,
        restrictions TEXT,
        activityLevel TEXT,
        nutritionalGoal TEXT,
        weight REAL,
        height REAL,
        age INTEGER,
        sex TEXT,
        userId INTEGER NOT NULL,
        FOREIGN KEY (userId) REFERENCES User(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        preparationMode TEXT,
        ingredients TEXT,
        restrictions TEXT,
        imagePath TEXT,
        userId INTEGER,
        categoryId INTEGER,
        FOREIGN KEY (userId) REFERENCES User(id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES Category(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE Category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // Seed inicial de receitas a partir da lista estática
    await _seedInitialRecipes(db);
    await _mockInitialGuestUser(db); // TODO: REMOVE THIS IN NEW DATABASE!!!
  }

  Future _mockInitialGuestUser(Database db) async {
    User u = User(
      email: "guest@localhost.com",
      firstName: "guest",
      lastName: "",
      password: "guest",
    ); // TODO: If we're going to use password for something in app there *must* be any encrpyt logic on it. There's an package for bcrypt in dart: https://pub.dev/packages/bcrypt
    // Usa a instância de `db` fornecida no onCreate para não reentrar em _initDatabase
    await db.insert('User', u.toMap());
  }

  Future<void> _ensureRecipeSchema(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info('Recipes')");
    final hasCategoryId = columns.any(
      (column) => column['name'] == 'categoryId',
    );
    if (!hasCategoryId) {
      // Ajusta o banco existente, caso tenha sido criado sem a coluna categoryId
      await db.execute('ALTER TABLE Recipes ADD COLUMN categoryId INTEGER;');
    }
  }

  // LÓGICA DE MIGRAÇÃO
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adiciona a coluna imagePath
      await db.execute("ALTER TABLE Recipes ADD COLUMN imagePath TEXT;");
    }
    if (oldVersion < 3) {
      // Adiciona a tabela Category
      await db.execute('''
        CREATE TABLE Category (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL
        )
      ''');
      // Adiciona a coluna categoryId na tabela Recipes
      await db.execute("ALTER TABLE Recipes ADD COLUMN categoryId INTEGER;");
    }
  }

  Future<void> _seedInitialRecipes(Database db) async {
    // Insere as receitas estáticas (todasAsReceitas) na tabela Recipes
    // Cada entrada em todasAsReceitas usa listas para ingredientes/modo_preparo
    for (final r in todasAsReceitas) {
      final name = r['nome'] ?? '';
      final ingredientes = (r['ingredientes'] is List)
          ? (r['ingredientes'] as List).join('\n')
          : (r['ingredientes']?.toString() ?? '');
      final preparo = (r['modo_preparo'] is List)
          ? (r['modo_preparo'] as List).join('\n')
          : (r['modo_preparo']?.toString() ?? '');
      final restrictions = r['restricoes'] ?? '';
      final image = r['imagem'];

      await db.insert('Recipes', {
        'name': name,
        'preparationMode': preparo,
        'ingredients': ingredientes,
        'restrictions': restrictions,
        'imagePath': image,
        'userId': null,
      });
    }
  }

  Future<void> _seedHiveRecipes() async {
    if (_hiveRecipesBox!.isEmpty) {
      for (final r in todasAsReceitas) {
        final name = r['nome'] ?? '';
        final ingredientes = (r['ingredientes'] is List)
            ? (r['ingredientes'] as List).join('\n')
            : (r['ingredientes']?.toString() ?? '');
        final preparo = (r['modo_preparo'] is List)
            ? (r['modo_preparo'] as List).join('\n')
            : (r['modo_preparo']?.toString() ?? '');
        final restrictions = r['restricoes'] ?? '';
        final image = r['imagem'];

        await _hiveRecipesBox!.add({
          'name': name,
          'preparationMode': preparo,
          'ingredients': ingredientes,
          'restrictions': restrictions,
          'imagePath': image,
          'userId': null,
        });
      }
    }
  }

  // --- Operações CRUD (User) ---
  Future<int> insertUser(User user) async {
    if (kIsWeb) {
      final userMap = user.toMap();
      // Em Hive, precisamos adicionar um ID manualmente
      userMap['id'] = _getNextUserId();
      await _hiveUsersBox!.add(userMap);
      return userMap['id'] as int;
    } else {
      Database db = await database;
      return await db.insert('User', user.toMap());
    }
  }

  Future<User?> getUser(String email, String password) async {
    if (kIsWeb) {
      for (var user in _hiveUsersBox!.values) {
        if (user['email'] == email && user['password'] == password) {
          return User.fromMap(user.cast<String, dynamic>());
        }
      }
      return null;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'User',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );
      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    }
  }

  Future<User?> getUserByEmail(String email) async {
    if (kIsWeb) {
      for (var user in _hiveUsersBox!.values) {
        if (user['email'] == email) {
          return User.fromMap(user.cast<String, dynamic>());
        }
      }
      return null;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'User',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    }
  }

  Future<User?> getUserById(int id) async {
    if (kIsWeb) {
      for (var user in _hiveUsersBox!.values) {
        if (user['id'] == id) {
          return User.fromMap(user.cast<String, dynamic>());
        }
      }
      return null;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'User',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return User.fromMap(maps.first);
      }
      return null;
    }
  }

  // --- Operações CRUD (Profile) ---
  Future<int> insertProfile(Profile profile) async {
    if (kIsWeb) {
      final profileMap = profile.toMap();
      profileMap['id'] = _getNextProfileId();
      await _hiveProfilesBox!.add(profileMap);
      // Notifica listeners que o perfil foi atualizado/inserido
      NotificationService.instance.notify('profile_updated');
      return profileMap['id'] as int;
    } else {
      Database db = await database;
      final id = await db.insert('Profile', profile.toMap());
      NotificationService.instance.notify('profile_updated');
      return id;
    }
  }

  Future<Profile?> getProfileByUserId(int userId) async {
    if (kIsWeb) {
      for (var profile in _hiveProfilesBox!.values) {
        if (profile['userId'] == userId) {
          return Profile.fromMap(profile.cast<String, dynamic>());
        }
      }
      return null;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'Profile',
        where: 'userId = ?',
        whereArgs: [userId],
      );
      if (maps.isNotEmpty) {
        return Profile.fromMap(maps.first);
      }
      return null;
    }
  }

  Future<List<Profile>> getProfilesByUserId(int userId) async {
    if (kIsWeb) {
      List<Profile> profiles = [];
      for (var profile in _hiveProfilesBox!.values) {
        if (profile['userId'] == userId) {
          profiles.add(Profile.fromMap(profile.cast<String, dynamic>()));
        }
      }
      return profiles;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'Profile',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'firstName ASC',
      );
      return List.generate(maps.length, (i) {
        return Profile.fromMap(maps[i]);
      });
    }
  }

  Future<int> updateProfile(Profile profile) async {
    if (kIsWeb) {
      // Em Hive, precisamos encontrar o índice do profile e atualizar
      int index = -1;
      for (int i = 0; i < _hiveProfilesBox!.length; i++) {
        final p = _hiveProfilesBox!.getAt(i);
        if (p?['id'] == profile.id) {
          index = i;
          break;
        }
      }
      if (index >= 0) {
        await _hiveProfilesBox!.putAt(index, profile.toMap());
        // Notifica listeners
        NotificationService.instance.notify('profile_updated');
        return 1;
      }
      return 0;
    } else {
      Database db = await database;
      final rows = await db.update(
        'Profile',
        profile.toMap(),
        where: 'id = ?',
        whereArgs: [profile.id],
      );
      if (rows > 0) NotificationService.instance.notify('profile_updated');
      return rows;
    }
  }

  Future<int> deleteProfile(int id) async {
    if (kIsWeb) {
      for (int i = 0; i < _hiveProfilesBox!.length; i++) {
        final p = _hiveProfilesBox!.getAt(i);
        if (p?['id'] == id) {
          await _hiveProfilesBox!.deleteAt(i);
          NotificationService.instance.notify('profile_updated');
          return 1;
        }
      }
      return 0;
    } else {
      Database db = await database;
      final rows = await db.delete('Profile', where: 'id = ?', whereArgs: [id]);
      if (rows > 0) NotificationService.instance.notify('profile_updated');
      return rows;
    }
  }

  // --- Operações CRUD (Recipes) ---
  Future<int> insertRecipe(Recipe recipe) async {
    if (kIsWeb) {
      final recipeMap = recipe.toMap();
      recipeMap['id'] = _getNextRecipeId();
      await _hiveRecipesBox!.add(recipeMap);
      // Notifica listeners que as receitas mudaram
      NotificationService.instance.notify('recipes_db_updated');
      return recipeMap['id'] as int;
    } else {
      Database db = await database;
      try {
        final id = await db.insert('Recipes', recipe.toMap());
        // ignore: avoid_print
        print('✅ Recipe inserted with id $id for user ${recipe.userId}');
        NotificationService.instance.notify('recipes_db_updated');
        return id;
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ Erro insertRecipe: $e');
        rethrow;
      }
    }
  }

  Future<List<Recipe>> getRecipesByUserId(int userId) async {
    if (kIsWeb) {
      List<Recipe> recipes = [];
      for (var recipe in _hiveRecipesBox!.values) {
        if (recipe['userId'] == userId) {
          recipes.add(Recipe.fromMap(recipe.cast<String, dynamic>()));
        }
      }
      return recipes;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'Recipes',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) {
        return Recipe.fromMap(maps[i]);
      });
    }
  }

  Future<int> updateRecipe(Recipe recipe) async {
    if (kIsWeb) {
      int index = -1;
      for (int i = 0; i < _hiveRecipesBox!.length; i++) {
        final r = _hiveRecipesBox!.getAt(i);
        if (r?['id'] == recipe.id) {
          index = i;
          break;
        }
      }
      if (index >= 0) {
        await _hiveRecipesBox!.putAt(index, recipe.toMap());
        NotificationService.instance.notify('recipes_db_updated');
        return 1;
      }
      return 0;
    } else {
      Database db = await database;
      final rows = await db.update(
        'Recipes',
        recipe.toMap(),
        where: 'id = ?',
        whereArgs: [recipe.id],
      );
      if (rows > 0) NotificationService.instance.notify('recipes_db_updated');
      return rows;
    }
  }

  Future<int> deleteRecipe(int id) async {
    if (kIsWeb) {
      for (int i = 0; i < _hiveRecipesBox!.length; i++) {
        final r = _hiveRecipesBox!.getAt(i);
        if (r?['id'] == id) {
          await _hiveRecipesBox!.deleteAt(i);
          NotificationService.instance.notify('recipes_db_updated');
          return 1;
        }
      }
      return 0;
    } else {
      Database db = await database;
      final rows = await db.delete('Recipes', where: 'id = ?', whereArgs: [id]);
      if (rows > 0) NotificationService.instance.notify('recipes_db_updated');
      return rows;
    }
  }

  Future<int> deleteUser(int userId) async {
    if (kIsWeb) {
      // Deleta todas as receitas do usuário
      for (int i = _hiveRecipesBox!.length - 1; i >= 0; i--) {
        final r = _hiveRecipesBox!.getAt(i);
        if (r?['userId'] == userId) {
          await _hiveRecipesBox!.deleteAt(i);
        }
      }

      // Deleta todos os perfis do usuário
      for (int i = _hiveProfilesBox!.length - 1; i >= 0; i--) {
        final p = _hiveProfilesBox!.getAt(i);
        if (p?['userId'] == userId) {
          await _hiveProfilesBox!.deleteAt(i);
        }
      }

      // Deleta o usuário
      for (int i = 0; i < _hiveUsersBox!.length; i++) {
        final u = _hiveUsersBox!.getAt(i);
        if (u?['id'] == userId) {
          await _hiveUsersBox!.deleteAt(i);
          return 1;
        }
      }
      return 0;
    } else {
      Database db = await database;

      // Deleta todas as receitas do usuário (cascata)
      await db.delete('Recipes', where: 'userId = ?', whereArgs: [userId]);

      // Deleta todos os perfis do usuário (cascata)
      await db.delete('Profile', where: 'userId = ?', whereArgs: [userId]);

      // Deleta o usuário
      return await db.delete('User', where: 'id = ?', whereArgs: [userId]);
    }
  }

  // --- Operações CRUD (Category) ---
  Future<int> insertCategory(Category category) async {
    if (kIsWeb) {
      final categoryMap = category.toMap();
      categoryMap['id'] = _getNextCategoryId();
      await _hiveCategoriesBox!.add(categoryMap);
      return categoryMap['id'] as int;
    } else {
      Database db = await database;
      return await db.insert('Category', category.toMap());
    }
  }

  Future<List<Category>> getAllCategories() async {
    if (kIsWeb) {
      List<Category> categories = [];
      for (var category in _hiveCategoriesBox!.values) {
        categories.add(Category.fromMap(category.cast<String, dynamic>()));
      }
      return categories;
    } else {
      Database db = await database;
      List<Map<String, dynamic>> maps = await db.query(
        'Category',
        orderBy: 'name ASC',
      );
      return List.generate(maps.length, (i) {
        return Category.fromMap(maps[i]);
      });
    }
  }

  Future<int> deleteCategory(int id) async {
    if (kIsWeb) {
      for (int i = 0; i < _hiveCategoriesBox!.length; i++) {
        final c = _hiveCategoriesBox!.getAt(i);
        if (c?['id'] == id) {
          await _hiveCategoriesBox!.deleteAt(i);
          return 1;
        }
      }
      return 0;
    } else {
      Database db = await database;
      return await db.delete('Category', where: 'id = ?', whereArgs: [id]);
    }
  }
}
