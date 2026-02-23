import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _dbName = 'zizul.db';
  static const _dbVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color INTEGER NOT NULL,
        is_shortcut INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expense (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        category_id INTEGER,
        payment_type INTEGER NOT NULL,
        memo TEXT,
        FOREIGN KEY (category_id) REFERENCES category(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        monthly_goal INTEGER NOT NULL DEFAULT 0,
        weekly_goal INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('INSERT INTO settings (id) VALUES (1)');

    await db.execute('CREATE INDEX idx_expense_created_at ON expense(created_at)');
    await db.execute('CREATE INDEX idx_expense_category ON expense(category_id)');
    await db.execute('CREATE INDEX idx_expense_payment ON expense(payment_type)');
  }

  /* =========================
      EXPENSE
  ========================= */

  Future<int> insertExpense(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('expense', data);
  }

  Future<List<Map<String, dynamic>>> getExpensesBetween(
      int start, int end) async {
    final db = await instance.database;
    return await db.query(
      'expense',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [start, end],
      orderBy: 'created_at DESC',
    );
  }

  Future<int?> getTotalBetween(int start, int end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM expense
      WHERE created_at BETWEEN ? AND ?
    ''', [start, end]);

    return result.first['total'] as int?;
  }

  Future<int> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update(
      'expense',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      'expense',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMultipleExpenses(List<int> ids) async {
    final db = await instance.database;
    return await db.delete(
      'expense',
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  /* =========================
      CATEGORY
  ========================= */

  Future<int> insertCategory(Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert('category', data);
  }

  Future<List<Map<String, dynamic>>> getAllCategories() async {
    final db = await instance.database;
    return await db.query('category', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> getShortcutCategories() async {
    final db = await instance.database;
    return await db.query(
      'category',
      where: 'is_shortcut = 1',
      orderBy: 'name ASC',
    );
  }

  Future<int> updateCategory(int id, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.update(
      'category',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete(
      'category',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /* =========================
      SETTINGS
  ========================= */

  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    final result =
        await db.query('settings', where: 'id = 1', limit: 1);
    return result.first;
  }

  Future<int> updateGoals(int monthly, int weekly) async {
    final db = await instance.database;
    return await db.update(
      'settings',
      {
        'monthly_goal': monthly,
        'weekly_goal': weekly,
      },
      where: 'id = 1',
    );
  }

  /* =========================
      STATISTICS
  ========================= */

  Future<List<Map<String, dynamic>>> getCategoryStats(
      int start, int end) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM expense
      WHERE created_at BETWEEN ? AND ?
      GROUP BY category_id
    ''', [start, end]);
  }

  /* =========================
      CSV EXPORT
  ========================= */

  Future<List<Map<String, dynamic>>> exportAllExpenses() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        e.id,
        e.amount,
        e.created_at,
        c.name as category,
        e.payment_type,
        e.memo
      FROM expense e
      LEFT JOIN category c ON e.category_id = c.id
      ORDER BY e.created_at DESC
    ''');
  }

  /* =========================
      CLOSE
  ========================= */

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}