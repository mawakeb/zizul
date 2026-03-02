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
import 'repositories/stats_repository.dart';
import 'utils/date_range_util.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const ProviderScope(child: ZizulApp()));
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ExpenseAddScreen(),
      const ExpenseHistoryScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_card), label: '추가'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '내역'),
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

  DateTime _dateTime = DateTime.now();
  int? _categoryId;
  PaymentType _paymentType = PaymentType.card;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _dateTime,
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('카테고리 추가'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '카테고리 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(categoriesProvider.notifier).add(
                      Category(
                        name: name,
                        color: const Color(0xFF8B5CF6).value,
                        isShortcut: false,
                      ),
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      amount: int.parse(_amountController.text.trim()),
      createdAt: _dateTime,
      categoryId: _categoryId,
      paymentType: _paymentType,
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
      _amountController.clear();
      _memoController.clear();
      _categoryId = null;
      _paymentType = PaymentType.card;
      _dateTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('지출 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('날짜 / 시간'),
              subtitle: Text(_formatDateTime(_dateTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) {
                return DropdownButtonFormField<int?>(
                  value: _categoryId,
                  decoration: InputDecoration(
                    labelText: '카테고리 (선택)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _addCategory,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('선택 안함'),
                    ),
                    ...categories.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('카테고리 오류: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '금액 (필수)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '금액을 입력하세요';
                final n = int.tryParse(v.trim()) ?? 0;
                if (n <= 0) return '0보다 큰 금액을 입력하세요';
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
                return ChoiceChip(
                  selected: _paymentType == type,
                  label: Text(_paymentTypeLabel(type)),
                  onSelected: (_) => setState(() => _paymentType = type),
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
              TextField(
                controller: monthly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '월간 목표'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weekly,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '주간 목표'),
              ),
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

  String _escapeCsv(String text) {
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  String _toCsv(List<Expense> expenses, Map<int, Category> categoryMap) {
    final buffer = StringBuffer('id,created_at,amount,category,payment_type,memo\n');
    for (final e in expenses) {
      buffer.writeln([
        (e.id ?? '').toString(),
        e.createdAt.toIso8601String(),
        e.amount.toString(),
        categoryMap[e.categoryId]?.name ?? '',
        _paymentTypeLabel(e.paymentType),
        e.memo ?? '',
      ].map(_escapeCsv).join(','));
    }
    return buffer.toString();
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;

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

  Future<void> _exportCsv(List<Expense> expenses, Map<int, Category> categoryMap) async {
    final csv = _toCsv(expenses, categoryMap);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV를 클립보드에 복사했습니다.')),
    );
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
            decoration: const InputDecoration(
              hintText: 'id,created_at,amount,category,payment_type,memo',
            ),
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
                  final row = _parseCsvLine(lines[i]);
                  if (row.length < 6) continue;

                  final createdAt = DateTime.tryParse(row[1]);
                  final amount = int.tryParse(row[2]);
                  if (createdAt == null || amount == null || amount <= 0) continue;

                  final categoryName = row[3].trim();
                  Category? category;
                  if (categoryName.isNotEmpty) {
                    category = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase()).cast<Category?>().firstWhere((_) => true, orElse: () => null);
                    if (category == null) {
                      await categoryRepo.add(
                        Category(
                          name: categoryName,
                          color: const Color(0xFF8B5CF6).value,
                          isShortcut: false,
                        ),
                      );
                      categories = await categoryRepo.getAll();
                      category = categories.where((c) => c.name.toLowerCase() == categoryName.toLowerCase()).cast<Category?>().firstWhere((_) => true, orElse: () => null);
                    }
                  }

                  await expenseRepo.addExpense(
                    Expense(
                      amount: amount,
                      createdAt: createdAt,
                      categoryId: category?.id,
                      paymentType: _paymentTypeFromLabel(row[4]),
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = categoryMap.values.toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상세 / 수정', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '금액'),
                  ),
                  TextField(
                    controller: memoController,
                    decoration: const InputDecoration(labelText: '메모'),
                  ),
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
                        label: Text(_paymentTypeLabel(p)),
                        onSelected: (_) => setModalState(() => paymentType = p),
                      );
                    }).toList(),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: dt,
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(dt),
                      );
                      if (t == null) return;
                      setModalState(() {
                        dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                    icon: const Icon(Icons.edit_calendar),
                    label: Text(_formatDateTime(dt)),
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
                                Expense(
                                  id: e.id,
                                  amount: amount,
                                  createdAt: dt,
                                  categoryId: categoryId,
                                  paymentType: paymentType,
                                  memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                                ),
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
          },
        );
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
                      IconButton(
                        onPressed: () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _pickMonth,
                          child: Text('${month.year}-${month.month.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
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
                          if (v != null) setState(() => _sort = v);
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
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('내역이 없습니다.')),
                    ),
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
                        subtitle: Text(
                          '${_formatDateTime(e.createdAt)} · ${categoryMap[e.categoryId]?.name ?? '미분류'} · ${_paymentTypeLabel(e.paymentType)}\n${e.memo ?? ''}',
                        ),
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

enum StatsPeriod { week, month, year }

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
                future: expenseRepo.getTotalInRange(_range()),
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
                          Expanded(child: Center(child: Text(_periodText(_period, _cursor)))),
                          IconButton(onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (sum > 0)
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            slices: stats
                                .map(
                                  (s) => PieSlice(
                                    value: s.totalAmount.toDouble(),
                                    color: _sliceColor(s.categoryId),
                                    label: categoryMap[s.categoryId]?.name ?? '미분류',
                                  ),
                                )
                                .toList(),
                          ),
                        )
                      else
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('통계 데이터가 없습니다.')),
                          ),
                        ),
                      const SizedBox(height: 8),
                      ...stats.map((s) {
                        final ratio = sum == 0 ? 0.0 : s.totalAmount / sum;
                        final name = categoryMap[s.categoryId]?.name ?? '미분류';
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: _sliceColor(s.categoryId)),
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
                          final elapsed = _elapsedRatio(_period, _cursor);
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
                                  Text('페이스: ${_paceStatus(spendRatio, elapsed, goal)}'),
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

  int _goalByPeriod(int monthlyGoal, int weeklyGoal) {
    if (_period == StatsPeriod.week) return weeklyGoal;
    if (_period == StatsPeriod.month) return monthlyGoal;
    return monthlyGoal * 12;
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
            ...filtered.map(
              (e) => ListTile(
                title: Text('₩${e.amount}'),
                subtitle: Text('${_formatDateTime(e.createdAt)} · ${e.memo ?? ''}'),
              ),
            ),
          ],
        );
      },
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
      painter: _PiePainter(slices),
      child: const SizedBox.expand(),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<PieSlice> slices;

  _PiePainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (p, e) => p + e.value);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * (s.value / total);
      canvas.drawArc(rect, start, sweep, true, Paint()..color = s.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

Color _sliceColor(int? id) {
  if (id == null) return Colors.grey;
  final palette = [
    const Color(0xFF8B5CF6),
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
  ];
  return palette[id.abs() % palette.length];
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

PaymentType _paymentTypeFromLabel(String value) {
  final v = value.trim().toLowerCase();
  if (v == '현금' || v == 'cash') return PaymentType.cash;
  if (v == '기타' || v == 'etc') return PaymentType.etc;
  return PaymentType.card;
}

String _formatDateTime(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _periodText(StatsPeriod period, DateTime cursor) {
  switch (period) {
    case StatsPeriod.week:
      final range = DateRangeUtil.weekRange(cursor);
      final start = DateTime.fromMillisecondsSinceEpoch(range.start);
      final end = DateTime.fromMillisecondsSinceEpoch(range.end);
      return '주간 ${start.month}/${start.day} ~ ${end.month}/${end.day}';
    case StatsPeriod.month:
      return '월간 ${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
    case StatsPeriod.year:
      return '연간 ${cursor.year}';
  }
}

double _elapsedRatio(StatsPeriod period, DateTime cursor) {
  final now = DateTime.now();
  if (period == StatsPeriod.week) {
    final currentWeekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final cursorWeekStart = DateTime(cursor.year, cursor.month, cursor.day - (cursor.weekday - 1));
    if (currentWeekStart == cursorWeekStart) {
      return now.weekday / 7;
    }
    return 1;
  }

  if (period == StatsPeriod.month) {
    final totalDays = DateTime(cursor.year, cursor.month + 1, 0).day;
    final day = (now.year == cursor.year && now.month == cursor.month) ? now.day : totalDays;
    return day / totalDays;
  }

  final totalDaysInYear = DateTime(cursor.year + 1, 1, 1)
      .difference(DateTime(cursor.year, 1, 1))
      .inDays;
  final dayOfYear = now.year == cursor.year
      ? now.difference(DateTime(now.year, 1, 1)).inDays + 1
      : totalDaysInYear;
  return dayOfYear / totalDaysInYear;
}

String _paceStatus(double spendRatio, double elapsedRatio, int goal) {
  if (goal <= 0) return '목표 미설정';
  if (spendRatio >= 1) return '목표 초과';
  if (spendRatio > elapsedRatio + 0.1) return '주의 필요';
  return '정상 범위';
}
