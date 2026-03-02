class AppSettings {
  final int monthlyGoal;
  final int weeklyGoal;
  final bool dailyNotificationEnabled;
  final int dailyNotificationHour;
  final int dailyNotificationMinute;

  AppSettings({
    required this.monthlyGoal,
    required this.weeklyGoal,
    this.dailyNotificationEnabled = false,
    this.dailyNotificationHour = 8,
    this.dailyNotificationMinute = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'monthly_goal': monthlyGoal,
      'weekly_goal': weeklyGoal,
      'daily_notification_enabled': dailyNotificationEnabled ? 1 : 0,
      'daily_notification_hour': dailyNotificationHour,
      'daily_notification_minute': dailyNotificationMinute,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      monthlyGoal: map['monthly_goal'] ?? 0,
      weeklyGoal: map['weekly_goal'] ?? 0,
      dailyNotificationEnabled: (map['daily_notification_enabled'] ?? 0) == 1,
      dailyNotificationHour: map['daily_notification_hour'] ?? 8,
      dailyNotificationMinute: map['daily_notification_minute'] ?? 0,
    );
  }
}
