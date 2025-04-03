import 'package:flutter/material.dart';
import '../services/local_db_service.dart';

class EditWorkerDialog extends StatefulWidget {
  final Map<String, dynamic> worker;
  final VoidCallback onSaved;

  const EditWorkerDialog({
    super.key,
    required this.worker,
    required this.onSaved,
  });

  @override
  State<EditWorkerDialog> createState() => _EditWorkerDialogState();
}

class _EditWorkerDialogState extends State<EditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController salaryController;
  late TextEditingController netSalesController;
  late TextEditingController profitPercentController;
  String role = 'Worker';

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.worker['name']);
    salaryController =
        TextEditingController(text: widget.worker['salary'].toString());
    netSalesController = TextEditingController(
        text: (widget.worker['netSales'] ?? '').toString());
    profitPercentController = TextEditingController(
        text: (widget.worker['profitPercent'] ?? '').toString());
    role = widget.worker['role'];
  }

  Future<void> saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final updatedWorker = {
      'id': widget.worker['id'],
      'name': nameController.text.trim(),
      'salary': double.parse(salaryController.text.trim()),
      'role': role,
      'netSales': role != 'Worker'
          ? double.tryParse(netSalesController.text) ?? 0
          : null,
      'profitPercent': role != 'Worker'
          ? double.tryParse(profitPercentController.text) ?? 0
          : null,
      'createdAt': widget.worker['createdAt'],
    };

    final db = await LocalDBService.database;
    await db.update(
      'workers',
      updatedWorker,
      where: 'id = ?',
      whereArgs: [widget.worker['id']],
    );

    if (!context.mounted) return;
    Navigator.pop(context);
    widget.onSaved(); // refresh main screen
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("✏️ Edit Worker",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Worker Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: salaryController,
                  decoration:
                      const InputDecoration(labelText: 'Monthly Salary'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || double.tryParse(value) == null
                          ? 'Invalid number'
                          : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: ['Worker', 'Manager', 'Owner']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => role = value!);
                  },
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                Visibility(
                  visible: role != 'Worker',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: netSalesController,
                        decoration:
                            const InputDecoration(labelText: 'Net Sales'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: profitPercentController,
                        decoration:
                            const InputDecoration(labelText: 'Profit %'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text("❌ Cancel"),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: saveChanges,
                      icon: const Text("💾", style: TextStyle(fontSize: 18)),
                      label: const Text("Save Changes"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A017),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
