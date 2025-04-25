import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';
import 'package:intl/intl.dart';

class AdvancePaymentDialog extends StatefulWidget {
  final bool embed;
  const AdvancePaymentDialog({super.key, this.embed = false});

  @override
  State<AdvancePaymentDialog> createState() => _AdvancePaymentDialogState();
}

class _AdvancePaymentDialogState extends State<AdvancePaymentDialog> {
  String? selectedMonth;

  final TextEditingController amountController = TextEditingController();
  List<Map<String, dynamic>> workers = [];
  String? selectedWorkerName;

  String? _statusText;
  Color _statusColor = Colors.green;

  @override
  void initState() {
    super.initState();
    loadWorkers();

    selectedMonth = null;
  }

  Future<void> loadWorkers() async {
    final result = await LocalDBService.getAllWorkers();
    if (!mounted) return;
    setState(() => workers = result);
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.bgColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

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
                Text("💸 Advance Payment",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Enter the advance payment details 👇",
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 28),

                // Worker Dropdown
                DropdownButtonFormField<String>(
                  value: selectedWorkerName,
                  decoration: _input('Worker Name'),
                  icon: const Icon(Icons.arrow_drop_down),
                  items: workers.map((w) {
                    return DropdownMenuItem<String>(
                      value: w['name'],
                      child: Text(w['name']),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedWorkerName = val),
                ),
                const SizedBox(height: 16),

                // Styled Date Picker Like TextField
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2030),
                      helpText: 'Select Payment Date',
                    );

                    if (picked != null) {
                      setState(() {
                        selectedMonth =
                            DateFormat('d MMMM yyyy').format(picked);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: _input("Select Date"),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedMonth ?? 'dd/MM/yyyy',
                          style: TextStyle(
                            color: selectedMonth == null
                                ? Colors.grey
                                : Colors.black87,
                            fontSize: 14.5,
                          ),
                        ),
                        const Icon(Icons.calendar_today,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Amount
                TextField(
                    controller: amountController,
                    decoration: _input('Advance Amount'),
                    keyboardType: TextInputType.number,
                    style: Theme.of(context).textTheme.bodyMedium),

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
                        const Text("ℹ️", style: TextStyle(fontSize: 18)),
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
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (selectedWorkerName == null ||
                              amountController.text.isEmpty ||
                              selectedMonth == null) {
                            setState(() {
                              _statusText = "⚠ Please complete all fields.";
                              _statusColor = Colors.orange;
                            });
                            return;
                          }

                          final record = {
                            'id': const Uuid().v4(),
                            'workerName': selectedWorkerName!,
                            'month': selectedMonth!,
                            'amount':
                                double.tryParse(amountController.text) ?? 0,
                            'timestamp': DateFormat('d MMMM yyyy')
                                .parse(selectedMonth!)
                                .toIso8601String()
                          };

                          try {
                            await LocalDBService.addAdvancePayment(record);

                            // ✅ Play cha-ching sound
                            final player = AudioPlayer();
                            await player
                                .play(AssetSource('sounds/money-counter.mp3'));

                            // ✅ Clear fields (except selectedWorkerName)
                            amountController.clear();
                            setState(() {
                              selectedMonth = null;
                              _statusText = null;
                            });

                            if (!context.mounted) return;
                            if (!widget.embed) Navigator.pop(context);

                            AppTheme.showSuccessSnackbar(
                                context, "✅ Payment saved!");
                          } catch (e) {
                            setState(() {
                              _statusText = "❌ Failed to save: $e";
                              _statusColor = Colors.red;
                            });
                          }
                        },
                        icon: const Text("➕", style: TextStyle(fontSize: 18)),
                        label: const Text("Pay in advance"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
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
