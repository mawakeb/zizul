import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_stat.dart';
import '../../providers/category_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';
import '../../utils/app_helpers.dart';
import '../../utils/date_range_util.dart';
import '../../widgets/charts/pie_chart.dart';
import 'stats_period.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;
  DateTime _cursor = DateTime.now();

  void _move(int delta) {
    setState(() {
      if (_period == StatsPeriod.week) {
        _cursor = _cursor.add(Duration(days: 7 * delta));
      } else if (_period == StatsPeriod.month) {
        _cursor = DateTime(_cursor.year, _cursor.month + delta, 1);
      } else {
        _cursor = DateTime(_cursor.year + delta, 1, 1);
      }
    });
  }

  DateRange _range() {
    switch (_period) {
      case StatsPeriod.week:
        return DateRangeUtil.weekRange(_cursor);
      case StatsPeriod.month:
        return DateRangeUtil.monthRange(_cursor);
      case StatsPeriod.year:
        return DateRangeUtil.yearRange(_cursor);
    }
  }

  int _goalByPeriod(int monthlyGoal, int weeklyGoal) {
    if (_period == StatsPeriod.week) return weeklyGoal;
    if (_period == StatsPeriod.month) return monthlyGoal;
    return monthlyGoal * 12;
  }

  Future<List<CategoryStat>> _loadStats() {
    final repo = ref.read(statsRepositoryProvider);
    switch (_period) {
      case StatsPeriod.week:
        return repo.getWeeklyCategoryStats(_cursor);
      case StatsPeriod.month:
        return repo.getMonthlyCategoryStats(_cursor);
      case StatsPeriod.year:
        return repo.getYearlyCategoryStats(_cursor);
    }
  }

  Future<void> _showCategoryExpenses(String name, int? categoryId) async {
    final repo = ref.read(expenseRepositoryProvider);
    final expenses = await repo.getExpensesInRange(_range());
    final filtered = expenses.where((e) => e.categoryId == categoryId).toList();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('$name 내역', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            if (filtered.isEmpty) const Text('내역 없음'),
            ...filtered.map((e) => ListTile(title: Text('₩${e.amount}'), subtitle: Text('${formatDateTime(e.createdAt)} · ${e.memo ?? ''}'))),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: categoriesAsync.when(
        data: (categories) {
          final categoryMap = {for (final c in categories) c.id: c};
          return FutureBuilder<List<CategoryStat>>(
            future: _loadStats(),
            builder: (context, statSnap) {
              if (statSnap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (statSnap.hasError) {
                return Center(child: Text('통계 오류: ${statSnap.error}'));
              }

              final stats = statSnap.data ?? [];
              final sum = stats.fold<int>(0, (p, e) => p + e.totalAmount);

              return FutureBuilder<int>(
                future: ref.read(expenseRepositoryProvider).getTotalInRange(_range()),
                builder: (context, spendSnap) {
                  final spent = spendSnap.data ?? 0;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SegmentedButton<StatsPeriod>(
                        segments: const [
                          ButtonSegment(value: StatsPeriod.week, label: Text('주')),
                          ButtonSegment(value: StatsPeriod.month, label: Text('월')),
                          ButtonSegment(value: StatsPeriod.year, label: Text('연')),
                        ],
                        selected: {_period},
                        onSelectionChanged: (s) => setState(() => _period = s.first),
                      ),
                      Row(
                        children: [
                          IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
                          Expanded(child: Center(child: Text(periodText(_period, _cursor)))),
                          IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (sum > 0)
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            slices: stats
                                .map((s) => PieSlice(value: s.totalAmount.toDouble(), color: sliceColor(s.categoryId), label: categoryMap[s.categoryId]?.name ?? '미분류'))
                                .toList(),
                          ),
                        )
                      else
                        const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('통계 데이터가 없습니다.')))),
                      const SizedBox(height: 8),
                      ...stats.map((s) {
                        final ratio = sum == 0 ? 0.0 : s.totalAmount / sum;
                        final name = categoryMap[s.categoryId]?.name ?? '미분류';
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: sliceColor(s.categoryId)),
                          title: Text(name),
                          subtitle: Text('₩${s.totalAmount} · ${(ratio * 100).toStringAsFixed(1)}%'),
                          onTap: () => _showCategoryExpenses(name, s.categoryId),
                        );
                      }),
                      const Divider(),
                      settingsAsync.when(
                        data: (settings) {
                          final goal = _goalByPeriod(settings.monthlyGoal, settings.weeklyGoal);
                          final remain = goal - spent;
                          final elapsed = elapsedRatio(_period, _cursor);
                          final spendRatio = goal <= 0 ? 0.0 : spent / goal;

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('목표 대비 분석', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text('소비: ₩$spent / 목표: ₩$goal'),
                                  Text('남은 금액: ₩$remain'),
                                  Text('페이스: ${paceStatus(spendRatio, elapsed, goal)}'),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
