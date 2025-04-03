import 'package:flutter/material.dart';
import '../services/local_db_service.dart';
import '../widgets/edit_worker_dialog.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> workers = [];

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  Future<void> loadWorkers() async {
    final result = await LocalDBService.getAllWorkers();
    setState(() {
      workers = result;
    });
  }

  Future<List<Map<String, dynamic>>> getSalaryHistory(String name) async {
    final db = await LocalDBService.database;
    return await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [name],
      orderBy: 'timestamp DESC',
    );
  }

  void showWorkerDetails(Map<String, dynamic> worker) async {
    final salaryHistory = await getSalaryHistory(worker['name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(worker['name']),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("🧑 Role: ${worker['role']}"),
                Text("💰 Salary: ${worker['salary']}"),
                if (worker['netSales'] != null)
                  Text("📈 Net Sales: ${worker['netSales']}"),
                if (worker['profitPercent'] != null)
                  Text("📊 Profit %: ${worker['profitPercent']}"),
                const SizedBox(height: 20),
                const Text("📋 Salary History:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                if (salaryHistory.isEmpty) const Text("No records yet."),
                if (salaryHistory.isNotEmpty)
                  ...salaryHistory.map((record) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              "📆 ${record['month']} (${DateFormat.yMd().add_jm().format(DateTime.parse(record['timestamp']))})"),
                          Text("➕ Bonus: ${record['bonus']}"),
                          Text("🕐 Overtime: ${record['overtimeHours']}"),
                          Text("🚫 Absences: ${record['absentDays']}"),
                          Text("💸 Paid: ${record['amountPaid']}"),
                          Text("💰 Total: ${record['totalSalary']}"),
                          Text("💼 Balance: ${record['remainingBalance']}"),
                          const Divider(),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => EditWorkerDialog(
                    worker: worker,
                    onSaved: loadWorkers,
                  ),
                );
              },
              child: const Text("✏️ Edit"),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Confirm Delete"),
                    content: const Text(
                        "Are you sure you want to delete this worker?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final db = await LocalDBService.database;
                  await db.delete('workers',
                      where: 'id = ?', whereArgs: [worker['id']]);
                  await loadWorkers();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child:
                  const Text("🗑 Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Worker History'),
      ),
      body: workers.isEmpty
          ? const Center(child: Text("No workers found."))
          : ListView.builder(
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final worker = workers[index];
                return ListTile(
                  title: Text(worker['name']),
                  subtitle: Text(
                      "Role: ${worker['role']} • Salary: ${worker['salary']}"),
                  onTap: () => showWorkerDetails(worker),
                );
              },
            ),
    );
  }
}
