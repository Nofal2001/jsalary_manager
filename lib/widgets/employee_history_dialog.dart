import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:jsalary_manager/services/settings_service.dart';

class EmployeeHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> worker;
  const EmployeeHistoryDialog({super.key, required this.worker});

  @override
  State<EmployeeHistoryDialog> createState() => _EmployeeHistoryDialogState();
}

class _EmployeeHistoryDialogState extends State<EmployeeHistoryDialog> {
  List<Map<String, dynamic>> allRecords = [];
  String selectedType = 'All';
  String selectedMonth = 'All';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await LocalDBService.database;

    final salary = await db.query(
      'salary_records',
      where: 'workerName = ?',
      whereArgs: [widget.worker['name']],
    );

    final advance = await db.query(
      'advance_payments',
      where: 'workerName = ?',
      whereArgs: [widget.worker['name']],
    );

    final combined = [
      ...salary.map((s) => {
            'type': 'Salary',
            'month': s['month'] ?? '',
            'absentDays': s['absentDays'].toString(),
            'overtimeHours': s['overtimeHours'].toString(),
            'bonus': s['bonus'].toString(),
            'amountPaid': s['amountPaid'].toString(),
            'remainingBalance': s['remainingBalance'].toString(),
            'timestamp': s['timestamp'].toString(),
          }),
      ...advance.map((a) => {
            'type': 'Advance',
            'month': a['month'] ?? '',
            'absentDays': '',
            'overtimeHours': '',
            'bonus': '',
            'amountPaid': a['amount'].toString(),
            'remainingBalance': '',
            'timestamp': a['timestamp'].toString(),
          }),
    ];

    combined.sort((a, b) {
      final tsA =
          DateTime.tryParse(a['timestamp'].toString()) ?? DateTime(2000);
      final tsB =
          DateTime.tryParse(b['timestamp'].toString()) ?? DateTime(2000);
      return tsB.compareTo(tsA);
    });

    setState(() {
      allRecords = combined;
    });
  }

  List<String> getAvailableMonths() {
    final months =
        allRecords.map((r) => r['month']?.toString() ?? '').toSet().toList();
    months.removeWhere((m) => m.isEmpty);
    months.sort();
    return ['All', ...months];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = allRecords.where((r) {
      final matchType = selectedType == 'All' || r['type'] == selectedType;
      final matchMonth = selectedMonth == 'All' || r['month'] == selectedMonth;
      return matchType && matchMonth;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("📖 Worker Payment History"),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
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
                      Text(widget.worker['name'],
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${widget.worker['role']} • Salary: \$${widget.worker['salary']}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const Spacer(), // <-- Pushes the export button to the right
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text("Export"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: _exportToExcel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text("All Types")),
                    DropdownMenuItem(value: 'Salary', child: Text("Salary")),
                    DropdownMenuItem(value: 'Advance', child: Text("Advance")),
                  ],
                  onChanged: (val) => setState(() => selectedType = val!),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: selectedMonth,
                  items: getAvailableMonths()
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedMonth = val!),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: AppTheme.cardDecoration,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    headingTextStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                    dataRowColor: WidgetStateProperty.resolveWith((states) {
                      return AppTheme.cardBgColor;
                    }),
                    columns: const [
                      DataColumn(label: Text("📅 Month")),
                      DataColumn(label: Text("🚫 Absent")),
                      DataColumn(label: Text("⏱ Overtime")),
                      DataColumn(label: Text("🎁 Bonus")),
                      DataColumn(label: Text("💵 Paid")),
                      DataColumn(label: Text("🧾 Remaining")),
                      DataColumn(label: Text("🔖 Type")),
                      DataColumn(label: Text("📆 Date")),
                    ],
                    rows: filtered.map((r) {
                      final date = DateFormat('y/MM/dd – HH:mm')
                          .format(DateTime.parse(r['timestamp']));
                      final color = r['type'] == 'Advance'
                          ? Colors.red.withOpacity(0.08)
                          : Colors.green.withOpacity(0.08);
                      return DataRow(
                        color: WidgetStateProperty.all(color),
                        cells: [
                          DataCell(Text(r['month'] ?? '')),
                          DataCell(Text(r['absentDays'].toString())),
                          DataCell(Text(r['overtimeHours'].toString())),
                          DataCell(Text(r['bonus'].toString())),
                          DataCell(Text(r['amountPaid'].toString())),
                          DataCell(Text(r['remainingBalance'].toString())),
                          DataCell(Text(r['type'].toString())),
                          DataCell(Text(date)),
                        ],
                      );
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

  Future<void> _exportToExcel() async {
    final excelFile = Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    final headers = [
      "Month",
      "Absent",
      "Overtime",
      "Bonus",
      "Paid",
      "Remaining",
      "Note",
      "Type",
      "Date"
    ];

    sheet.appendRow(headers);

    for (final r in allRecords) {
      final date = DateFormat('y/MM/dd – HH:mm').format(
          DateTime.tryParse(r['timestamp'].toString()) ?? DateTime(2000));
      sheet.appendRow([
        r['month'] ?? '',
        r['absentDays'] ?? '',
        r['overtimeHours'] ?? '',
        r['bonus'] ?? '',
        r['amountPaid'] ?? '',
        r['remainingBalance'] ?? '',
        r['note'] ?? '',
        r['type'] ?? '',
        date,
      ]);
    }

    final path = SettingsService.get('exportPath', '');
    if (path.isEmpty) {
      AppTheme.showErrorSnackbar(context, "❌ Set export path in Settings.");
      return;
    }

    final file = File('$path/${widget.worker['name']}_History.xlsx');
    file.writeAsBytesSync(excelFile.encode()!);
    await OpenFile.open(file.path);
    AppTheme.showSuccessSnackbar(context, "✅ Exported Successfully");
  }
}
