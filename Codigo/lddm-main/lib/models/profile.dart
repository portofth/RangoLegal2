class Profile {
  int? id;
  String firstName;
  String lastName;
  String preferences;
  String restrictions;
  String activityLevel;
  String nutritionalGoal;
  double weight;
  double height;
  int age;
  String sex;
  int userId; // Foreign Key

  Profile({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.preferences,
    required this.restrictions,
    required this.activityLevel,
    required this.nutritionalGoal,
    required this.weight,
    required this.height,
    required this.age,
    required this.sex,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'preferences': preferences,
      'restrictions': restrictions,
      'activityLevel': activityLevel,
      'nutritionalGoal': nutritionalGoal,
      'weight': weight,
      'height': height,
      'age': age,
      'sex': sex,
      'userId': userId,
    };
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      preferences: map['preferences'],
      restrictions: map['restrictions'],
      activityLevel: map['activityLevel'],
      nutritionalGoal: map['nutritionalGoal'],
      weight: map['weight'],
      height: map['height'],
      age: map['age'],
      sex: map['sex'],
      userId: map['userId'],
    );
  }
}