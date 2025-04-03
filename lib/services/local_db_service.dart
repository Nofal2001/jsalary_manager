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

    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, 'salary_app.db');

    debugPrint("📍 DB Path: $path");

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2, // Bump version to enable upgrade
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    debugPrint("⬆️ Upgrading DB from v$oldVersion to v$newVersion");
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
        timestamp TEXT
      )
    ''');
  }

  // ────────────────────────────────────────────────
  // WORKER
  static Future<void> addWorker(Map<String, dynamic> workerData) async {
    final db = await database;
    await db.insert('workers', workerData);
  }

  static Future<List<Map<String, dynamic>>> getAllWorkers() async {
    final db = await database;
    return await db.query('workers');
  }

  static Future<Map<String, dynamic>?> getWorkerByName(String name) async {
    final db = await database;
    final result = await db.query(
      'workers',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ────────────────────────────────────────────────
  // SALARY
  static Future<void> addSalaryRecord(Map<String, dynamic> record) async {
    final db = await database;
    await db.insert('salary_records', record);
  }

  static Future<void> deleteWorker(String id) async {
    final db = await database;
    await db.delete(
      'workers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<bool> checkIfSalaryExists({
    required String workerName,
    required String month,
  }) async {
    final db = await database;
    final result = await db.query(
      'salary_records',
      where: 'workerName = ? AND month = ?',
      whereArgs: [workerName, month],
    );
    return result.isNotEmpty;
  }

  // ────────────────────────────────────────────────
  // ADVANCE
  static Future<void> addAdvancePayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('advance_payments', data);
  }

  // ────────────────────────────────────────────────
  // ADMIN TOOLS
  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('workers');
    await db.delete('salary_records');
    await db.delete('advance_payments');
    debugPrint("🧹 Cleared all local data.");
  }

  static Future<void> printAllWorkersToConsole() async {
    final db = await database;
    final workers = await db.query('workers');
    debugPrint("🧠 All Workers:");
    for (var w in workers) {
      debugPrint(w.toString());
    }
  }

  static Future<void> updateWorker(Map<String, dynamic> workerData) async {
    final db = await database;

    // Base update fields
    final updateFields = {
      'name': workerData['name'],
      'salary': workerData['salary'],
      'role': workerData['role'],
    };

    // Conditionally include sales/profit fields for Manager/Owner
    if (workerData['role'] == 'Manager' || workerData['role'] == 'Owner') {
      updateFields['netSales'] = workerData['netSales'] ?? 0;
      updateFields['profitPercent'] = workerData['profitPercent'] ?? 0;
    }

    await db.update(
      'workers',
      updateFields,
      where: 'id = ?',
      whereArgs: [workerData['id']],
    );
  }
}
