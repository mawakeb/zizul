import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'repository_providers.dart';
import 'date_providers.dart';
import 'stats_providers.dart';

/// ===============================
/// Expense List State (AsyncNotifier)
/// ===============================

class MonthlyExpenseNotifier
    extends AsyncNotifier<List<Expense>> {
  late final ExpenseRepository _repo;

  @override
  Future<List<Expense>> build() async {
    _repo = ref.read(expenseRepositoryProvider);

    final selectedMonth = ref.watch(selectedMonthProvider);

    return _repo.getMonthlyExpenses(selectedMonth);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final selectedMonth = ref.read(selectedMonthProvider);
      return _repo.getMonthlyExpenses(selectedMonth);
    });
  }

  Future<void> addExpense(Expense expense) async {
    await _repo.addExpense(expense);

    // Invalidate dependent providers
    ref.invalidate(monthlyTotalProvider);
    ref.invalidate(spendingStatusProvider);

    await refresh();
  }

  Future<void> updateExpense(Expense expense) async {
    await _repo.updateExpense(expense);

    ref.invalidate(monthlyTotalProvider);
    ref.invalidate(spendingStatusProvider);

    await refresh();
  }

  Future<void> deleteExpense(int id) async {
    await _repo.deleteExpense(id);

    ref.invalidate(monthlyTotalProvider);
    ref.invalidate(spendingStatusProvider);

    await refresh();
  }

  Future<void> deleteMultiple(List<int> ids) async {
    await _repo.deleteMultiple(ids);

    ref.invalidate(monthlyTotalProvider);
    ref.invalidate(spendingStatusProvider);

    await refresh();
  }
}

/// Provider
final monthlyExpensesProvider =
    AsyncNotifierProvider<MonthlyExpenseNotifier, List<Expense>>(
        MonthlyExpenseNotifier.new);


/// ===============================
/// Monthly Total (Derived)
/// ===============================

final monthlyTotalProvider =
    FutureProvider<int>((ref) async {
  final repo = ref.read(expenseRepositoryProvider);
  final date = ref.watch(selectedMonthProvider);
  return repo.getMonthlyTotal(date);
});