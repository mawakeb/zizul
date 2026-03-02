import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../providers/category_providers.dart';
import '../../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          settingsAsync.when(
            data: (settings) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('목표 금액', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('월간: ${settings.monthlyGoal}'),
                    Text('주간: ${settings.weeklyGoal}'),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => _showGoalDialog(context, ref, settings.monthlyGoal, settings.weeklyGoal),
                      icon: const Icon(Icons.edit),
                      label: const Text('목표 수정'),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('설정 로드 실패: $e'),
          ),
          const SizedBox(height: 12),
          settingsAsync.when(
            data: (settings) => Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: settings.dailyNotificationEnabled,
                    onChanged: (enabled) async {
                      await ref.read(settingsProvider.notifier).updateDailyNotification(
                            enabled: enabled,
                            hour: settings.dailyNotificationHour,
                            minute: settings.dailyNotificationMinute,
                          );
                    },
                    title: const Text('매일 아침 푸시 알림 사용'),
                    subtitle: Text('시간 ${settings.dailyNotificationHour.toString().padLeft(2, '0')}:${settings.dailyNotificationMinute.toString().padLeft(2, '0')}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('알림 시간 변경'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: settings.dailyNotificationHour,
                          minute: settings.dailyNotificationMinute,
                        ),
                      );
                      if (picked == null) return;
                      await ref.read(settingsProvider.notifier).updateDailyNotification(
                            enabled: settings.dailyNotificationEnabled,
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                    },
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('알림 설정 로드 실패: $e'),
          ),
          const SizedBox(height: 12),
          categoriesAsync.when(
            data: (categories) => _CategorySettingsCard(categories: categories),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('카테고리 로드 실패: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGoalDialog(
    BuildContext context,
    WidgetRef ref,
    int monthlyGoal,
    int weeklyGoal,
  ) async {
    final monthlyController = TextEditingController(text: monthlyGoal.toString());
    final weeklyController = TextEditingController(text: weeklyGoal.toString());

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('목표 금액 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: monthlyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '월간 목표'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weeklyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '주간 목표'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).updateGoals(
                      monthly: int.tryParse(monthlyController.text) ?? 0,
                      weekly: int.tryParse(weeklyController.text) ?? 0,
                    );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
}

class _CategorySettingsCard extends ConsumerWidget {
  final List<Category> categories;

  const _CategorySettingsCard({required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('카테고리 관리', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (categories.isEmpty) const Text('카테고리가 없습니다.'),
            ...categories.map(
              (c) => ListTile(
                dense: true,
                leading: CircleAvatar(backgroundColor: Color(c.color)),
                title: Text(c.name),
                subtitle: Text(c.isShortcut ? '바로가기 사용' : '일반'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'toggle') {
                      await ref.read(categoriesProvider.notifier).updateCategory(
                            Category(
                              id: c.id,
                              name: c.name,
                              color: c.color,
                              isShortcut: !c.isShortcut,
                            ),
                          );
                    }
                    if (value == 'delete' && c.id != null) {
                      await ref.read(categoriesProvider.notifier).deleteCategory(c.id!);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'toggle',
                      child: Text(c.isShortcut ? '바로가기 해제' : '바로가기 지정'),
                    ),
                    const PopupMenuItem<String>(value: 'delete', child: Text('삭제')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
