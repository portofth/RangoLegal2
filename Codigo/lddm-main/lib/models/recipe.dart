class Recipe {
  int? id;
  String name;
  String preparationMode;
  String ingredients;
  String restrictions;
  String? imagePath; // Campo para o caminho da imagem
  int userId; // Foreign Key
  int? categoryId; // Foreign Key para Category

  Recipe({
    this.id,
    required this.name,
    required this.preparationMode,
    required this.ingredients,
    required this.restrictions,
    this.imagePath,
    required this.userId,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'preparationMode': preparationMode,
      'ingredients': ingredients,
      'restrictions': restrictions,
      'imagePath': imagePath,
      'userId': userId,
      'categoryId': categoryId,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      preparationMode: map['preparationMode'],
      ingredients: map['ingredients'],
      restrictions: map['restrictions'],
      imagePath: map['imagePath'],
      userId: map['userId'],
      categoryId: map['categoryId'],
    );
  }
}