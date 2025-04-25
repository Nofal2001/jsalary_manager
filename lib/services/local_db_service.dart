import 'dart:io';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LocalDBService {
  static Database? _db;
  static bool _loggingEnabled = false;

  // Structured migration framework - maps version numbers to migration functions
  static final Map<int, Function(Database)> _migrations = {
    2: (db) async {
      final cols = (await db.rawQuery("PRAGMA table_info(workers);"))
          .map((e) => e['name'])
          .toList();
      if (!cols.contains('joinDate')) {
        await db.execute("ALTER TABLE workers ADD COLUMN joinDate TEXT;");
      }
    },
    10: (db) async {
      final workersCols = (await db.rawQuery("PRAGMA table_info(workers);"))
          .map((e) => e['name'])
          .toList();
      if (!workersCols.contains('joinDate')) {
        await db.execute("ALTER TABLE workers ADD COLUMN joinDate TEXT;");
      }

      final clientsCols = (await db.rawQuery("PRAGMA table_info(clients);"))
          .map((e) => e['name'])
          .toList();
      if (!clientsCols.contains('joinDate')) {
        await db.execute("ALTER TABLE clients ADD COLUMN joinDate TEXT;");
      }
    },
    // Future migrations can be added here
  };

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
        version: 10, // Current version
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    _logOperation('CREATE', 'DATABASE', 'Creating database version $version');
    await _createAllTables(db);
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    debugPrint("⬆️ DB upgrade from $oldV to $newV");
    _logOperation('UPGRADE', 'DATABASE', 'Upgrading from $oldV to $newV');

    // Record this upgrade in version history
    await _recordVersionUpdate(db, oldV, newV);

    // Apply migrations in order
    for (int v = oldV + 1; v <= newV; v++) {
      if (_migrations.containsKey(v)) {
        try {
          _logOperation(
              'MIGRATION', 'DATABASE', 'Applying migration for version $v');
          await _migrations[v]!(db);
          _logOperation('MIGRATION', 'DATABASE',
              'Successfully applied migration for version $v');
        } catch (e) {
          _logOperation(
              'ERROR', 'DATABASE', 'Migration failed for version $v: $e');
          rethrow;
        }
      }
    }

    // Always ensure all tables exist with the latest schema
    await _createAllTables(db);
  }

  static Future<void> _recordVersionUpdate(
      Database db, int oldVersion, int newVersion) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS version_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          oldVersion INTEGER,
          newVersion INTEGER,
          updateDate TEXT
        )
      ''');

      await db.insert('version_history', {
        'oldVersion': oldVersion,
        'newVersion': newVersion,
        'updateDate': DateTime.now().toIso8601String()
      });
    } catch (e) {
      debugPrint("Failed to record version history: $e");
      // Don't rethrow - this shouldn't block the upgrade
    }
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
        joinDate TEXT
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
        salesAmount REAL,
        cycleStart TEXT,
        cycleEnd TEXT,
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
        joinDate TEXT
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

  // ─────────── LOGGING ───────────
  static void enableLogging(bool enable) {
    _loggingEnabled = enable;
    _logOperation(
        'CONFIG', 'SYSTEM', 'Logging ${enable ? 'enabled' : 'disabled'}');
  }

  static void _logOperation(String operation, String table, [dynamic data]) {
    if (_loggingEnabled) {
      debugPrint('DB [$table] $operation: ${data ?? ''}');
    }
  }

  // ─────────── BACKUP & RESTORE ───────────
  static Future<String> backupDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final dbPath =
        join((await getApplicationDocumentsDirectory()).path, 'salary_app.db');
    final backupPath = join((await getApplicationDocumentsDirectory()).path,
        'salary_app_backup_${DateTime.now().millisecondsSinceEpoch}.db');

    await File(dbPath).copy(backupPath);
    _logOperation('BACKUP', 'DATABASE', 'Backup created at $backupPath');
    return backupPath;
  }

  static Future<bool> restoreFromBackup(String backupPath) async {
    try {
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      final dbPath = join(
          (await getApplicationDocumentsDirectory()).path, 'salary_app.db');
      await File(backupPath).copy(dbPath);
      _logOperation('RESTORE', 'DATABASE', 'Restored from $backupPath');
      return true;
    } catch (e) {
      debugPrint("Restore failed: $e");
      _logOperation('ERROR', 'DATABASE', 'Restore failed: $e');
      return false;
    }
  }

  // ─────────── DATA VALIDATION ───────────
  static Future<Map<String, bool>> validateDatabaseIntegrity() async {
    final db = await database;
    final results = <String, bool>{};

    try {
      await db.rawQuery('PRAGMA integrity_check');
      results['integrity'] = true;
    } catch (e) {
      results['integrity'] = false;
    }

    // Check essential tables exist
    for (final table in ['workers', 'salary_records', 'clients', 'vault']) {
      try {
        await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
        results[table] = true;
      } catch (e) {
        results[table] = false;
      }
    }

    _logOperation(
        'VALIDATION', 'DATABASE', 'Integrity check results: $results');
    return results;
  }

  // ─────────── FEATURE FLAGS ───────────
  static Future<Map<String, dynamic>> getFeatureFlags() async {
    final db = await database;
    final version = await db.getVersion();

    final flags = {
      'workerJoinDate': version >= 10,
      'clientJoinDate': version >= 10,
      // Add more features as your app evolves
    };

    _logOperation('FEATURES', 'SYSTEM', 'Feature flags: $flags');
    return flags;
  }

  // ─────────── DATA EXPORT & IMPORT ───────────
  static Future<String> exportDatabaseToJson() async {
    final db = await database;
    final export = <String, List<Map<String, dynamic>>>{};

    for (final table in [
      'workers',
      'salary_records',
      'advance_payments',
      'clients',
      'incomes',
      'expenses',
      'vault'
    ]) {
      export[table] = await db.query(table);
    }

    final exportPath = join((await getApplicationDocumentsDirectory()).path,
        'salary_app_export_${DateTime.now().millisecondsSinceEpoch}.json');
    await File(exportPath).writeAsString(jsonEncode(export));
    _logOperation('EXPORT', 'DATABASE', 'Exported to $exportPath');
    return exportPath;
  }

  static Future<bool> importDatabaseFromJson(String jsonPath) async {
    try {
      final jsonString = await File(jsonPath).readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final db = await database;
      await db.transaction((txn) async {
        for (final table in data.keys) {
          await txn.delete(table);
          for (final record in data[table]) {
            await txn.insert(table, Map<String, dynamic>.from(record));
          }
        }
      });

      _logOperation('IMPORT', 'DATABASE', 'Imported data from $jsonPath');
      return true;
    } catch (e) {
      debugPrint("Import failed: $e");
      _logOperation('ERROR', 'DATABASE', 'Import failed: $e');
      return false;
    }
  }

  // ─────────── DATABASE VERSION INFO ───────────
  static Future<int> getCurrentVersion() async {
    final db = await database;
    return db.getVersion();
  }

  static Future<List<Map<String, dynamic>>> getVersionHistory() async {
    final db = await database;
    try {
      return await db.query('version_history', orderBy: 'updateDate DESC');
    } catch (e) {
      _logOperation('ERROR', 'DATABASE', 'Failed to get version history: $e');
      return [];
    }
  }

  // ─────────── WORKERS ───────────
  static Future<void> addWorker(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('workers', data);
    _logOperation('INSERT', 'workers', data['name']);
  }

  static Future<List<Map<String, dynamic>>> getAllWorkers() async {
    final db = await database;
    _logOperation('QUERY', 'workers', 'Getting all workers');
    return db.query('workers');
  }

  static Future<void> deleteWorker(String id) async {
    final db = await database;
    await db.delete('workers', where: 'id = ?', whereArgs: [id]);
    _logOperation('DELETE', 'workers', 'Worker ID: $id');
  }

  static Future<void> updateWorker(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('workers', data, where: 'id = ?', whereArgs: [data['id']]);
    _logOperation('UPDATE', 'workers', 'Worker: ${data['name']}');
  }

  static Future<Map<String, dynamic>?> getWorkerByName(String name) async {
    final db = await database;
    final res = await db.query('workers', where: 'name = ?', whereArgs: [name]);
    _logOperation('QUERY', 'workers', 'Worker by name: $name');
    return res.isNotEmpty ? res.first : null;
  }

  // Advanced worker queries
  static Future<List<Map<String, dynamic>>> getWorkersBySalaryRange(
      double min, double max) async {
    final db = await database;
    _logOperation('QUERY', 'workers', 'Salary range: $min-$max');
    return db.query(
      'workers',
      where: 'salary BETWEEN ? AND ?',
      whereArgs: [min, max],
    );
  }

  static Future<void> bulkInsertWorkers(
      List<Map<String, dynamic>> workers) async {
    final db = await database;
    final batch = db.batch();
    for (final worker in workers) {
      batch.insert('workers', worker);
    }
    await batch.commit(noResult: true);
    _logOperation('BULK_INSERT', 'workers', 'Added ${workers.length} workers');
  }

  // ─────────── SALARY ───────────
  static Future<void> addSalaryRecord(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('salary_records', data);
    _logOperation('INSERT', 'salary_records',
        'Worker: ${data['workerName']}, Month: ${data['month']}');
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
    _logOperation('CHECK', 'salary_records',
        'Worker: $workerName, Month: $month, Exists: ${res.isNotEmpty}');
    return res.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getSalaryRecords({
    String? workerName,
    String? month,
  }) async {
    final db = await database;

    if (workerName != null && month != null) {
      return db.query(
        'salary_records',
        where: 'workerName = ? AND month = ?',
        whereArgs: [workerName, month],
      );
    } else if (workerName != null) {
      return db.query(
        'salary_records',
        where: 'workerName = ?',
        whereArgs: [workerName],
      );
    } else if (month != null) {
      return db.query(
        'salary_records',
        where: 'month = ?',
        whereArgs: [month],
      );
    } else {
      return db.query('salary_records');
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentPayments(
      {int limit = 10}) async {
    final db = await database;
    _logOperation('QUERY', 'salary_records', 'Recent payments limit: $limit');
    return db.query(
      'salary_records',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ─────────── ADVANCE ───────────
  static Future<void> addAdvancePayment(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('advance_payments', data);
    _logOperation('INSERT', 'advance_payments',
        'Worker: ${data['workerName']}, Amount: ${data['amount']}');
  }

  static Future<List<Map<String, dynamic>>> getAdvancePaymentsByWorker(
      String workerName) async {
    final db = await database;
    return db.query(
      'advance_payments',
      where: 'workerName = ?',
      whereArgs: [workerName],
    );
  }

  // ─────────── CLIENTS ───────────
  static Future<void> addClient(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('clients', data);
    _logOperation('INSERT', 'clients', 'Client: ${data['name']}');
  }

  static Future<List<Map<String, dynamic>>> getAllClients() async {
    final db = await database;
    _logOperation('QUERY', 'clients', 'Getting all clients');
    return db.query('clients');
  }

  static Future<void> updateClient(Map<String, dynamic> data) async {
    final db = await database;
    await db.update('clients', data, where: 'id = ?', whereArgs: [data['id']]);
    _logOperation('UPDATE', 'clients', 'Client: ${data['name']}');
  }

  static Future<void> deleteClient(String id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
    _logOperation('DELETE', 'clients', 'Client ID: $id');
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
    _logOperation('INSERT', 'incomes',
        'Amount: ${data['amount']}, Name: ${data['name'] ?? 'Income'}');
  }

  static Future<List<Map<String, dynamic>>> getAllIncomes() async {
    final db = await database;
    _logOperation('QUERY', 'incomes', 'Getting all incomes');
    return db.query('incomes');
  }

  static Future<List<Map<String, dynamic>>> getIncomesByPeriod(
      DateTime start, DateTime end) async {
    final db = await database;
    return db.query(
      'incomes',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
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
    _logOperation('INSERT', 'expenses',
        'Amount: ${data['amount']}, Name: ${data['name'] ?? 'Expense'}');
  }

  static Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    _logOperation('QUERY', 'expenses', 'Getting all expenses');
    return db.query('expenses');
  }

  static Future<List<Map<String, dynamic>>> getExpensesByPeriod(
      DateTime start, DateTime end) async {
    final db = await database;
    return db.query(
      'expenses',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
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
    ]..sort((a, b) => DateTime.parse(b['timestamp'] as String)
        .compareTo(DateTime.parse(a['timestamp'] as String)));
  }

  static Future<Map<String, dynamic>> getFinancialSummary() async {
    final db = await database;

    // Get total income
    final incomeResult =
        await db.rawQuery('SELECT SUM(amount) as total FROM incomes');
    final totalIncome = incomeResult.first['total'] ?? 0;

    // Get total expenses
    final expenseResult =
        await db.rawQuery('SELECT SUM(amount) as total FROM expenses');
    final totalExpense = expenseResult.first['total'] ?? 0;

    // Get total salaries paid
    final salaryResult = await db
        .rawQuery('SELECT SUM(amountPaid) as total FROM salary_records');
    final totalSalary = salaryResult.first['total'] ?? 0;

    // Get total advances
    final advanceResult =
        await db.rawQuery('SELECT SUM(amount) as total FROM advance_payments');
    final totalAdvance = advanceResult.first['total'] ?? 0;

    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'totalSalary': totalSalary,
      'totalAdvance': totalAdvance,
      'netBalance':
          (totalIncome as num) - (totalExpense as num) - (totalSalary as num),
    };
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
    _logOperation('CLEAR', 'ALL', 'Cleared all data');
  }

  // ─────────── NAME UPDATE PROPAGATION ───────────
  static Future<void> updateNameReferences(
      String oldName, String newName) async {
    final db = await database;

    await db.update('incomes', {'name': newName},
        where: 'name = ?', whereArgs: [oldName]);

    await db.update('expenses', {'name': newName},
        where: 'name = ?', whereArgs: [oldName]);

    await db.update('vault', {'name': newName},
        where: 'name = ?', whereArgs: [oldName]);

    _logOperation(
        'UPDATE', 'NAMES', 'Updated references from $oldName to $newName');
  }
}
