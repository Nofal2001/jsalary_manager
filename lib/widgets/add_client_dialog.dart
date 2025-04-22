import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';

class AddClientDialog extends StatefulWidget {
  final bool embed;
  const AddClientDialog({super.key, this.embed = false});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String? _statusText;
  Color _statusColor = Colors.green;

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
                Text("👤 Add New Client",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Fill in the client details below 👇",
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 28),
                TextField(
                  controller: nameController,
                  decoration: _input('Client Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: _input('Phone Number (optional)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: _input('Notes (optional)'),
                  maxLines: 3,
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
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final notes = notesController.text.trim();

                          if (name.isEmpty) {
                            setState(() {
                              _statusText = "⚠ Please enter a client name.";
                              _statusColor = Colors.orange;
                            });
                            return;
                          }

                          final client = {
                            'id': const Uuid().v4(),
                            'name': name,
                            'phone': phone,
                            'notes': notes,
                            'createdAt': DateTime.now().toIso8601String(),
                          };

                          try {
                            await LocalDBService.addClient(client);
                            if (!context.mounted) return;
                            if (!widget.embed) Navigator.pop(context);
                            AppTheme.showSuccessSnackbar(
                                context, "✅ Client added successfully!");
                          } catch (e) {
                            setState(() {
                              _statusText = "❌ Failed to save: $e";
                              _statusColor = Colors.red;
                            });
                          }
                        },
                        icon: const Text("➕", style: TextStyle(fontSize: 18)),
                        label: const Text("Add Client"),
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
