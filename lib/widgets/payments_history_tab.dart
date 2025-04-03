import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class PaymentsHistoryTab extends StatefulWidget {
  const PaymentsHistoryTab({super.key});

  @override
  State<PaymentsHistoryTab> createState() => _PaymentsHistoryTabState();
}

class _PaymentsHistoryTabState extends State<PaymentsHistoryTab> {
  List<Map<String, dynamic>> allPayments = [];
  List<Map<String, dynamic>> filteredPayments = [];

  String selectedMonth = 'All';
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final db = await LocalDBService.database;

    final salaries = await db.query('salary_records');
    final advances = await db.query('advance_payments');

    final List<Map<String, dynamic>> payments = [
      ...salaries.map((s) => {
            'name': s['workerName'],
            'amount': s['amountPaid'],
            'type': 'Salary',
            'month': s['month'] ?? '',
            'timestamp': s['timestamp'],
          }),
      ...advances.map((a) => {
            'name': a['workerName'],
            'amount': a['amount'],
            'type': 'Advance',
            'month': '',
            'timestamp': a['timestamp'],
          }),
    ];

    payments.sort((a, b) {
      final aDate = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final bDate = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    setState(() {
      allPayments = payments;
      _applyFilters();
    });
  }

  void _applyFilters() {
    filteredPayments = allPayments.where((p) {
      final matchesSearch = p['name']
              ?.toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()) ??
          false;
      final matchesMonth =
          selectedMonth == 'All' || p['month'] == selectedMonth;
      return matchesSearch && matchesMonth;
    }).toList();
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Payments'];

    sheet.appendRow([
      "Name",
      "Amount",
      "Type",
      "Month",
      "Date",
    ]);

    for (final p in filteredPayments) {
      sheet.appendRow([
        p['name'],
        p['amount'],
        p['type'],
        p['month'],
        p['timestamp'],
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/payments_history.xlsx";
    final fileBytes = excel.encode();
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(fileBytes as List<int>);

    if (mounted) {
      AppTheme.showSuccessSnackbar(context, "📤 Exported to: $path");
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableMonths = {
      ...allPayments
          .map((p) => p['month'] ?? '')
          .where((m) => m.toString().isNotEmpty)
    }.toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Title Row + Filter + Export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📋 Payments History',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  DropdownButton<String>(
                    value: selectedMonth,
                    onChanged: (val) {
                      setState(() {
                        selectedMonth = val!;
                        _applyFilters();
                      });
                    },
                    items: [
                      const DropdownMenuItem(
                        value: 'All',
                        child: Text("📆 All Months"),
                      ),
                      ...availableMonths.map((month) => DropdownMenuItem(
                            value: month.toString(),
                            child: Text("📅 $month"),
                          )),
                    ],
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _exportToExcel,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("📤"),
                  ),
                ],
              )
            ],
          ),

          const SizedBox(height: 12),

          // Search bar
          TextField(
            decoration: const InputDecoration(
              hintText: "🔍 Search by name...",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (value) {
              setState(() {
                searchText = value;
                _applyFilters();
              });
            },
          ),

          const SizedBox(height: 16),

          // Table
          // Replace the Expanded(...) widget with this:
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(
                        AppTheme.primaryColor.withOpacity(0.08)),
                    headingTextStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                    dataRowColor: WidgetStatePropertyAll(
                        AppTheme.cardBgColor.withOpacity(0.95)),
                    columns: const [
                      DataColumn(label: Text('👤 Name')),
                      DataColumn(label: Text('💰 Amount')),
                      DataColumn(label: Text('💳 Type')),
                      DataColumn(label: Text('📅 Date')),
                    ],
                    rows: filteredPayments.map((p) {
                      final dateFormatted =
                          DateFormat('y/MM/dd – HH:mm').format(
                        DateTime.tryParse(p['timestamp'] ?? '') ??
                            DateTime.now(),
                      );

                      return DataRow(
                        color: WidgetStateProperty.all(
                          p['type'] == 'Advance'
                              ? AppTheme.warningColor.withOpacity(0.05)
                              : AppTheme.successColor.withOpacity(0.05),
                        ),
                        cells: [
                          DataCell(Text(p['name'].toString())),
                          DataCell(Text("\$${p['amount']}")),
                          DataCell(Text(p['type'])),
                          DataCell(Text(dateFormatted)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
