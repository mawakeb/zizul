
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/database_helper.dart';
import 'features/add/expense_add_screen.dart';
import 'features/history/expense_history_screen.dart';
import 'features/stats/stats_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(const ProviderScope(child: ZizulApp()));
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
          seedColor: const Color(0xFF8B5CF6),
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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ExpenseAddScreen(),
      const ExpenseHistoryScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_card), label: '추가'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: '내역'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '통계'),
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
