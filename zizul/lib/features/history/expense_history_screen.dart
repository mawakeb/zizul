import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/payment_type.dart';
import '../../providers/category_providers.dart';
import '../../providers/date_providers.dart';
import '../../providers/expense_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/settings_providers.dart';
import '../../utils/app_helpers.dart';
import '../../utils/csv/csv_util.dart';

enum ExpenseSort { newest, oldest, amountHigh, amountLow }

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _searchController = TextEditingController();
  final Set<int> _selectedIds = {};
  ExpenseSort _sort = ExpenseSort.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _moveMonth(int delta) {
    final m = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = DateTime(m.year, m.month + delta, 1);
  }

  Future<void> _pickMonth() async {
    final current = ref.read(selectedMonthProvider);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
  }

  List<Expense> _filterSort(List<Expense> input, Map<int, Category> categoryMap) {
    var list = [...input];
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) {
        final memo = (e.memo ?? '').toLowerCase();
        final category = (categoryMap[e.categoryId]?.name ?? '').toLowerCase();
        return memo.contains(q) || category.contains(q);
      }).toList();
    }

    switch (_sort) {
      case ExpenseSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ExpenseSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ExpenseSort.amountHigh:
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case ExpenseSort.amountLow:
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
    }
    return list;
  }

  Future<void> _showGoalDialog() async {
    final settings = await ref.read(settingsProvider.future);
    final monthly = TextEditingController(text: settings.monthlyGoal.toString());
    final weekly = TextEditingController(text: settings.weeklyGoal.toString());

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('목표 금액 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: monthly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '월간 목표')),
              const SizedBox(height: 8),
              TextField(controller: weekly, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '주간 목표')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).updateGoals(
                      monthly: int.tryParse(monthly.text) ?? 0,
                      weekly: int.tryParse(weekly.text) ?? 0,
                    );
                ref.invalidate(monthlyTotalProvider);
                ref.invalidate(monthlyExpensesProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    await ref.read(monthlyExpensesProvider.notifier).deleteMultiple(_selectedIds.toList());
    setState(() => _selectedIds.clear());
  }

  Future<void> _exportCsv(List<Expense> expenses, Map<int, Category> categoryMap) async {
    await Clipboard.setData(ClipboardData(text: expensesToCsv(expenses, categoryMap)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV를 클립보드에 복사했습니다.')));
  }

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('CSV 가져오기'),
          content: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(hintText: 'id,created_at,amount,category,payment_type,memo'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                final raw = controller.text.trim();
                if (raw.isEmpty) return;
                final lines = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
                if (lines.length < 2) return;

                final categoryRepo = ref.read(categoryRepositoryProvider);
                final expenseRepo = ref.read(expenseRepositoryProvider);
                var categories = await categoryRepo.getAll();

                for (var i = 1; i < lines.length; i++) {
                  final row = parseCsvLine(lines[i]);
                  if (row.length < 6) continue;

                  final createdAt = DateTime.tryParse(row[1]);
                  final amount = int.tryParse(row[2]);
                  if (createdAt == null || amount == null || amount <= 0) continue;

                  final categoryName = row[3].trim();
                  Category? category;
                  if (categoryName.isNotEmpty) {
                    final lower = categoryName.toLowerCase();
                    category = categories.cast<Category?>().firstWhere(
                      (c) => c?.name.toLowerCase() == lower,
                      orElse: () => null,
                    );
                    if (category == null) {
                      await categoryRepo.add(Category(name: categoryName, color: const Color(0xFF8B5CF6).value, isShortcut: false));
                      categories = await categoryRepo.getAll();
                      category = categories.cast<Category?>().firstWhere(
                        (c) => c?.name.toLowerCase() == lower,
                        orElse: () => null,
                      );
                    }
                  }

                  await expenseRepo.addExpense(
                    Expense(
                      amount: amount,
                      createdAt: createdAt,
                      categoryId: category?.id,
                      paymentType: paymentTypeFromLabel(row[4]),
                      memo: row[5].trim().isEmpty ? null : row[5].trim(),
                    ),
                  );
                }

                ref.invalidate(monthlyExpensesProvider);
                ref.invalidate(monthlyTotalProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('가져오기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showExpenseDetail(Expense e, Map<int, Category> categoryMap) async {
    final amountController = TextEditingController(text: e.amount.toString());
    final memoController = TextEditingController(text: e.memo ?? '');
    DateTime dt = e.createdAt;
    int? categoryId = e.categoryId;
    PaymentType paymentType = e.paymentType;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          final categories = categoryMap.values.toList();
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('상세 / 수정', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '금액')),
                TextField(controller: memoController, decoration: const InputDecoration(labelText: '메모')),
                DropdownButtonFormField<int?>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('선택 안함')),
                    ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) => setModalState(() => categoryId = v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: PaymentType.values.map((p) {
                    return ChoiceChip(
                      selected: paymentType == p,
                      label: Text(paymentTypeLabel(p)),
                      onSelected: (_) => setModalState(() => paymentType = p),
                    );
                  }).toList(),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: dt);
                    if (d == null) return;
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(dt));
                    if (t == null) return;
                    setModalState(() => dt = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(formatDateTime(dt)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        if (e.id != null) {
                          await ref.read(monthlyExpensesProvider.notifier).deleteExpense(e.id!);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () async {
                        final amount = int.tryParse(amountController.text.trim());
                        if (amount == null || amount <= 0 || e.id == null) return;
                        await ref.read(monthlyExpensesProvider.notifier).updateExpense(
                              Expense(id: e.id, amount: amount, createdAt: dt, categoryId: categoryId, paymentType: paymentType, memo: memoController.text.trim().isEmpty ? null : memoController.text.trim()),
                            );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('수정 저장'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(monthlyExpensesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalAsync = ref.watch(monthlyTotalProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('지출 내역'),
        actions: [
          IconButton(onPressed: _showGoalDialog, icon: const Icon(Icons.flag_outlined)),
          IconButton(onPressed: _importCsv, icon: const Icon(Icons.file_upload_outlined)),
        ],
      ),
      body: categoriesAsync.when(
        data: (categories) {
          final categoryMap = {for (final c in categories) c.id!: c};
          return expensesAsync.when(
            data: (expenses) {
              final filtered = _filterSort(expenses, categoryMap);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: TextButton(
                          onPressed: _pickMonth,
                          child: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      IconButton(onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('해당 월 총 지출'),
                          totalAsync.when(
                            data: (v) => Text('₩$v', style: Theme.of(context).textTheme.headlineSmall),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('$e'),
                          ),
                          const SizedBox(height: 6),
                          settingsAsync.when(
                            data: (s) => Text('목표 월간 ${s.monthlyGoal} / 주간 ${s.weeklyGoal}'),
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => Text('$e'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: '검색 (메모/카테고리)', prefixIcon: Icon(Icons.search)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<ExpenseSort>(
                        value: _sort,
                        items: const [
                          DropdownMenuItem(value: ExpenseSort.newest, child: Text('최신순')),
                          DropdownMenuItem(value: ExpenseSort.oldest, child: Text('오래된순')),
                          DropdownMenuItem(value: ExpenseSort.amountHigh, child: Text('금액많은순')),
                          DropdownMenuItem(value: ExpenseSort.amountLow, child: Text('금액적은순')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sort = v);
                        },
                      ),
                      const Spacer(),
                      Text('선택 ${_selectedIds.length}개'),
                      IconButton(onPressed: _selectedIds.isEmpty ? null : _bulkDelete, icon: const Icon(Icons.delete_outline)),
                      IconButton(onPressed: () => _exportCsv(filtered, categoryMap), icon: const Icon(Icons.file_download_outlined)),
                    ],
                  ),
                  const Divider(),
                  if (filtered.isEmpty)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('내역이 없습니다.'))),
                  ...filtered.map((e) {
                    final selected = _selectedIds.contains(e.id);
                    return Card(
                      child: ListTile(
                        onTap: () => _showExpenseDetail(e, categoryMap),
                        onLongPress: e.id == null
                            ? null
                            : () {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(e.id);
                                  } else {
                                    _selectedIds.add(e.id!);
                                  }
                                });
                              },
                        leading: e.id == null
                            ? null
                            : Checkbox(
                                value: selected,
                                onChanged: (_) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(e.id);
                                    } else {
                                      _selectedIds.add(e.id!);
                                    }
                                  });
                                },
                              ),
                        title: Text('₩${e.amount}'),
                        subtitle: Text('${formatDateTime(e.createdAt)} · ${categoryMap[e.categoryId]?.name ?? '미분류'} · ${paymentTypeLabel(e.paymentType)}\n${e.memo ?? ''}'),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('지출 조회 오류: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('카테고리 조회 오류: $e')),
      ),
    );
  }
}
