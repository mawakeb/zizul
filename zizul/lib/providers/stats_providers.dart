import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository_providers.dart';
import 'date_providers.dart';
import 'expense_providers.dart';

enum SpendingStatus {
  good,
  warning,
  exceeded,
}

final spendingStatusProvider =
    FutureProvider<SpendingStatus>((ref) async {
  final settingsRepo = ref.read(settingsRepositoryProvider);
  final settings = await settingsRepo.getSettings();

  final total = await ref.watch(monthlyTotalProvider.future);
  final selectedMonth = ref.watch(selectedMonthProvider);

  final now = DateTime.now();

  final daysInMonth =
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  final currentDay = now.day;

  final ratioSpent =
      settings.monthlyGoal == 0 ? 0 : total / settings.monthlyGoal;

  final ratioTime = currentDay / daysInMonth;

  if (ratioSpent > 1) {
    return SpendingStatus.exceeded;
  } else if (ratioSpent > ratioTime) {
    return SpendingStatus.warning;
  } else {
    return SpendingStatus.good;
  }
});