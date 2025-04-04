import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jsalary_manager/services/local_db_service.dart';
import '../theme/theme.dart';

class FullHistoryTab extends StatefulWidget {
  const FullHistoryTab({super.key});

  @override
  State<FullHistoryTab> createState() => _FullHistoryTabState();
}

class _FullHistoryTabState extends State<FullHistoryTab> {
  List<Map<String, dynamic>> allRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];

  String? _sortBy;
  bool _ascending = true;
  String _searchText = '';
  String _filterType = 'All';
  String _filterMonth = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllRecords();
  }

  Future<void> _loadAllRecords() async {
    final db = await LocalDBService.database;
    final salary = await db.query('salary_records');
    final advances = await db.query('advance_payments');

    final List<Map<String, dynamic>> combined = [];
    combined.addAll(salary.map((e) => {...e, 'type': 'Salary'}));
    combined.addAll(advances.map((e) => {...e, 'type': 'Advance'}));

    combined.sort((a, b) =>
        b['timestamp'].toString().compareTo(a['timestamp'].toString()));

    if (mounted) {
      setState(() {
        allRecords = combined;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    filteredRecords = allRecords.where((record) {
      final name = record['workerName']?.toString().toLowerCase() ?? '';
      final matchesSearch = name.contains(_searchText.toLowerCase());

      final matchesType = _filterType == 'All' || record['type'] == _filterType;
      final matchesMonth =
          _filterMonth == 'All' || record['month'] == _filterMonth;

      return matchesSearch && matchesType && matchesMonth;
    }).toList();
  }

  void _sortRecords(String column) {
    setState(() {
      _ascending = (_sortBy == column) ? !_ascending : true;
      _sortBy = column;
      filteredRecords.sort((a, b) => _ascending
          ? a[column].toString().compareTo(b[column].toString())
          : b[column].toString().compareTo(a[column].toString()));
    });
  }

  double get totalPaid => filteredRecords
      .where((e) => e['type'] == 'Salary')
      .fold(0.0, (sum, e) => sum + (e['amountPaid'] as num? ?? 0).toDouble());

  double get totalAdvance => filteredRecords
      .where((e) => e['type'] == 'Advance')
      .fold(0.0, (sum, e) => sum + (e['amount'] as num? ?? 0).toDouble());

  Future<void> _editCell(
      Map<String, dynamic> row, String key, dynamic newValue) async {
    final confirm = await AppTheme.showAppDialog<bool>(
      context: context,
      title: "✏️ Confirm Edit",
      content: Text("Are you sure you want to change $key to $newValue?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm")),
      ],
    );

    if (confirm != true) return;

    final db = await LocalDBService.database;
    if (row['type'] == 'Salary') {
      await db.update('salary_records', {key: newValue},
          where: 'id = ?', whereArgs: [row['id']]);
    } else {
      await db.update('advance_payments', {key: newValue},
          where: 'id = ?', whereArgs: [row['id']]);
    }

    await _loadAllRecords();
  }

  Future<void> _deleteRow(Map<String, dynamic> row) async {
    final confirm = await AppTheme.showAppDialog<bool>(
      context: context,
      title: "🗑️ Confirm Delete",
      content: const Text("Are you sure you want to delete this record?"),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete")),
      ],
    );

    if (confirm != true) return;

    final db = await LocalDBService.database;
    if (row['type'] == 'Salary') {
      await db
          .delete('salary_records', where: 'id = ?', whereArgs: [row['id']]);
    } else {
      await db
          .delete('advance_payments', where: 'id = ?', whereArgs: [row['id']]);
    }

    await _loadAllRecords();
    AppTheme.showSuccessSnackbar(context, "✅ Record deleted");
  }

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['History'];
    sheet.appendRow([
      "Type",
      "Worker",
      "Month",
      "Amount Paid",
      "Bonus",
      "Remaining",
      "Advance",
      "Date"
    ]);

    for (var row in filteredRecords) {
      sheet.appendRow([
        row['type'],
        row['workerName'] ?? '',
        row['month'] ?? '-',
        row['amountPaid'] ?? '',
        row['bonus'] ?? '',
        row['remainingBalance'] ?? '',
        row['amount'] ?? '',
        row['timestamp'] ?? ''
      ]);
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/history_export.xlsx";
    final fileBytes = excel.encode();
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(fileBytes as List<int>);

    if (mounted) {
      AppTheme.showSuccessSnackbar(context, "📁 Exported to: $path");
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'All',
      ...allRecords
          .map((r) => r['month'])
          .where((m) => m != null && m.toString().trim().isNotEmpty)
          .toSet()
          .map((m) => m.toString())
    ];

    if (!months.contains(_filterMonth)) {
      _filterMonth = 'All';
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top Summary + Export
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("💸 Total Paid: \$${totalPaid.toStringAsFixed(2)}"),
              Text("⏩ Total Advance: \$${totalAdvance.toStringAsFixed(2)}"),
              ElevatedButton.icon(
                onPressed: _exportToExcel,
                icon: const Icon(Icons.download),
                label: const Text("Export"),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "Search name...",
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchText = val;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterType,
                onChanged: (val) {
                  setState(() {
                    _filterType = val!;
                    _applyFilters();
                  });
                },
                items: ['All', 'Salary', 'Advance']
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _filterMonth,
                onChanged: (val) {
                  setState(() {
                    _filterMonth = val!;
                    _applyFilters();
                  });
                },
                items: months
                    .map((m) =>
                        DropdownMenuItem<String>(value: m, child: Text(m)))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Data Table
          Expanded(
            child: Container(
              decoration: AppTheme.cardDecoration,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        AppTheme.primaryColor.withOpacity(0.1)),
                    dataRowColor: WidgetStateProperty.all(AppTheme.cardBgColor),
                    headingTextStyle: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(fontWeight: FontWeight.bold),
                    columns: [
                      DataColumn(
                          label: const Text("Type"),
                          onSort: (_, __) => _sortRecords('type')),
                      DataColumn(
                          label: const Text("Name"),
                          onSort: (_, __) => _sortRecords('workerName')),
                      DataColumn(
                          label: const Text("Month"),
                          onSort: (_, __) => _sortRecords('month')),
                      DataColumn(
                          label: const Text("Paid"),
                          onSort: (_, __) => _sortRecords('amountPaid')),
                      DataColumn(
                          label: const Text("Bonus"),
                          onSort: (_, __) => _sortRecords('bonus')),
                      DataColumn(
                          label: const Text("Remaining"),
                          onSort: (_, __) => _sortRecords('remainingBalance')),
                      DataColumn(
                          label: const Text("Advance"),
                          onSort: (_, __) => _sortRecords('amount')),
                      DataColumn(
                          label: const Text("Date"),
                          onSort: (_, __) => _sortRecords('timestamp')),
                      const DataColumn(label: Text("🗑️")),
                    ],
                    rows: filteredRecords.map((row) {
                      final isAdvance = row['type'] == 'Advance';
                      final bgColor = isAdvance
                          ? AppTheme.warningColor.withOpacity(0.05)
                          : AppTheme.successColor.withOpacity(0.05);

                      return DataRow(
                        color: WidgetStateProperty.all(bgColor),
                        cells: [
                          DataCell(Text(row['type'] ?? '')),
                          DataCell(Text(row['workerName'] ?? '-')),
                          DataCell(Text(row['month'] ?? '-')),
                          DataCell(GestureDetector(
                            onTap: () async {
                              final newValue = await _showEditDialog(
                                  row['amountPaid']?.toString() ?? '');
                              if (newValue != null) {
                                _editCell(row, 'amountPaid',
                                    double.tryParse(newValue) ?? 0);
                              }
                            },
                            child: Text("${row['amountPaid'] ?? ''}"),
                          )),
                          DataCell(Text("${row['bonus'] ?? ''}")),
                          DataCell(Text("${row['remainingBalance'] ?? ''}")),
                          DataCell(Text("${row['amount'] ?? ''}")),
                          DataCell(Text(row['timestamp'] ?? '-')),
                          DataCell(IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: "Delete",
                            onPressed: () => _deleteRow(row),
                          )),
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

  Future<String?> _showEditDialog(String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("✏️ Edit Value"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "New Value"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
