import 'payment_type.dart';

class ExpenseExport {
  final int id;
  final int amount;
  final DateTime createdAt;
  final String? category;
  final PaymentType paymentType;
  final String? memo;

  ExpenseExport({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.category,
    required this.paymentType,
    this.memo,
  });

  factory ExpenseExport.fromMap(Map<String, dynamic> map) {
    return ExpenseExport(
      id: map['id'],
      amount: map['amount'],
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      category: map['category'],
      paymentType:
          PaymentTypeExtension.fromInt(map['payment_type']),
      memo: map['memo'],
    );
  }
}