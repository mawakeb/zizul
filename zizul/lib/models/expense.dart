import 'payment_type.dart';

class Expense {
  final int? id;
  final int amount;
  final DateTime createdAt;
  final int? categoryId;
  final PaymentType paymentType;
  final String? memo;

  Expense({
    this.id,
    required this.amount,
    required this.createdAt,
    this.categoryId,
    required this.paymentType,
    this.memo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'category_id': categoryId,
      'payment_type': paymentType.value,
      'memo': memo,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: map['amount'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      categoryId: map['category_id'],
      paymentType: PaymentTypeExtension.fromInt(map['payment_type']),
      memo: map['memo'],
    );
  }
}