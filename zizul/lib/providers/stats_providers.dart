import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_stat.dart';
import 'date_providers.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

class SpendingStatus {
  final String level;
  final double spendRatio;
  final double elapsedRatio;

  const SpendingStatus({
    required this.level,
    required this.spendRatio,
    required this.elapsedRatio,
  });
}

final monthlyCategoryStatsProvider =
    FutureProvider<List<CategoryStat>>((ref) async {
  final repo = ref.read(statsRepositoryProvider);
  final date = ref.watch(selectedMonthProvider);
  return repo.getMonthlyCategoryStats(date);
});

final weeklyCategoryStatsProvider =
    FutureProvider<List<CategoryStat>>((ref) async {
  final repo = ref.read(statsRepositoryProvider);
  final date = ref.watch(selectedMonthProvider);
  return repo.getWeeklyCategoryStats(date);
});

final spendingStatusProvider = FutureProvider<SpendingStatus>((ref) async {
  final date = ref.watch(selectedMonthProvider);
  final settings = await ref.watch(settingsProvider.future);
  final expenseRepo = ref.read(expenseRepositoryProvider);

  final monthlyTotal = await expenseRepo.getMonthlyTotal(date);

  final goal = settings.monthlyGoal;
  if (goal <= 0) {
    return const SpendingStatus(
      level: 'no_goal',
      spendRatio: 0,
      elapsedRatio: 0,
    );
  }

  final now = DateTime.now();
  final sameMonth = now.year == date.year && now.month == date.month;
  final dayCursor = sameMonth ? now.day : DateTime(date.year, date.month + 1, 0).day;
  final totalDaysInMonth = DateTime(date.year, date.month + 1, 0).day;

  final spendRatio = monthlyTotal / goal;
  final elapsedRatio = dayCursor / totalDaysInMonth;

  if (spendRatio >= 1) {
    return SpendingStatus(
      level: 'exceeded',
      spendRatio: spendRatio,
      elapsedRatio: elapsedRatio,
    );
  }

  if (spendRatio > elapsedRatio + 0.1) {
    return SpendingStatus(
      level: 'caution',
      spendRatio: spendRatio,
      elapsedRatio: elapsedRatio,
    );
  }

  return SpendingStatus(
    level: 'normal',
    spendRatio: spendRatio,
    elapsedRatio: elapsedRatio,
  );
});
