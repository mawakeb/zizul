import '../database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final _db = DatabaseHelper.instance;

  Future<List<Category>> getAll() async {
    final result = await _db.getAllCategories();
    return result.map((e) => Category.fromMap(e)).toList();
  }

  Future<List<Category>> getShortcuts() async {
    final result = await _db.getShortcutCategories();
    return result.map((e) => Category.fromMap(e)).toList();
  }

  Future<void> add(Category category) async {
    await _db.insertCategory(category.toMap());
  }

  Future<void> update(Category category) async {
    if (category.id == null) return;
    await _db.updateCategory(category.id!, category.toMap());
  }

  Future<void> delete(int id) async {
    await _db.deleteCategory(id);
  }
}