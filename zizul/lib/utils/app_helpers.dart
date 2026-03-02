import 'package:flutter/material.dart';

import '../models/payment_type.dart';
import '../utils/date_range_util.dart';
import '../features/stats/stats_period.dart';

String paymentTypeLabel(PaymentType type) {
  switch (type) {
    case PaymentType.card:
      return '카드';
    case PaymentType.cash:
      return '현금';
    case PaymentType.etc:
      return '기타';
  }
}

PaymentType paymentTypeFromLabel(String value) {
  final v = value.trim().toLowerCase();
  if (v == '현금' || v == 'cash') return PaymentType.cash;
  if (v == '기타' || v == 'etc') return PaymentType.etc;
  return PaymentType.card;
}

String formatDateTime(DateTime d) {
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String periodText(StatsPeriod period, DateTime cursor) {
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

double elapsedRatio(StatsPeriod period, DateTime cursor) {
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

String paceStatus(double spendRatio, double elapsed, int goal) {
  if (goal <= 0) return '목표 미설정';
  if (spendRatio >= 1) return '목표 초과';
  if (spendRatio > elapsed + 0.1) return '주의 필요';
  return '정상 범위';
}

Color sliceColor(int? id) {
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
