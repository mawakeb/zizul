import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database_helper.dart';
import 'models/category.dart';
import 'models/category_stat.dart';
import 'models/expense.dart';
import 'models/payment_type.dart';
import 'providers/category_providers.dart';
import 'providers/date_providers.dart';
import 'providers/expense_providers.dart';
import 'providers/repository_providers.dart';
import 'providers/settings_providers.dart';
import 'repositories/expense_repository.dart';
import 'repositories/stats_repository.dart';
import 'utils/date_range_util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(
    const ProviderScope(
      child: ZizulApp(),
    ),
  );
}

class ZizulApp extends StatelessWidget {
  const ZizulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zizul',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B5CF6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ZizulRootShell(),
    );
  }
}

class ZizulRootShell extends StatefulWidget {
  const ZizulRootShell({super.key});

  @override
  State<ZizulRootShell> createState() => _ZizulRootShellState();
}

class _ZizulRootShellState extends State<ZizulRootShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ExpenseAddScreen(),
      const ExpenseHistoryScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add), label: '추가'),
          NavigationDestination(icon: Icon(Icons.list), label: '내역'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '통계'),
        ],
      ),
    );
  }
}

class ExpenseAddScreen extends ConsumerStatefulWidget {
  const ExpenseAddScreen({super.key});

  @override
  ConsumerState<ExpenseAddScreen> createState() => _ExpenseAddScreenState();
}

