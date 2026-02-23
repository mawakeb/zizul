import '../database/database_helper.dart';
import '../models/expense.dart';
import '../utils/date_range_util.dart';

class ExpenseRepository {
  final _db = DatabaseHelper.instance;

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense.toMap());
  }

  Future<List<Expense>> getMonthlyExpenses(DateTime date) async {
    final range = DateRangeUtil.monthRange(date);
    final result =
        await _db.getExpensesBetween(range.start, range.end);
    return result.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> getMonthlyTotal(DateTime date) async {
    final range = DateRangeUtil.monthRange(date);
    final total =
        await _db.getTotalBetween(range.start, range.end);
    return total ?? 0;
  }

  Future<void> updateExpense(Expense expense) async {
    if (expense.id == null) return;
    await _db.updateExpense(expense.id!, expense.toMap());
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
  }

  Future<void> deleteMultiple(List<int> ids) async {
    await _db.deleteMultipleExpenses(ids);
  }
}