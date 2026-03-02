import '../../models/category.dart';
import '../../models/expense.dart';
import '../app_helpers.dart';

String escapeCsv(String text) {
  if (text.contains(',') || text.contains('"') || text.contains('\n')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String expensesToCsv(List<Expense> expenses, Map<int, Category> categoryMap) {
  final buffer = StringBuffer('id,created_at,amount,category,payment_type,memo\n');
  for (final e in expenses) {
    buffer.writeln([
      (e.id ?? '').toString(),
      e.createdAt.toIso8601String(),
      e.amount.toString(),
      categoryMap[e.categoryId]?.name ?? '',
      paymentTypeLabel(e.paymentType),
      e.memo ?? '',
    ].map(escapeCsv).join(','));
  }
  return buffer.toString();
}

List<String> parseCsvLine(String line) {
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
