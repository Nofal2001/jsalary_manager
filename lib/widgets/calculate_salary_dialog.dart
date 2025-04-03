import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class CalculateSalaryDialog extends StatefulWidget {
  final bool embed;
  const CalculateSalaryDialog({super.key, this.embed = false});

  @override
  State<CalculateSalaryDialog> createState() => _CalculateSalaryDialogState();
}

class _CalculateSalaryDialogState extends State<CalculateSalaryDialog> {
  final TextEditingController overtimeController = TextEditingController();
  final TextEditingController absentController = TextEditingController();
  final TextEditingController bonusController = TextEditingController();
  final TextEditingController paidController = TextEditingController();
  final TextEditingController totalSalesController = TextEditingController();

  List<Map<String, dynamic>> workers = [];
  Map<String, dynamic>? selectedWorker;
  String? selectedWorkerName;
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());

  double salary = 0;
  double profitPercent = 0;
  double dailyWage = 0;
  double overtimePay = 0;
  double totalSalary = 0;
  double remainingBalance = 0;
  double previousBalance = 0;
  double advanceDeduction = 0;

  String? _statusText;
  Color _statusColor = Colors.green;

  final List<String> months =
      List.generate(12, (i) => DateFormat('MMMM').format(DateTime(0, i + 1)));

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  Future<void> loadWorkers() async {
    final result = await LocalDBService.getAllWorkers();
    if (!mounted) return;
    setState(() => workers = result);
  }

  Future<double> getPreviousBalance(String name) async {
    final db = await LocalDBService.database;
    final result = await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [name],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return result.isNotEmpty
        ? (result.first['remainingBalance'] as num).toDouble()
        : 0.0;
  }

  Future<double> getAdvanceToDeduct(String name) async {
    final db = await LocalDBService.database;
    final lastSalaryResult = await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [name],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    String? lastSalaryTimestamp;
    if (lastSalaryResult.isNotEmpty) {
      lastSalaryTimestamp = lastSalaryResult.first['timestamp'] as String?;
    }

    final advanceResults = await db.query(
      'advance_payments',
      where: lastSalaryTimestamp != null
          ? 'workerName = ? AND timestamp > ?'
          : 'workerName = ?',
      whereArgs:
          lastSalaryTimestamp != null ? [name, lastSalaryTimestamp] : [name],
    );

    double totalAdvance = 0.0;
    for (var a in advanceResults) {
      totalAdvance += (a['amount'] as num).toDouble();
    }
    return totalAdvance;
  }

  void calculateSalary() async {
    int absent = int.tryParse(absentController.text) ?? 0;
    int overtime = int.tryParse(overtimeController.text) ?? 0;
    double bonus = double.tryParse(bonusController.text) ?? 0;
    double paid = double.tryParse(paidController.text) ?? 0;

    double profitShare = 0.0;

    if (selectedWorkerName != null) {
      previousBalance = await getPreviousBalance(selectedWorkerName!);
      advanceDeduction = await getAdvanceToDeduct(selectedWorkerName!);

      final role = selectedWorker?['role'] ?? 'Worker';
      salary = selectedWorker?['salary']?.toDouble() ?? 0;
      profitPercent = selectedWorker?['profitPercent']?.toDouble() ?? 0;

      if (role == 'Manager' || role == 'Owner') {
        double totalSales = double.tryParse(totalSalesController.text) ?? 0;
        profitShare = (totalSales * profitPercent) / 100;
      }
    }

    dailyWage = salary / 30;
    overtimePay = (dailyWage / 8) * overtime;

    totalSalary = (dailyWage * (30 - absent)) +
        overtimePay +
        bonus +
        profitShare +
        previousBalance -
        advanceDeduction;

    remainingBalance = totalSalary - paid;

    setState(() {});
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("🧮 Calculate Salary",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedWorkerName,
            items: workers
                .map((worker) => DropdownMenuItem<String>(
                      value: worker['name'],
                      child: Text(worker['name']),
                    ))
                .toList(),
            onChanged: (value) {
              final worker = workers.firstWhere((w) => w['name'] == value);
              setState(() {
                selectedWorkerName = value;
                selectedWorker = worker;
                totalSalesController.clear();
              });
              calculateSalary();
            },
            decoration: _input('Worker Name'),
          ),
          const SizedBox(height: 10),
          if ((selectedWorker?['role'] == 'Manager' ||
              selectedWorker?['role'] == 'Owner')) ...[
            TextField(
              controller: totalSalesController,
              decoration: _input('Total Sales This Month'),
              keyboardType: TextInputType.number,
              onChanged: (_) => calculateSalary(),
            ),
            const SizedBox(height: 8),
            Text("💼 Profit %: ${profitPercent.toStringAsFixed(2)}"),
            const SizedBox(height: 4),
            if (totalSalesController.text.isNotEmpty)
              Text(
                "💡 Profit: \$${((double.tryParse(totalSalesController.text) ?? 0) * profitPercent / 100).toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.black87),
              ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: overtimeController,
                  decoration: _input('Overtime'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => calculateSalary(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: absentController,
                  decoration: _input('Absent'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => calculateSalary(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedMonth,
            items: months
                .map((month) =>
                    DropdownMenuItem(value: month, child: Text(month)))
                .toList(),
            onChanged: (value) => setState(() => selectedMonth = value!),
            decoration: _input('Month'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: bonusController,
            decoration: _input('Bonus'),
            keyboardType: TextInputType.number,
            onChanged: (_) => calculateSalary(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: paidController,
            decoration: _input('Amount Given'),
            keyboardType: TextInputType.number,
            onChanged: (_) => calculateSalary(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6EF),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("💳 Previous: ${previousBalance.toStringAsFixed(2)}"),
                Text("💳 Advance: -${advanceDeduction.toStringAsFixed(2)}"),
                const Divider(height: 16),
                Text("💰 Total: ${totalSalary.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
                Text("🧾 Remaining: ${remainingBalance.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!widget.embed)
                TextButton(
                  child: const Text("❌ Cancel"),
                  onPressed: () => Navigator.pop(context),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  if (selectedWorkerName == null || salary == 0) {
                    setState(() {
                      _statusText = "⚠ Please select a worker.";
                      _statusColor = Colors.orange;
                    });
                    return;
                  }

                  final exists = await LocalDBService.checkIfSalaryExists(
                    workerName: selectedWorkerName!,
                    month: selectedMonth,
                  );

                  if (exists) {
                    setState(() {
                      _statusText =
                          "⚠ Salary already paid to $selectedWorkerName for $selectedMonth.";
                      _statusColor = Colors.red;
                    });
                    return;
                  }

                  final record = {
                    'id': const Uuid().v4(),
                    'workerName': selectedWorkerName!,
                    'month': selectedMonth,
                    'absentDays': int.tryParse(absentController.text) ?? 0,
                    'overtimeHours': int.tryParse(overtimeController.text) ?? 0,
                    'bonus': double.tryParse(bonusController.text) ?? 0,
                    'amountPaid': double.tryParse(paidController.text) ?? 0,
                    'totalSalary': totalSalary,
                    'remainingBalance': remainingBalance,
                    'timestamp': DateTime.now().toIso8601String(),
                  };

                  try {
                    await LocalDBService.addSalaryRecord(record);
                    if (!context.mounted) return;
                    if (!widget.embed) Navigator.pop(context);
                    AppTheme.showSuccessSnackbar(
                        context, "✅ Salary record saved.");
                  } catch (e) {
                    setState(() {
                      _statusText = "❌ Failed to save salary: $e";
                      _statusColor = Colors.red;
                    });
                  }
                },
                icon: const Text("💵", style: TextStyle(fontSize: 18)),
                label: const Text("Pay Salary"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
          if (_statusText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _statusText!,
                style: TextStyle(color: _statusColor),
              ),
            ),
        ],
      ),
    );

    return widget.embed
        ? content
        : Dialog(
            insetPadding: const EdgeInsets.all(40),
            backgroundColor: AppTheme.bgColor,
            child: content,
          );
  }
}
