import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class EmployeeHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> worker;
  const EmployeeHistoryDialog({super.key, required this.worker});

  @override
  State<EmployeeHistoryDialog> createState() => _EmployeeHistoryDialogState();
}

class _EmployeeHistoryDialogState extends State<EmployeeHistoryDialog> {
  List<Map<String, dynamic>> records = [];
  String _sortBy = 'timestamp';
  bool _ascending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await LocalDBService.database;
    final result = await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [widget.worker['name']],
      orderBy: '$_sortBy ${_ascending ? 'ASC' : 'DESC'}',
    );
    setState(() => records = result);
  }

  void _onSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _ascending = !_ascending;
      } else {
        _sortBy = column;
        _ascending = true;
      }
      _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("📖 View Worker History"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: "Back",
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.worker['name'],
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${widget.worker['role']} • Salary: \$${widget.worker['salary']}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: AppTheme.cardDecoration,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppTheme.primaryColor.withOpacity(0.1)),
                    headingTextStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                    dataRowColor: WidgetStateProperty.all(AppTheme.cardBgColor),
                    columns: [
                      DataColumn(
                        label: const Text("📅 Month"),
                        onSort: (_, __) => _onSort('month'),
                      ),
                      DataColumn(
                        label: const Text("🚫 Absent"),
                        onSort: (_, __) => _onSort('absentDays'),
                      ),
                      DataColumn(
                        label: const Text("⏱ Overtime"),
                        onSort: (_, __) => _onSort('overtimeHours'),
                      ),
                      DataColumn(
                        label: const Text("🎁 Bonus"),
                        onSort: (_, __) => _onSort('bonus'),
                      ),
                      DataColumn(
                        label: const Text("💵 Paid"),
                        onSort: (_, __) => _onSort('amountPaid'),
                      ),
                      DataColumn(
                        label: const Text("🧾 Remaining"),
                        onSort: (_, __) => _onSort('remainingBalance'),
                      ),
                      DataColumn(
                        label: const Text("📆 Date"),
                        onSort: (_, __) => _onSort('timestamp'),
                      ),
                    ],
                    rows: records.map((r) {
                      final date = DateFormat('y/MM/dd – HH:mm')
                          .format(DateTime.parse(r['timestamp']));
                      return DataRow(cells: [
                        DataCell(Text(r['month'])),
                        DataCell(Text(r['absentDays'].toString())),
                        DataCell(Text(r['overtimeHours'].toString())),
                        DataCell(Text("${r['bonus']}")),
                        DataCell(Text("${r['amountPaid']}")),
                        DataCell(Text("${r['remainingBalance']}")),
                        DataCell(Text(date)),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
