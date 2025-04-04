import 'package:flutter/material.dart';
import 'package:jsalary_manager/services/local_db_service.dart';
import 'package:jsalary_manager/widgets/employee_history_dialog.dart';
import 'package:jsalary_manager/widgets/payments_history_tab.dart';
import 'package:jsalary_manager/widgets/full_history_tab.dart';
import 'package:jsalary_manager/theme/theme.dart';

class HistoryMainWindow extends StatefulWidget {
  const HistoryMainWindow({super.key});

  @override
  State<HistoryMainWindow> createState() => _HistoryMainWindowState();
}

class _HistoryMainWindowState extends State<HistoryMainWindow>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> workers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadWorkers();
  }

  Future<void> loadWorkers() async {
    final result = await LocalDBService.getAllWorkers();
    if (!mounted) return;
    setState(() => workers = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text('📋 History & Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🧍 Employees'),
            Tab(text: '💳 Payments History'),
            Tab(text: '📊 Full History'),
          ],
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEmployeeListTab(),
          const PaymentsHistoryTab(),
          const FullHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildEmployeeListTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: workers.isEmpty
          ? const Center(child: Text("No workers found."))
          : ListView.builder(
              itemCount: workers.length,
              itemBuilder: (context, index) {
                final worker = workers[index];
                final avatarColor =
                    Colors.primaries[index % Colors.primaries.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: AppTheme.cardDecoration,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: avatarColor.shade200,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      worker['name'],
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Text(
                      "${worker['role']} • Salary: \$${worker['salary']}",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEmojiActionButton(
                          emoji: "👁️",
                          tooltip: "View History",
                          color: Colors.deepPurple,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EmployeeHistoryDialog(worker: worker),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildEmojiActionButton(
                          emoji: "✏️",
                          tooltip: "Edit Worker",
                          color: Colors.teal,
                          onPressed: () => _editWorker(worker),
                        ),
                        const SizedBox(width: 6),
                        _buildEmojiActionButton(
                          emoji: "🗑️",
                          tooltip: "Delete Worker",
                          color: Colors.redAccent,
                          onPressed: () => _confirmDelete(worker),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmojiActionButton({
    required String emoji,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("🗑️ Confirm Delete"),
        content: Text(
          "Are you sure you want to permanently delete ${worker['name']}?",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(" Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text("Delete"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await LocalDBService.deleteWorker(worker['id']);
              if (!mounted) return;
              Navigator.pop(context);
              await loadWorkers();
              AppTheme.showSuccessSnackbar(context, "✅ Worker deleted");
            },
          ),
        ],
      ),
    );
  }

  void _editWorker(Map<String, dynamic> worker) {
    final nameController = TextEditingController(text: worker['name']);
    final salaryController =
        TextEditingController(text: worker['salary'].toString());
    String role = worker['role'];

    AppTheme.showAppDialog(
      context: context,
      title: "✏️ Edit Worker",
      content: Column(
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Worker Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: salaryController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monthly Salary'),
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
          child: const Text(" Cancel"),
        ),
        ElevatedButton.icon(
          icon: const Text("", style: TextStyle(fontSize: 18)),
          label: const Text("Save Changes"),
          onPressed: () async {
            await LocalDBService.updateWorker({
              'id': worker['id'],
              'name': nameController.text.trim(),
              'salary': double.tryParse(salaryController.text.trim()) ?? 0,
              'role': role,
            });
            Navigator.pop(context);
            await loadWorkers();
            AppTheme.showSuccessSnackbar(context, "✏️ Worker updated.");
          },
        ),
      ],
    );
  }
}