class _ExpenseAddScreenState extends ConsumerState<ExpenseAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  int? _selectedCategoryId;
  PaymentType _selectedPaymentType = PaymentType.card;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDateTime,
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text.trim());
    final expense = Expense(
      amount: amount,
      createdAt: _selectedDateTime,
      categoryId: _selectedCategoryId,
      paymentType: _selectedPaymentType,
      memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
    );

    await ref.read(monthlyExpensesProvider.notifier).addExpense(expense);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장 완료'),
        content: const Text('지출이 저장되었습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    setState(() {
      _selectedDateTime = DateTime.now();
      _selectedCategoryId = null;
      _selectedPaymentType = PaymentType.card;
      _amountController.clear();
      _memoController.clear();
    });
  }

  Future<void> _addCategoryDialog() async {
    final nameController = TextEditingController();
    bool isShortcut = false;
    Color color = const Color(0xFF8B5CF6);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('카테고리 추가'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '카테고리 이름'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: isShortcut,
                    onChanged: (v) => setDialogState(() => isShortcut = v),
                    title: const Text('바로가기'),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      Colors.purple,
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.red,
                    ].map((c) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => color = c),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: c,
                          child: color == c
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    await ref.read(categoriesProvider.notifier).add(
                          Category(name: name, color: color.value, isShortcut: isShortcut),
                        );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('지출 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              title: const Text('날짜 / 시간'),
              subtitle: Text(_formatDateTime(_selectedDateTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            categories.when(
              data: (list) {
                return DropdownButtonFormField<int?>(
                  value: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: '카테고리 (선택)',
                    suffixIcon: IconButton(
                      onPressed: _addCategoryDialog,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('선택 안함')),
                    ...list.map(
                      (c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('카테고리 로드 실패: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '금액 (필수)'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return '금액을 입력하세요';
                if ((int.tryParse(value.trim()) ?? 0) <= 0) return '0보다 큰 금액을 입력하세요';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: '메모 (선택)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text('결제 수단'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PaymentType.values.map((type) {
                final selected = _selectedPaymentType == type;
                return ChoiceChip(
                  selected: selected,
                  label: Text(_paymentTypeLabel(type)),
                  onSelected: (_) => setState(() => _selectedPaymentType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

enum ExpenseSort { newest, oldest, amountHigh, amountLow }

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  final _searchController = TextEditingController();
  ExpenseSort _sort = ExpenseSort.newest;
  final Set<int> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _changeMonth(int offset) async {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = DateTime(current.year, current.month + offset, 1);
  }

  Future<void> _pickMonth() async {
    final now = ref.read(selectedMonthProvider);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    ref.read(selectedMonthProvider.notifier).state = DateTime(picked.year, picked.month, 1);
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    await ref.read(monthlyExpensesProvider.notifier).deleteMultiple(_selectedIds.toList());
    setState(_selectedIds.clear);
  }

  List<Expense> _applyFilterSort(List<Expense> input, Map<int, Category> categoryMap) {
    var list = [...input];
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        final memo = (e.memo ?? '').toLowerCase();
        final categoryName = (categoryMap[e.categoryId]?.name ?? '').toLowerCase();
        return memo.contains(query) || categoryName.contains(query);
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
      builder: (context) => AlertDialog(
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
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _toCsv(List<Expense> expenses, Map<int, Category> categories) {
    final buffer = StringBuffer('id,created_at,amount,category,payment_type,memo\n');
    for (final e in expenses) {
      final cells = [
        (e.id ?? '').toString(),
        e.createdAt.toIso8601String(),
        e.amount.toString(),
        categories[e.categoryId]?.name ?? '',
        _paymentTypeLabel(e.paymentType),
        e.memo ?? '',
      ].map(_escapeCsv).join(',');
      buffer.writeln(cells);
    }
    return buffer.toString();
  }

  String _escapeCsv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString());
    return result;
  }

  Future<void> _exportCsv(List<Expense> expenses, Map<int, Category> categories) async {
    final csv = _toCsv(expenses, categories);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV가 클립보드에 복사되었습니다.')),
    );
  }

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV 가져오기'),
        content: TextField(
          controller: controller,
          minLines: 8,
          maxLines: 16,
          decoration: const InputDecoration(
            hintText: 'id,created_at,amount,category,payment_type,memo ...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              final raw = controller.text.trim();
              if (raw.isEmpty) return;
              final lines = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
              if (lines.length <= 1) return;

              final categories = await ref.read(categoryRepositoryProvider).getAll();
              final map = {for (final c in categories) c.name.toLowerCase(): c};

              for (var i = 1; i < lines.length; i++) {
                final row = _parseCsvLine(lines[i]);
                if (row.length < 6) continue;
                final createdAt = DateTime.tryParse(row[1]);
                final amount = int.tryParse(row[2]);
                if (createdAt == null || amount == null || amount <= 0) continue;

                final categoryName = row[3].trim();
                Category? category;
                if (categoryName.isNotEmpty) {
                  category = map[categoryName.toLowerCase()];
                  if (category == null) {
                    final newCategory = Category(
                      name: categoryName,
                      color: const Color(0xFF8B5CF6).value,
                      isShortcut: false,
                    );
                    await ref.read(categoryRepositoryProvider).add(newCategory);
                  }
                }

                final updatedCategories = await ref.read(categoryRepositoryProvider).getAll();
                final updatedMap = {for (final c in updatedCategories) c.name.toLowerCase(): c};
                final resolvedCategory = updatedMap[categoryName.toLowerCase()];

                final payment = _paymentTypeFromLabel(row[4]);
                await ref.read(expenseRepositoryProvider).addExpense(
                      Expense(
                        amount: amount,
                        createdAt: createdAt,
                        categoryId: resolvedCategory?.id,
                        paymentType: payment,
                        memo: row[5].trim().isEmpty ? null : row[5].trim(),
                      ),
                    );
              }

              ref.invalidate(monthlyExpensesProvider);
              ref.invalidate(monthlyTotalProvider);

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV 가져오기를 완료했습니다.')),
              );
            },
            child: const Text('가져오기'),
          ),
        ],
      ),
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
              final filtered = _applyFilterSort(expenses, categoryMap);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: TextButton(
                          onPressed: _pickMonth,
                          child: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('해당 월 총 지출'),
                          const SizedBox(height: 6),
                          totalAsync.when(
                            data: (v) => Text('₩$v', style: Theme.of(context).textTheme.headlineSmall),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('$e'),
                          ),
                          const SizedBox(height: 8),
                          settingsAsync.when(
                            data: (s) => Text('목표 월간 ${s.monthlyGoal} / 주간 ${s.weeklyGoal}'),
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => Text('$e'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '검색 (메모/카테고리)',
                      prefixIcon: Icon(Icons.search),
                    ),
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
                          if (v == null) return;
                          setState(() => _sort = v);
                        },
                      ),
                      const Spacer(),
                      Text('선택 ${_selectedIds.length}개'),
                      IconButton(
                        onPressed: _selectedIds.isEmpty ? null : _bulkDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        onPressed: () => _exportCsv(filtered, categoryMap),
                        icon: const Icon(Icons.file_download_outlined),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('내역이 없습니다.')),
                    ),
                  ...filtered.map((expense) {
                    final selected = _selectedIds.contains(expense.id);
                    return Card(
                      child: ListTile(
                        onTap: () => _openExpenseDetail(expense, categoryMap),
                        onLongPress: expense.id == null
                            ? null
                            : () {
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(expense.id);
                                  } else {
                                    _selectedIds.add(expense.id!);
                                  }
                                });
                              },
                        leading: expense.id == null
                            ? null
                            : Checkbox(
                                value: selected,
                                onChanged: (_) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.remove(expense.id);
                                    } else {
                                      _selectedIds.add(expense.id!);
                                    }
                                  });
                                },
                              ),
                        title: Text('₩${expense.amount}'),
                        subtitle: Text(
                          '${_formatDateTime(expense.createdAt)} · ${categoryMap[expense.categoryId]?.name ?? '미분류'} · ${_paymentTypeLabel(expense.paymentType)}\n${expense.memo ?? ''}',
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('내역 조회 실패: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('카테고리 조회 실패: $e')),
      ),
    );
  }

  Future<void> _openExpenseDetail(Expense expense, Map<int, Category> categoryMap) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final amountController = TextEditingController(text: expense.amount.toString());
        final memoController = TextEditingController(text: expense.memo ?? '');
        DateTime date = expense.createdAt;
        int? categoryId = expense.categoryId;
        PaymentType paymentType = expense.paymentType;

        return StatefulBuilder(builder: (context, setModalState) {
          final categories = categoryMap.values.toList();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상세 / 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('ID: ${expense.id ?? '-'}'),
                  const SizedBox(height: 8),
                  TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '금액')),
                  const SizedBox(height: 8),
                  TextField(controller: memoController, decoration: const InputDecoration(labelText: '메모')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: categoryId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('선택 안함')),
                      ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => setModalState(() => categoryId = v),
                    decoration: const InputDecoration(labelText: '카테고리'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: PaymentType.values.map((p) {
                      return ChoiceChip(
                        label: Text(_paymentTypeLabel(p)),
                        selected: paymentType == p,
                        onSelected: (_) => setModalState(() => paymentType = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: date,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(date),
                      );
                      if (t == null) return;
                      setModalState(() {
                        date = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(_formatDateTime(date)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (expense.id != null) {
                            await ref.read(monthlyExpensesProvider.notifier).deleteExpense(expense.id!);
                          }
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('삭제'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () async {
                          final amount = int.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0 || expense.id == null) return;
                          await ref.read(monthlyExpensesProvider.notifier).updateExpense(
                                Expense(
                                  id: expense.id,
                                  amount: amount,
                                  createdAt: date,
                                  categoryId: categoryId,
                                  paymentType: paymentType,
                                  memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                                ),
                              );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('수정 저장'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

enum StatsPeriod { week, month, year }

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;
  DateTime _cursor = DateTime.now();

  DateRange _rangeForPeriod() {
    switch (_period) {
      case StatsPeriod.week:
        return DateRangeUtil.weekRange(_cursor);
      case StatsPeriod.month:
        return DateRangeUtil.monthRange(_cursor);
      case StatsPeriod.year:
        return DateRangeUtil.yearRange(_cursor);
    }
  }

  Future<List<CategoryStat>> _loadStats(StatsRepository repo) {
    switch (_period) {
      case StatsPeriod.week:
        return repo.getWeeklyCategoryStats(_cursor);
      case StatsPeriod.month:
        return repo.getMonthlyCategoryStats(_cursor);
      case StatsPeriod.year:
        return repo.getYearlyCategoryStats(_cursor);
    }
  }

  void _move(int dir) {
    setState(() {
      if (_period == StatsPeriod.week) {
        _cursor = _cursor.add(Duration(days: 7 * dir));
      } else if (_period == StatsPeriod.month) {
        _cursor = DateTime(_cursor.year, _cursor.month + dir, 1);
      } else {
        _cursor = DateTime(_cursor.year + dir, 1, 1);
      }
    });
  }

  String _periodLabel() {
    switch (_period) {
      case StatsPeriod.week:
        final r = DateRangeUtil.weekRange(_cursor);
        return '주간 (${_formatDate(DateTime.fromMillisecondsSinceEpoch(r.start))} ~ ${_formatDate(DateTime.fromMillisecondsSinceEpoch(r.end))})';
      case StatsPeriod.month:
        return '월간 ${_cursor.year}-${_cursor.month.toString().padLeft(2, '0')}';
      case StatsPeriod.year:
        return '연간 ${_cursor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsRepo = ref.read(statsRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: categoriesAsync.when(
        data: (categories) {
          final categoryMap = {for (final c in categories) c.id: c};
          return FutureBuilder<List<CategoryStat>>(
            future: _loadStats(statsRepo),
            builder: (context, snap) {
              if (!snap.hasData) {
                if (snap.hasError) return Center(child: Text('통계 오류: ${snap.error}'));
                return const Center(child: CircularProgressIndicator());
              }

              final stats = snap.data!;
              final total = stats.fold<int>(0, (p, e) => p + e.totalAmount);

              return FutureBuilder<int>(
                future: expenseRepo.getTotalInRange(_rangeForPeriod()),
                builder: (context, totalSnap) {
                  final spent = totalSnap.data ?? 0;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
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
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
                          Expanded(child: Center(child: Text(_periodLabel()))),
                          IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (total > 0)
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            slices: stats.map((e) => PieSlice(value: e.totalAmount.toDouble(), color: _sliceColor(e.categoryId), label: categoryMap[e.categoryId]?.name ?? '미분류')).toList(),
                          ),
                        )
                      else
                        const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('통계 데이터가 없습니다.')))),
                      const SizedBox(height: 12),
                      ...stats.map((s) {
                        final ratio = total == 0 ? 0.0 : s.totalAmount / total;
                        final categoryName = categoryMap[s.categoryId]?.name ?? '미분류';
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: _sliceColor(s.categoryId)),
                          title: Text(categoryName),
                          subtitle: Text('₩${s.totalAmount} · ${(ratio * 100).toStringAsFixed(1)}%'),
                          onTap: () => _showCategoryExpenses(categoryName, s.categoryId),
                        );
                      }),
                      const Divider(),
                      settingsAsync.when(
                        data: (settings) {
                          final goal = _period == StatsPeriod.week
                              ? settings.weeklyGoal
                              : _period == StatsPeriod.month
                                  ? settings.monthlyGoal
                                  : settings.monthlyGoal * 12;
                          final remaining = goal - spent;
                          final elapsedRatio = _elapsedRatio(_period, _cursor);
                          final spendRatio = goal <= 0 ? 0.0 : spent / goal;
                          final status = _status(spendRatio, elapsedRatio, goal);

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('목표 대비 분석', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text('소비: ₩$spent / 목표: ₩$goal'),
                                  Text('남은 금액: ₩$remaining'),
                                  Text('페이스: $status (소비비율 ${(spendRatio * 100).toStringAsFixed(1)}%, 경과 ${(elapsedRatio * 100).toStringAsFixed(1)}%)'),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: SwitchListTile(
                          value: settingsAsync.valueOrNull?.dailyNotificationEnabled ?? false,
                          onChanged: (v) async {
                            final s = settingsAsync.valueOrNull;
                            if (s == null) return;
                            await ref.read(settingsProvider.notifier).updateDailyNotification(
                                  enabled: v,
                                  hour: s.dailyNotificationHour,
                                  minute: s.dailyNotificationMinute,
                                );
                          },
                          title: const Text('매일 아침 푸시 알림 (설정값 저장)'),
                          subtitle: Text('시간 ${settingsAsync.valueOrNull?.dailyNotificationHour ?? 8}:${(settingsAsync.valueOrNull?.dailyNotificationMinute ?? 0).toString().padLeft(2, '0')}'),
                        ),
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

  Future<void> _showCategoryExpenses(String name, int? categoryId) async {
    final repo = ref.read(expenseRepositoryProvider);
    final range = _rangeForPeriod();
    final all = await repo.getExpensesInRange(range);
    final filtered = all.where((e) => e.categoryId == categoryId).toList();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$name 내역', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (filtered.isEmpty) const Text('내역 없음'),
          ...filtered.map((e) => ListTile(
                title: Text('₩${e.amount}'),
                subtitle: Text('${_formatDateTime(e.createdAt)} · ${e.memo ?? ''}'),
              )),
        ],
      ),
    );
  }
}

class PieSlice {
  final double value;
  final Color color;
  final String label;

  PieSlice({required this.value, required this.color, required this.label});
}

class PieChart extends StatelessWidget {
  final List<PieSlice> slices;

  const PieChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PieChartPainter(slices),
      child: const SizedBox.expand(),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PieSlice> slices;

  _PieChartPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (p, e) => p + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * (s.value / total);
      final paint = Paint()..color = s.color;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) => oldDelegate.slices != slices;
}

Color _sliceColor(int? id) {
  if (id == null) return Colors.grey;
  final colors = [
    const Color(0xFF8B5CF6),
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
  ];
  return colors[id.abs() % colors.length];
}

String _paymentTypeLabel(PaymentType type) {
  switch (type) {
    case PaymentType.card:
      return '카드';
    case PaymentType.cash:
      return '현금';
    case PaymentType.etc:
      return '기타';
  }
}

PaymentType _paymentTypeFromLabel(String label) {
  final normalized = label.trim();
  if (normalized == '현금' || normalized.toLowerCase() == 'cash') {
    return PaymentType.cash;
  }
  if (normalized == '기타' || normalized.toLowerCase() == 'etc') {
    return PaymentType.etc;
  }
  return PaymentType.card;
}

String _formatDateTime(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime d) {
  return '${d.month}/${d.day}';
}

double _elapsedRatio(StatsPeriod period, DateTime cursor) {
  final now = DateTime.now();
  if (period == StatsPeriod.week) {
    final sameWeekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final cursorWeekStart = DateTime(cursor.year, cursor.month, cursor.day - (cursor.weekday - 1));
    if (sameWeekStart.year == cursorWeekStart.year && sameWeekStart.month == cursorWeekStart.month && sameWeekStart.day == cursorWeekStart.day) {
      return now.weekday / 7;
    }
    return 1;
  }

  if (period == StatsPeriod.month) {
    final totalDays = DateTime(cursor.year, cursor.month + 1, 0).day;
    final day = (now.year == cursor.year && now.month == cursor.month) ? now.day : totalDays;
    return day / totalDays;
  }

  final totalDaysInYear = DateTime(cursor.year + 1, 1, 1).difference(DateTime(cursor.year, 1, 1)).inDays;
  final dayOfYear = now.year == cursor.year
      ? now.difference(DateTime(now.year, 1, 1)).inDays + 1
      : totalDaysInYear;
  return dayOfYear / totalDaysInYear;
}

String _status(double spendRatio, double elapsedRatio, int goal) {
  if (goal <= 0) return '목표 미설정';
  if (spendRatio >= 1) return '목표 초과';
  if (spendRatio > elapsedRatio + 0.1) return '주의 필요';
  return '정상 범위';
}
