import '../database/database_helper.dart';
import '../models/category_stat.dart';
import '../utils/date_range_util.dart';

class StatsRepository {
  final _db = DatabaseHelper.instance;

  Future<List<CategoryStat>> getMonthlyCategoryStats(
      DateTime date) async {
    final range = DateRangeUtil.monthRange(date);
    final result =
        await _db.getCategoryStats(range.start, range.end);
    return result.map((e) => CategoryStat.fromMap(e)).toList();
  }

  Future<List<CategoryStat>> getWeeklyCategoryStats(
      DateTime date) async {
    final range = DateRangeUtil.weekRange(date);
    final result =
        await _db.getCategoryStats(range.start, range.end);
    return result.map((e) => CategoryStat.fromMap(e)).toList();
  }
}