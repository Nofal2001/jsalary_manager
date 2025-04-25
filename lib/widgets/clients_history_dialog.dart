import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:jsalary_manager/services/settings_service.dart';

class ClientsHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> client;
  const ClientsHistoryDialog({super.key, required this.client});

  @override
  State<ClientsHistoryDialog> createState() => _ClientsHistoryDialogState();
}

class _ClientsHistoryDialogState extends State<ClientsHistoryDialog> {
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
      'vault',
      where: 'name = ?',
      whereArgs: [widget.client['name']],
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

  Future<void> _exportToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    sheet.appendRow(["Note", "Amount", "Type", "Date"]);

    for (final r in records) {
      final date =
          DateFormat('d MMMM yyyy').format(DateTime.parse(r['timestamp']));
      sheet.appendRow(
          [r['note'] ?? '', r['amount'].toString(), r['type'] ?? '', date]);
    }

    final exportPath = SettingsService.get('exportPath', '');
    if (exportPath.isEmpty) {
      AppTheme.showErrorSnackbar(context, "❌ Set export folder in Settings.");
      return;
    }

    final file =
        File('$exportPath/${widget.client['name']}_ClientHistory.xlsx');
    file.writeAsBytesSync(excel.encode()!);
    await OpenFile.open(file.path);
    AppTheme.showSuccessSnackbar(context, "✅ Exported successfully.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("📖 View Client History"),
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.client['name'],
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text('Phone: ${widget.client['phone']}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: const Icon(Icons.download),
                    label: const Text("Export"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 900), // Adjust as needed
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.primaryColor.withOpacity(0.1),
                      ),
                      headingTextStyle: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(fontWeight: FontWeight.bold),
                      dataRowColor:
                          WidgetStateProperty.all(AppTheme.cardBgColor),
                      columns: const [
                        DataColumn(label: Center(child: Text("📝 Note"))),
                        DataColumn(label: Center(child: Text("💰 Amount"))),
                        DataColumn(label: Center(child: Text("🔖 Type"))),
                        DataColumn(label: Center(child: Text("📅 Date"))),
                      ],
                      rows: records.map((r) {
                        final date = DateFormat('d MMMM yyyy')
                            .format(DateTime.parse(r['timestamp']));
                        return DataRow(cells: [
                          DataCell(Center(child: Text(r['note'] ?? '-'))),
                          DataCell(Center(child: Text("${r['amount']}"))),
                          DataCell(Center(child: Text(r['type'] ?? 'Unknown'))),
                          DataCell(Center(child: Text(date))),
                        ]);
                      }).toList(),
                    ),
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
