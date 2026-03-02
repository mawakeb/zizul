import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../repositories/category_repository.dart';
import 'repository_providers.dart';

class CategoryNotifier extends AsyncNotifier<List<Category>> {
  late final CategoryRepository _repo;

  @override
  Future<List<Category>> build() async {
    _repo = ref.read(categoryRepositoryProvider);
    return _repo.getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getAll);
  }

  Future<void> add(Category category) async {
    await _repo.add(category);
    await refresh();
  }

  Future<void> updateCategory(Category category) async {
    await _repo.update(category);
    await refresh();
  }

  Future<void> deleteCategory(int id) async {
    await _repo.delete(id);
    await refresh();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoryNotifier, List<Category>>(
  CategoryNotifier.new,
);

final shortcutCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repo = ref.read(categoryRepositoryProvider);
  return repo.getShortcuts();
});
