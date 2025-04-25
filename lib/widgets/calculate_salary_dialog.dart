// SAME IMPORTS
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  DateTime? nextSalaryDate;
  DateTime? cycleStart;
  DateTime? cycleEnd;

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

  Future<DateTime?> getLastSalaryDate(String name) async {
    final db = await LocalDBService.database;
    final result = await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [name],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isNotEmpty) {
      return DateTime.tryParse(result.first['timestamp'] as String? ?? '');
    }
    return null;
  }

  Future<double> getAdvanceToDeduct(
      String name, DateTime from, DateTime to) async {
    final db = await LocalDBService.database;
    final results = await db.query(
      'advance_payments',
      where: 'workerName = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [name, from.toIso8601String(), to.toIso8601String()],
    );
    double total = 0;
    for (var a in results) {
      total += (a['amount'] as num).toDouble();
    }
    return total;
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

  DateTime getNextSalaryDueDate(DateTime joinDate, DateTime? lastSalaryDate) {
    DateTime startFrom = DateTime(2025, 4, joinDate.day);

    if (lastSalaryDate == null || lastSalaryDate.isBefore(startFrom)) {
      return startFrom;
    }

    // 👇 Always return next due date one full month ahead of last paid
    return DateTime(
      lastSalaryDate.year,
      lastSalaryDate.month + 1,
      joinDate.day,
    );
  }

  String formatDate(DateTime dt) {
    return DateFormat('d MMMM yyyy').format(dt);
  }

  Future<void> calculateSalary() async {
    if (selectedWorker == null) return;

    int absent = int.tryParse(absentController.text) ?? 0;
    int overtime = int.tryParse(overtimeController.text) ?? 0;
    double bonus = double.tryParse(bonusController.text) ?? 0;
    double paid = double.tryParse(paidController.text) ?? 0;
    double profitShare = 0.0;

    salary = selectedWorker?['salary']?.toDouble() ?? 0;
    profitPercent = selectedWorker?['profitPercent']?.toDouble() ?? 0;

    DateTime joinDate = DateTime.tryParse(selectedWorker?['createdAt'] ?? '') ??
        DateTime(2025, 4, 1);
    DateTime? lastPaid = await getLastSalaryDate(selectedWorkerName!);
    nextSalaryDate = getNextSalaryDueDate(joinDate, lastPaid);

    cycleStart = lastPaid ?? joinDate;
    cycleEnd = nextSalaryDate!;

    if (selectedWorker?['role'] == 'Manager' ||
        selectedWorker?['role'] == 'Owner') {
      double totalSales = double.tryParse(totalSalesController.text) ?? 0;
      profitShare = (totalSales * profitPercent) / 100;
    }

    previousBalance = await getPreviousBalance(selectedWorkerName!);
    advanceDeduction =
        await getAdvanceToDeduct(selectedWorkerName!, cycleStart!, cycleEnd!);

    dailyWage = salary / 30;
    overtimePay = (dailyWage / 8) * overtime;

    totalSalary = (dailyWage * (30 - absent)) +
        overtimePay +
        bonus +
        profitShare +
        previousBalance -
        advanceDeduction;

    remainingBalance = double.parse((totalSalary - paid).toStringAsFixed(2));

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
            if (cycleStart != null && cycleEnd != null) ...[
              Text(
                "📅 Sales Cycle: ${formatDate(cycleStart!)} → ${formatDate(cycleEnd!)}",
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Enter total sales for the current salary cycle only.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
            ],
            TextField(
              controller: totalSalesController,
              decoration: _input('Total Sales This Period'),
              keyboardType: TextInputType.number,
              onChanged: (_) => calculateSalary(),
            ),
            const SizedBox(height: 10),
            Text("💼 Profit %: ${profitPercent.toStringAsFixed(2)}"),
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
          TextField(
            controller: bonusController,
            decoration: _input('Bonus'),
            keyboardType: TextInputType.number,
            onChanged: (_) => calculateSalary(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: paidController,
            decoration: _input('Amount Paid'),
            keyboardType: TextInputType.number,
            onChanged: (_) => calculateSalary(),
          ),
          const SizedBox(height: 12),
          if (nextSalaryDate != null)
            Text(
              "📅 Next Due: ${formatDate(nextSalaryDate!)}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
          const SizedBox(height: 10),
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
                  if (selectedWorkerName == null ||
                      salary == 0 ||
                      nextSalaryDate == null) {
                    setState(() {
                      _statusText = "⚠ Please select a worker.";
                      _statusColor = Colors.orange;
                    });
                    return;
                  }

                  if (DateTime.now().isBefore(nextSalaryDate!)) {
                    SystemSound.play(SystemSoundType.alert);

                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.white,
                        title: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 28),
                            SizedBox(width: 8),
                            Text("Salary Not Yet Due",
                                style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            const Text(
                              "⛔ You’re trying to pay a salary that’s not due yet.",
                              style: TextStyle(fontSize: 14.8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "📅 Next due date is: ${formatDate(nextSalaryDate!)}",
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "💡 Tip:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              "If you wish to pay in advance, record it as an Advance Payment instead.",
                              style: TextStyle(
                                  fontSize: 13.8, color: Colors.black87),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("OK",
                                style: TextStyle(fontSize: 15)),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final exists = await LocalDBService.checkIfSalaryExists(
                    workerName: selectedWorkerName!,
                    month: formatDate(nextSalaryDate!),
                  );

                  if (exists) {
                    setState(() {
                      _statusText =
                          "⚠ Salary already paid to $selectedWorkerName for ${formatDate(nextSalaryDate!)}.";
                      _statusColor = Colors.red;
                    });
                    return;
                  }

                  final record = {
                    'id': const Uuid().v4(),
                    'workerName': selectedWorkerName!,
                    'month': formatDate(nextSalaryDate!),
                    'absentDays': int.tryParse(absentController.text) ?? 0,
                    'overtimeHours': int.tryParse(overtimeController.text) ?? 0,
                    'bonus': double.tryParse(bonusController.text) ?? 0,
                    'amountPaid': double.tryParse(paidController.text) ?? 0,
                    'totalSalary': totalSalary,
                    'remainingBalance': remainingBalance,
                    'salesAmount': double.tryParse(totalSalesController.text),
                    'cycleStart': cycleStart!.toIso8601String(),
                    'cycleEnd': cycleEnd!.toIso8601String(),
                    'timestamp': nextSalaryDate!.toIso8601String(),
                  };

                  try {
                    await LocalDBService.addSalaryRecord(record);

                    // ✅ Play "cha-ching" cashier sound
                    final player = AudioPlayer();
                    await player.play(AssetSource('sounds/cha_ching.mp3'));

                    // ✅ Clear fields, but keep the selected worker
                    overtimeController.clear();
                    absentController.clear();
                    bonusController.clear();
                    paidController.clear();
                    totalSalesController.clear();
                    salary = 0;
                    profitPercent = 0;
                    dailyWage = 0;
                    overtimePay = 0;
                    totalSalary = 0;
                    remainingBalance = 0;
                    previousBalance = 0;
                    advanceDeduction = 0;
                    _statusText = null;

                    await calculateSalary(); // Refresh calculations for same worker

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
