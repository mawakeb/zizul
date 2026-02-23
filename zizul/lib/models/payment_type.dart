enum PaymentType {
  card,
  cash,
  etc,
}

extension PaymentTypeExtension on PaymentType {
  int get value {
    switch (this) {
      case PaymentType.card:
        return 0;
      case PaymentType.cash:
        return 1;
      case PaymentType.etc:
        return 2;
    }
  }

  static PaymentType fromInt(int value) {
    switch (value) {
      case 0:
        return PaymentType.card;
      case 1:
        return PaymentType.cash;
      case 2:
        return PaymentType.etc;
      default:
        throw Exception('Invalid payment type');
    }
  }
}