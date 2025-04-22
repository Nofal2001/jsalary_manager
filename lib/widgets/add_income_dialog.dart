import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class AddIncomeDialog extends StatefulWidget {
  final bool embed;
  const AddIncomeDialog({super.key, this.embed = false});

  @override
  State<AddIncomeDialog> createState() => _AddIncomeDialogState();
}

class _AddIncomeDialogState extends State<AddIncomeDialog> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String? selectedClient;
  List<String> clientNames = [];

  String? _statusText;
  Color _statusColor = Colors.green;

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
            width: 500,
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("📥 Add Income",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Record a new income entry 👇",
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 24),
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
                  keyboardType: TextInputType.number,
                  decoration: _input("Amount"),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: _input("Select Date"),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        const Icon(Icons.calendar_today, size: 18)
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: _input("Notes (optional)"),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                if (_statusText != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _statusColor.withAlpha(30),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!widget.embed)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (selectedClient == null ||
                            amountController.text.isEmpty) {
                          setState(() {
                            _statusText = "⚠ Please fill all required fields.";
                            _statusColor = Colors.orange;
                          });
                          return;
                        }

                        final income = {
                          'id': const Uuid().v4(),
                          'amount':
                              double.tryParse(amountController.text) ?? 0.0,
                          'month': DateFormat('MMMM').format(selectedDate),
                          'notes': notesController.text.trim(),
                          'timestamp': selectedDate.toIso8601String(),
                          'name': selectedClient,
                        };

                        try {
                          await LocalDBService.addIncome(income);
                          if (!context.mounted) return;
                          if (!widget.embed) Navigator.pop(context);
                          AppTheme.showSuccessSnackbar(
                              context, "✅ Income saved!");
                        } catch (e) {
                          setState(() {
                            _statusText = "❌ Failed to save: $e";
                            _statusColor = Colors.red;
                          });
                        }
                      },
                      icon: const Text("💰", style: TextStyle(fontSize: 18)),
                      label: const Text("Save Income"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
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
