// Full updated code for lib/screens/history_main_window.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jsalary_manager/services/local_db_service.dart';
import 'package:jsalary_manager/theme/theme.dart';
import 'package:jsalary_manager/widgets/employee_history_dialog.dart';
import 'package:jsalary_manager/widgets/clients_history_dialog.dart';
import 'package:jsalary_manager/services/settings_service.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class HistoryMainWindow extends StatefulWidget {
  const HistoryMainWindow({super.key});

  @override
  State<HistoryMainWindow> createState() => _HistoryMainWindowState();
}

class _HistoryMainWindowState extends State<HistoryMainWindow>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> workers = [];
  List<Map<String, dynamic>> clients = [];
  List<Map<String, dynamic>> incomes = [];
  List<Map<String, dynamic>> expenses = [];

  // Filters
  String incomeSearch = '';
  String expenseSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadData();
  }

  Future<void> loadData() async {
    final allWorkers = await LocalDBService.getAllWorkers();
    final allClients = await LocalDBService.getAllClients();
    final allIncomes = await LocalDBService.getAllIncomes();
    final allExpenses = await LocalDBService.getVaultPayments();

    if (!mounted) return;
    setState(() {
      workers = allWorkers;
      clients = allClients;
      incomes = allIncomes;
      expenses = allExpenses.where((e) => e['type'] != 'income').toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('📋 History & Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🧍 Employees'),
            Tab(text: '👥 Clients'),
            Tab(text: '💸 Expenses'),
            Tab(text: '💰 Incomes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntityList("Employees", workers, _editWorker, _confirmDelete,
              (item) => EmployeeHistoryDialog(worker: item)),
          _buildEntityList(
              "Clients",
              clients,
              _editClient,
              _confirmDeleteClient,
              (item) => ClientsHistoryDialog(client: item)),
          _buildTransactionTable("Expenses", expenses, "Expenses_History.xlsx",
              expenseSearch, (val) => setState(() => expenseSearch = val)),
          _buildTransactionTable("Incomes", incomes, "Incomes_History.xlsx",
              incomeSearch, (val) => setState(() => incomeSearch = val)),
        ],
      ),
    );
  }

  Widget _buildEntityList(
    String title,
    List<Map<String, dynamic>> data,
    Function(Map<String, dynamic>) onEdit,
    Function(Map<String, dynamic>) onDelete,
    Widget Function(Map<String, dynamic>) historyDialogBuilder,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: data.isEmpty
          ? Center(child: Text("No $title found."))
          : ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, i) {
                final item = data[i];
                final color = Colors.primaries[i % Colors.primaries.length];

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.shade300,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['phone'] ?? item['role'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionButton("👁️", "View", Colors.deepPurple, () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => historyDialogBuilder(item)));
                        }),
                        _actionButton(
                            "✏️", "Edit", Colors.teal, () => onEdit(item)),
                        _actionButton(
                            "🗑️", "Delete", Colors.red, () => onDelete(item)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTransactionTable(
    String title,
    List<Map<String, dynamic>> data,
    String fileName,
    String searchQuery,
    Function(String) onSearch,
  ) {
    final filtered = data.where((row) {
      final name = (row['name'] ?? '').toLowerCase();
      final note = (row['note'] ?? '').toLowerCase();
      final date = (row['timestamp'] ?? '').split('T').first;
      return name.contains(searchQuery.toLowerCase()) ||
          note.contains(searchQuery.toLowerCase()) ||
          date.contains(searchQuery);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    hintText: "🔍 Search by name, note or date (YYYY-MM-DD)",
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text("Export"),
                onPressed: () => _exportToExcel(filtered, fileName),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black12)
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(Colors.amber.shade50),
                  dataRowColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.grey.shade100
                          : Colors.grey.shade50),
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text("👤 Name")),
                    DataColumn(label: Text("💰 Amount")),
                    DataColumn(label: Text("📄 Note")),
                    DataColumn(label: Text("💳 Type")),
                    DataColumn(label: Text("📅 Date")),
                  ],
                  rows: filtered
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(Text(row['name'] ?? '—')),
                            DataCell(Text("${row['amount'] ?? '—'} ")),
                            DataCell(Text(row['note'] ?? '—')),
                            DataCell(Text(
                                row['type']?.toString().toUpperCase() ?? '—')),
                            DataCell(Text(DateFormat('d MMMM yyyy')
                                .format(DateTime.parse(row['timestamp'])))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(
      List<Map<String, dynamic>> data, String fileName) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    if (data.isNotEmpty) {
      final keys = data.first.keys.toList();
      sheet.appendRow(keys);
      for (final row in data) {
        final rowData = keys.map((k) {
          final value = row[k];
          if (k == 'timestamp' && value != null) {
            return DateFormat('d MMMM yyyy').format(DateTime.parse(value));
          }
          return value?.toString() ?? '';
        }).toList();
        sheet.appendRow(rowData);
      }
    }

    final exportPath = SettingsService.get('exportPath', '');
    if (exportPath.isEmpty) {
      AppTheme.showErrorSnackbar(context, "❌ Set export folder in Settings.");
      return;
    }

    final file = File('$exportPath/$fileName');
    file.writeAsBytesSync(excel.encode()!);
    await OpenFile.open(file.path);
    AppTheme.showSuccessSnackbar(context, "✅ File exported successfully.");
  }

  Widget _actionButton(
      String emoji, String tooltip, Color color, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> worker) async {
    final confirmed = await AppTheme.showConfirmDialog(
      context: context,
      title: "🗑️ Confirm Delete",
      message: "Are you sure you want to delete this worker?",
    );
    if (confirmed) {
      await LocalDBService.deleteWorker(worker['id']);
      await loadData();
      AppTheme.showSuccessSnackbar(context, "✅ Worker deleted.");
    }
  }

  void _confirmDeleteClient(Map<String, dynamic> client) async {
    final confirmed = await AppTheme.showConfirmDialog(
      context: context,
      title: "🗑️ Confirm Delete",
      message: "Are you sure you want to delete this client?",
    );
    if (confirmed) {
      // 🔥 Delete the client from the database
      final db = await LocalDBService.database;
      await db.delete('clients', where: 'id = ?', whereArgs: [client['id']]);

      // 🔄 Reload the data to refresh the UI
      await loadData();

      // ✅ Show feedback
      AppTheme.showSuccessSnackbar(context, "✅ Client deleted.");
    }
  }

  void _editWorker(Map<String, dynamic> worker) {
    final nameCtrl = TextEditingController(text: worker['name']);
    final salaryCtrl = TextEditingController(text: worker['salary'].toString());
    String role = worker['role'];

    AppTheme.showAppDialog(
      context: context,
      title: "✏️ Edit Worker",
      content: Column(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: salaryCtrl,
            decoration: const InputDecoration(labelText: 'Salary'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: role,
            items: ['Worker', 'Manager', 'Owner']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) => role = val!,
            decoration: const InputDecoration(labelText: 'Role'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text("Save"),
          onPressed: () async {
            final oldName = worker['name'];
            final newName = nameCtrl.text.trim();

            await LocalDBService.updateWorker({
              'id': worker['id'],
              'name': newName,
              'salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
              'role': role,
            });

            // ✅ Also update name in vault/income/expenses
            await LocalDBService.updateNameReferences(oldName, newName);

            Navigator.pop(context);
            await loadData();
            AppTheme.showSuccessSnackbar(context, "✏️ Worker updated.");
          },
        ),
      ],
    );
  }

  void _editClient(Map<String, dynamic> client) {
    final nameCtrl = TextEditingController(text: client['name']);
    final phoneCtrl = TextEditingController(text: client['phone']);
    final notesCtrl = TextEditingController(text: client['notes']);

    AppTheme.showAppDialog(
      context: context,
      title: "✏️ Edit Client",
      content: Column(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text("Save"),
          onPressed: () async {
            final oldName = client['name'];
            final newName = nameCtrl.text.trim();

            await LocalDBService.addClient({
              'id': client['id'],
              'name': newName,
              'phone': phoneCtrl.text.trim(),
              'notes': notesCtrl.text.trim(),
              'timestamp': client['timestamp'],
              'createdAt': client['createdAt'],
            });

            // ✅ Update name everywhere
            await LocalDBService.updateNameReferences(oldName, newName);

            Navigator.pop(context);
            await loadData();
            AppTheme.showSuccessSnackbar(context, "✏️ Client updated.");
          },
        ),
      ],
    );
  }
}
