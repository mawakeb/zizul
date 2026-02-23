class AppSettings {
  final int monthlyGoal;
  final int weeklyGoal;

  AppSettings({
    required this.monthlyGoal,
    required this.weeklyGoal,
  });

  Map<String, dynamic> toMap() {
    return {
      'monthly_goal': monthlyGoal,
      'weekly_goal': weeklyGoal,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      monthlyGoal: map['monthly_goal'],
      weeklyGoal: map['weekly_goal'],
    );
  }
}