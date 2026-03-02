import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/payment_type.dart';
import '../../providers/category_providers.dart';
import '../../providers/expense_providers.dart';
import '../../utils/app_helpers.dart';

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
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(categoriesProvider.notifier).add(
                      Category(name: name, color: const Color(0xFF8B5CF6).value, isShortcut: false),
                    );
                if (context.mounted) Navigator.pop(context);
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
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
              subtitle: Text(formatDateTime(_dateTime)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) => DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: InputDecoration(
                  labelText: '카테고리 (선택)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addCategory,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('선택 안함')),
                  ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
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
                  label: Text(paymentTypeLabel(type)),
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
