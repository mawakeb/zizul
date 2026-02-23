class CategoryStat {
  final int? categoryId;
  final int totalAmount;

  CategoryStat({
    required this.categoryId,
    required this.totalAmount,
  });

  factory CategoryStat.fromMap(Map<String, dynamic> map) {
    return CategoryStat(
      categoryId: map['category_id'],
      totalAmount: map['total'] ?? 0,
    );
  }
}