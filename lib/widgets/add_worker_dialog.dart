import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/local_db_service.dart';
import '../theme/theme.dart';
import 'package:intl/intl.dart';

class AddWorkerDialog extends StatefulWidget {
  final bool embed;
  const AddWorkerDialog({super.key, this.embed = false});

  @override
  State<AddWorkerDialog> createState() => _AddWorkerDialogState();
}

class _AddWorkerDialogState extends State<AddWorkerDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController salaryController = TextEditingController();
  final TextEditingController profitPercentController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  String role = 'Worker';
  final List<String> roles = ['Worker', 'Manager', 'Owner'];

  Future<bool> isDuplicateName(String name) async {
    final allWorkers = await LocalDBService.getAllWorkers();
    final input = name.toLowerCase().trim();
    return allWorkers.any(
        (worker) => (worker['name'] as String).toLowerCase().trim() == input);
  }

  Future<void> saveWorker() async {
    if (joinDate == null) {
      AppTheme.showErrorSnackbar(context, "📅 Please select a join date.");
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final name = nameController.text.trim();
    final bool duplicate = await isDuplicateName(name);
    if (duplicate) {
      if (context.mounted) {
        AppTheme.showErrorSnackbar(
            context, "❌ This worker name already exists.");
      }
      return;
    }

    final double salary = double.parse(salaryController.text.trim());
    final String id = const Uuid().v4();

    final workerData = {
      'id': id,
      'name': name,
      'salary': salary,
      'role': role,
      'createdAt': joinDate!.toIso8601String(),
    };

    if (role == 'Manager' || role == 'Owner') {
      final double profitPercent =
          double.tryParse(profitPercentController.text.trim()) ?? 0;
      workerData['profitPercent'] = profitPercent;
    }

    try {
      await LocalDBService.addWorker(workerData);
      if (!context.mounted) return;
      if (!widget.embed) Navigator.of(context).pop();
      AppTheme.showSuccessSnackbar(context, "✅ Worker saved successfully!");
    } catch (e) {
      AppTheme.showErrorSnackbar(context, "❌ Failed to save worker: $e");
    }
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
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text("👷‍♂️ Add New Worker",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text("Fill the worker's details below 👇",
                      style: TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 28),

                  // Name
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Worker Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Salary
                  TextFormField(
                    controller: salaryController,
                    decoration:
                        const InputDecoration(labelText: 'Monthly Salary'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter salary';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Join Date'),
                          child: Text(
                            joinDate != null
                                ? DateFormat('d MMMM yyyy').format(joinDate!)
                                : 'Select date',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _pickJoinDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Role
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    icon: const Icon(Icons.arrow_drop_down),
                    items: roles
                        .map((r) =>
                            DropdownMenuItem<String>(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (val) => setState(() => role = val!),
                  ),
                  const SizedBox(height: 16),

                  // Profit %
                  if (role == 'Manager' || role == 'Owner')
                    TextFormField(
                      controller: profitPercentController,
                      decoration: const InputDecoration(
                          labelText: 'Profit % (optional)'),
                      keyboardType: TextInputType.number,
                    ),

                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!widget.embed)
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      const SizedBox(width: 12),
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
                          onPressed: saveWorker,
                          icon: const Text("➕", style: TextStyle(fontSize: 18)),
                          label: const Text("Add"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return widget.embed
        ? content
        : Dialog(insetPadding: const EdgeInsets.all(40), child: content);
  }

  DateTime? joinDate; // Default to today

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: joinDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => joinDate = picked);
    }
  }
}
