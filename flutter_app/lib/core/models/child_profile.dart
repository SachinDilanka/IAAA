class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.avatarId,
    required this.currentLevel,
  });

  final int id;
  final String name;
  final int age;
  final String avatarId;
  final String currentLevel;

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    id: json['id'] as int,
    name: json['name'] as String,
    age: json['age'] as int,
    avatarId: json['avatar_id'] as String? ?? 'tikiri',
    currentLevel: json['current_level'] as String? ?? 'letters',
  );

  ChildProfile copyWith({String? name, int? age}) => ChildProfile(
    id: id,
    name: name ?? this.name,
    age: age ?? this.age,
    avatarId: avatarId,
    currentLevel: currentLevel,
  );
}
