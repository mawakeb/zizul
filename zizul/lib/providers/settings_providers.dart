import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import 'repository_providers.dart';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  late final SettingsRepository _repo;

  @override
  Future<AppSettings> build() async {
    _repo = ref.read(settingsRepositoryProvider);
    return _repo.getSettings();
  }

  Future<void> updateGoals({required int monthly, required int weekly}) async {
    await _repo.updateGoals(monthly, weekly);
    state = await AsyncValue.guard(_repo.getSettings);
  }

  Future<void> updateDailyNotification({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _repo.updateDailyNotification(
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
    state = await AsyncValue.guard(_repo.getSettings);
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
