import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LocalDBService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'salary_app.db');

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7, // ✅ Updated version
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    debugPrint("⬆️ DB upgrade from $oldV to $newV");

    if (oldV < 3) {
      final cols = (await db.rawQuery("PRAGMA table_info(advance_payments);"))
          .map((e) => e['name'])
          .toList();
      if (!cols.contains('month')) {
        await db.execute("ALTER TABLE advance_payments ADD COLUMN month TEXT;");
      }
    }

    if (oldV < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS clients (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          phone TEXT,
          notes TEXT,
          timestamp TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS incomes (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          notes TEXT,
          timestamp TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          notes TEXT,
          timestamp TEXT
        )
      ''');
    }

    if (oldV < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS vault (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
    }

    if (oldV < 6) {
      final clientCols = (await db.rawQuery("PRAGMA table_info(clients);"))
          .map((e) => e['name'])
          .toList();
      if (!clientCols.contains('createdAt')) {
        await db.execute("ALTER TABLE clients ADD COLUMN createdAt TEXT;");
        debugPrint("✅ Added 'createdAt' to clients");
      }
    }

    if (oldV < 7) {
      final incomeCols = (await db.rawQuery("PRAGMA table_info(incomes);"))
          .map((e) => e['name'])
          .toList();
      if (!incomeCols.contains('name')) {
        await db.execute("ALTER TABLE incomes ADD COLUMN name TEXT;");
        debugPrint("✅ Added 'name' column to incomes");
      }

      final expenseCols = (await db.rawQuery("PRAGMA table_info(expenses);"))
          .map((e) => e['name'])
          .toList();
      if (!expenseCols.contains('name')) {
        await db.execute("ALTER TABLE expenses ADD COLUMN name TEXT;");
        debugPrint("✅ Added 'name' column to expenses");
      }
    }

    await _createAllTables(db);
  }

  static Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        salary REAL NOT NULL,
        role TEXT NOT NULL,
        netSales REAL,
        profitPercent REAL,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS salary_records (
        id TEXT PRIMARY KEY,
        workerName TEXT NOT NULL,
        month TEXT NOT NULL,
        absentDays INTEGER,
        overtimeHours INTEGER,
        bonus REAL,
        amountPaid REAL,
        totalSalary REAL,
        remainingBalance REAL,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS advance_payments (
        id TEXT PRIMARY KEY,
        workerName TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT,
        month TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        notes TEXT,
        timestamp TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS incomes (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        name TEXT,
        notes TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        name TEXT,
        notes TEXT,
        timestamp TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vault (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  // ─────────── WORKERS ───────────
  static Future<void> addWorker(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('workers', data);
  }

  static Future<List<Map<String, dynamic>>> getAllWorkers() async {
    final db = await database;
    return db.query('workers');
  }

  static Future<void> deleteWorker(String id) async {
    final db = await database;
    await db.delete('workers', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> updateWorker(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('workers', data, where: 'id = ?', whereArgs: [data['id']]);
  }

  static Future<Map<String, dynamic>?> getWorkerByName(String name) async {
    final db = await database;
    final res = await db.query('workers', where: 'name = ?', whereArgs: [name]);
    return res.isNotEmpty ? res.first : null;
  }

  // ─────────── SALARY ───────────
  static Future<void> addSalaryRecord(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('salary_records', data);
  }

  static Future<bool> checkIfSalaryExists({
    required String workerName,
    required String month,
  }) async {
    final db = await database;
    final res = await db.query(
      'salary_records',
      where: 'workerName = ? AND month = ?',
      whereArgs: [workerName, month],
    );
    return res.isNotEmpty;
  }

  // ─────────── ADVANCE ───────────
  static Future<void> addAdvancePayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('advance_payments', data);
  }

  // ─────────── CLIENTS ───────────
  static Future<void> addClient(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('clients', data);
  }

  static Future<List<Map<String, dynamic>>> getAllClients() async {
    final db = await database;
    return db.query('clients');
  }

  // ─────────── INCOME ───────────
  static Future<void> addIncome(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('incomes', data);
    await db.insert('vault', {
      'id': data['id'],
      'type': 'income',
      'name': data['name'] ?? 'Income',
      'amount': data['amount'],
      'note': data['notes'] ?? '',
      'timestamp': data['timestamp'],
    });
  }

  static Future<List<Map<String, dynamic>>> getAllIncomes() async {
    final db = await database;
    return db.query('incomes');
  }

  // ─────────── EXPENSE ───────────
  static Future<void> addExpense(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('expenses', data);
    await db.insert('vault', {
      'id': data['id'],
      'type': 'expense',
      'name': data['name'] ?? 'Expense',
      'amount': data['amount'],
      'note': data['notes'] ?? '',
      'timestamp': data['timestamp'],
    });
  }

  static Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    return db.query('expenses');
  }

  // ─────────── VAULT ───────────
  static Future<List<Map<String, dynamic>>> getVaultPayments() async {
    final db = await database;
    final income =
        await db.query('vault', where: 'type = ?', whereArgs: ['income']);
    final expense =
        await db.query('vault', where: 'type = ?', whereArgs: ['expense']);
    final salary = await db.query('salary_records');
    final advances = await db.query('advance_payments');

    final salaryMapped = salary.map((r) => {
          'type': 'salary',
          'name': r['workerName'],
          'amount': r['amountPaid'],
          'note': 'Salary Payment',
          'timestamp': r['timestamp'],
        });

    final advanceMapped = advances.map((r) => {
          'type': 'advance',
          'name': r['workerName'],
          'amount': r['amount'],
          'note': 'Advance Payment',
          'timestamp': r['timestamp'],
        });

    return [
      ...income,
      ...expense,
      ...salaryMapped,
      ...advanceMapped,
    ]..sort((a, b) => DateTime.parse(b['timestamp'])
        .compareTo(DateTime.parse(a['timestamp'])));
  }

  // ─────────── ADMIN ───────────
  static Future<void> clearAllData() async {
    final db = await database;
    for (final table in [
      'workers',
      'salary_records',
      'advance_payments',
      'clients',
      'incomes',
      'expenses',
      'vault',
    ]) {
      await db.delete(table);
    }
  }
}
