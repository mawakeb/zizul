class DateRange {
  final int start;
  final int end;

  DateRange(this.start, this.end);
}

class DateRangeUtil {
  static DateRange monthRange(DateTime date) {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
    return DateRange(
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
  }

  static DateRange weekRange(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final weekStart = DateTime(start.year, start.month, start.day);
    final weekEnd = weekStart
        .add(const Duration(days: 7))
        .subtract(const Duration(milliseconds: 1));
    return DateRange(
      weekStart.millisecondsSinceEpoch,
      weekEnd.millisecondsSinceEpoch,
    );
  }

  static DateRange yearRange(DateTime date) {
    final start = DateTime(date.year, 1, 1);
    final end = DateTime(date.year + 1, 1, 1)
        .subtract(const Duration(milliseconds: 1));
    return DateRange(
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
  }
}
