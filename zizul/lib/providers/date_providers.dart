import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedMonthProvider =
    StateProvider<DateTime>((ref) {
  return DateTime.now();
});