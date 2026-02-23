class Category {
  final int? id;
  final String name;
  final int color; // ARGB int
  final bool isShortcut;

  Category({
    this.id,
    required this.name,
    required this.color,
    required this.isShortcut,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'is_shortcut': isShortcut ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      isShortcut: map['is_shortcut'] == 1,
    );
  }
}