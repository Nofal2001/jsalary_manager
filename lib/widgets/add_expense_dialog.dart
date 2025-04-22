import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class AddExpenseDialog extends StatefulWidget {
  final bool embed;
  const AddExpenseDialog({super.key, this.embed = false});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String? selectedClient;
  String? _statusText;
  Color _statusColor = Colors.green;
  List<String> clientNames = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await LocalDBService.getAllClients();
    setState(() {
      clientNames = clients.map((e) => e['name'].toString()).toList();
    });
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.bgColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBF9F6), Color(0xFFF4EFE7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 520,
            margin: const EdgeInsets.symmetric(vertical: 40),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("📤 Add Expense",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Enter the expense details 👇",
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 28),
                DropdownButtonFormField<String>(
                  value: selectedClient,
                  decoration: _input("Select Client"),
                  items: clientNames
                      .map((name) =>
                          DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedClient = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: _input('Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: _input("Select Date"),
                      controller: TextEditingController(
                          text: DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: _input('Notes (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                if (_statusText != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(20),
                      border: Border.all(color: _statusColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text("💡", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_statusText!,
                              style: TextStyle(color: _statusColor)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.embed)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0 || selectedClient == null) {
                          setState(() {
                            _statusText =
                                "⚠ Please enter amount and select client.";
                            _statusColor = Colors.orange;
                          });
                          return;
                        }

                        final record = {
                          'id': const Uuid().v4(),
                          'amount': amount,
                          'notes': notesController.text.trim(),
                          'timestamp': selectedDate.toIso8601String(),
                          'name': selectedClient!,
                        };

                        try {
                          await LocalDBService.addExpense(record);
                          if (!context.mounted) return;
                          if (!widget.embed) Navigator.pop(context);
                          AppTheme.showSuccessSnackbar(
                              context, "✅ Expense recorded!");
                        } catch (e) {
                          setState(() {
                            _statusText = "❌ Failed to save: $e";
                            _statusColor = Colors.red;
                          });
                        }
                      },
                      icon: const Text("➖", style: TextStyle(fontSize: 18)),
                      label: const Text("Save Expense"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    return widget.embed
        ? content
        : Dialog(insetPadding: const EdgeInsets.all(40), child: content);
  }
}
