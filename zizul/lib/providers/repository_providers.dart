import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/expense_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/stats_repository.dart';

final expenseRepositoryProvider =
    Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final statsRepositoryProvider =
    Provider<StatsRepository>((ref) {
  return StatsRepository();
});