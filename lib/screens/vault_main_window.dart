import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class VaultMainWindow extends StatefulWidget {
  const VaultMainWindow({super.key});

  @override
  State<VaultMainWindow> createState() => _VaultMainWindowState();
}

class _VaultMainWindowState extends State<VaultMainWindow> {
  double currentBalance = 0;
  double yearlyIncome = 0;
  double yearlyExpenses = 0;
  double yearlyNet = 0;
  List<Map<String, dynamic>> allPayments = [];
  List<Map<String, dynamic>> filteredPayments = [];

  String selectedType = 'All';
  String selectedMonth = 'All';

  @override
  void initState() {
    super.initState();
    _loadVaultData();
  }

  Future<void> _loadVaultData() async {
    final data = await LocalDBService.getVaultPayments();
    double income = 0, expense = 0, balance = 0;

    for (var entry in data) {
      double amount = (entry['amount'] as num).toDouble();
      final type = entry['type'];
      if (type == 'income') {
        income += amount;
        balance += amount;
      } else {
        expense += amount;
        balance -= amount;
      }
    }

    setState(() {
      yearlyIncome = income;
      yearlyExpenses = expense;
      yearlyNet = income - expense;
      currentBalance = balance;
      allPayments = data;
    });

    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      filteredPayments = allPayments.where((entry) {
        final typeMatch =
            selectedType == 'All' || entry['type'] == selectedType;
        final month =
            DateFormat('yyyy-MM').format(DateTime.parse(entry['timestamp']));
        final monthMatch = selectedMonth == 'All' || month == selectedMonth;
        return typeMatch && monthMatch;
      }).toList();
    });
  }

  List<String> _getAvailableMonths() {
    final months = allPayments
        .map(
            (e) => DateFormat('yyyy-MM').format(DateTime.parse(e['timestamp'])))
        .toSet()
        .toList();
    months.sort();
    return ['All', ...months];
  }

  Widget _statBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: color)),
            const SizedBox(height: 6),
            Text(
              "${value.toStringAsFixed(2)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> entry) {
    final nameController = TextEditingController(text: entry['name']);
    final amountController =
        TextEditingController(text: entry['amount'].toString());
    final noteController = TextEditingController(text: entry['note'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("✏️ Edit Transaction"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number),
            TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDBService.database;
              final updatedValues = {
                'name': nameController.text,
                'amount': double.tryParse(amountController.text) ?? 0,
                'note': noteController.text,
              };

              if (entry['type'] == 'salary') {
                await db.update(
                  'salary_records',
                  {'amountPaid': updatedValues['amount']},
                  where: 'timestamp = ? AND workerName = ?',
                  whereArgs: [entry['timestamp'], entry['name']],
                );
              } else if (entry['type'] == 'advance') {
                await db.update(
                  'advance_payments',
                  {'amount': updatedValues['amount']},
                  where: 'timestamp = ? AND workerName = ?',
                  whereArgs: [entry['timestamp'], entry['name']],
                );
              } else if (entry['type'] == 'income') {
                await db.update(
                  'incomes',
                  {
                    'name': updatedValues['name'],
                    'amount': updatedValues['amount'],
                    'notes': updatedValues['note']
                  },
                  where: 'id = ?',
                  whereArgs: [entry['id']],
                );
                await db.update('vault', updatedValues,
                    where: 'id = ?', whereArgs: [entry['id']]);
              } else if (entry['type'] == 'expense') {
                await db.update(
                  'expenses',
                  {
                    'name': updatedValues['name'],
                    'amount': updatedValues['amount'],
                    'notes': updatedValues['note']
                  },
                  where: 'id = ?',
                  whereArgs: [entry['id']],
                );
                await db.update('vault', updatedValues,
                    where: 'id = ?', whereArgs: [entry['id']]);
              }

              Navigator.pop(context);
              _loadVaultData();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🗑️ Delete Entry"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final db = await LocalDBService.database;

              if (entry['type'] == 'salary') {
                await db.delete('salary_records',
                    where: 'timestamp = ? AND workerName = ?',
                    whereArgs: [entry['timestamp'], entry['name']]);
              } else if (entry['type'] == 'advance') {
                await db.delete('advance_payments',
                    where: 'timestamp = ? AND workerName = ?',
                    whereArgs: [entry['timestamp'], entry['name']]);
              } else {
                await db
                    .delete('vault', where: 'id = ?', whereArgs: [entry['id']]);
                if (entry['type'] == 'income') {
                  await db.delete('incomes',
                      where: 'id = ?', whereArgs: [entry['id']]);
                } else if (entry['type'] == 'expense') {
                  await db.delete('expenses',
                      where: 'id = ?', whereArgs: [entry['id']]);
                }
              }

              Navigator.pop(context);
              _loadVaultData();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("🏦 Vault Overview",
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _statBox("💰 Balance", currentBalance, Colors.green.shade700),
              _statBox("⬇ Income (Year)", yearlyIncome, Colors.blue),
              _statBox("⬆ Expenses (Year)", yearlyExpenses, Colors.red),
              _statBox("📊 Net Income", yearlyNet, Colors.deepPurple),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              DropdownButton<String>(
                value: selectedType,
                onChanged: (val) {
                  if (val != null) {
                    selectedType = val;
                    _applyFilters();
                  }
                },
                items: ['All', 'income', 'expense', 'salary', 'advance']
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text("Type: $e")))
                    .toList(),
              ),
              const SizedBox(width: 20),
              DropdownButton<String>(
                value: selectedMonth,
                onChanged: (val) {
                  if (val != null) {
                    selectedMonth = val;
                    _applyFilters();
                  }
                },
                items: _getAvailableMonths()
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text("Month: $e")))
                    .toList(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          const Text("📜 Payment History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: AppTheme.cardDecoration,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: filteredPayments.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, index) {
                  final p = filteredPayments[index];
                  final color = p['type'] == 'income'
                      ? Colors.green
                      : (p['type'] == 'salary'
                          ? Colors.blue
                          : (p['type'] == 'advance'
                              ? Colors.orange
                              : Colors.redAccent));

                  final time = DateFormat('MMM d, yyyy – hh:mm a')
                      .format(DateTime.parse(p['timestamp']));

                  return GestureDetector(
                    onSecondaryTapDown: (details) async {
                      final selected = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          details.globalPosition.dx,
                          details.globalPosition.dy,
                          details.globalPosition.dx,
                          details.globalPosition.dy,
                        ),
                        items: const [
                          PopupMenuItem(value: 'edit', child: Text("✏ Edit")),
                          PopupMenuItem(
                              value: 'delete', child: Text("🗑 Delete")),
                        ],
                      );

                      if (selected == 'edit') {
                        _showEditDialog(p);
                      } else if (selected == 'delete') {
                        _confirmDelete(p);
                      }
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(
                          p['type'] == 'income'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: color,
                        ),
                      ),
                      title: Text(p['name'] ?? "Unknown"),
                      subtitle: Text(p['note'] ?? "-"),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${(p['amount'] as num).toStringAsFixed(2)}",
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(time, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
