import '../database/database_helper.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final _db = DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final result = await _db.getSettings();
    return AppSettings.fromMap(result);
  }

  Future<void> updateGoals(int monthly, int weekly) async {
    await _db.updateGoals(monthly, weekly);
  }

  Future<void> updateDailyNotification({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _db.updateDailyNotification(
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
  }
}
