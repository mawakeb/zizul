import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(
    const ProviderScope(
      child: ZizulApp(),
    ),
  );
}

class ZizulApp extends StatelessWidget {
  const ZizulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zizul',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 112, 68, 255),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ZizulRootShell(),
    );
  }
}

class ZizulRootShell extends StatefulWidget {
  const ZizulRootShell({super.key});

  @override
  State<ZizulRootShell> createState() => _ZizulRootShellState();
}

class _ZizulRootShellState extends State<ZizulRootShell> {
  int _selectedIndex = 0;

  static const _pages = <Widget>[
    _ExpenseAddScreen(),
    _ExpenseHistoryScreen(),
    _StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_card_outlined),
            selectedIcon: Icon(Icons.add_card),
            label: '지출 추가',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: '내역',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '통계',
          ),
        ],
      ),
    );
  }
}

class _ExpenseAddScreen extends StatelessWidget {
  const _ExpenseAddScreen();

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholder(
      title: '지출 추가',
      subtitle: '앱 기본 진입 화면',
      description: '여기에 지출 입력 폼(날짜/카테고리/금액/메모/결제수단)이 들어갑니다.',
      icon: Icons.add_card,
    );
  }
}

class _ExpenseHistoryScreen extends StatelessWidget {
  const _ExpenseHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholder(
      title: '지출 내역',
      subtitle: '월별 조회/검색/정렬/수정/삭제',
      description: '여기에 월간 합계, 달력 탭, 내역 리스트가 들어갑니다.',
      icon: Icons.list_alt,
    );
  }
}

class _StatsScreen extends StatelessWidget {
  const _StatsScreen();

  @override
  Widget build(BuildContext context) {
    return const _FeaturePlaceholder(
      title: '통계',
      subtitle: '카테고리별 통계/목표 대비 소비 페이스',
      description: '여기에 파이 차트 및 목표 대비 분석 UI가 들어갑니다.',
      icon: Icons.pie_chart,
    );
  }
}

class _FeaturePlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;

  const _FeaturePlaceholder({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 16),
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
