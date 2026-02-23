import 'package:flutter/material.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database; // DB 생성 테스트
  runApp(const ZizulApp());
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
          seedColor: const Color.fromARGB(255, 112, 68, 255), // 세련된 블루톤
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'zizul DB initialized',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}