import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<Map<String, dynamic>> roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('customRolesJson');

    if (saved != null) {
      roles = List<Map<String, dynamic>>.from(json.decode(saved));
    } else {
      roles = [
        {'role': 'Employee', 'getsPercent': false},
        {'role': 'Manager', 'getsPercent': true},
        {'role': 'Owner', 'getsPercent': true},
      ];
      await _saveRoles();
    }

    setState(() {});
  }

  Future<void> _saveRoles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customRolesJson', json.encode(roles));
  }

  void _deleteRole(String role) {
    if (role == 'Owner') {
      AppTheme.showWarningSnackbar(
        context,
        "⚠️ You can't delete the Owner role.",
      );
      return;
    }

    setState(() {
      roles.removeWhere((r) => r['role'] == role);
    });
    _saveRoles();
  }

  void _showAddRoleDialog() {
    final TextEditingController controller = TextEditingController();
    bool getsPercent = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.bgColor,
          title: const Text("➕ Add New Role"),
          content: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: "Role Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text("Gets %"),
                    const SizedBox(width: 12),
                    Checkbox(
                      value: getsPercent,
                      onChanged: (val) => setState(() => getsPercent = val!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final role = controller.text.trim();
                if (role.isEmpty ||
                    roles.any(
                        (r) => r['role'].toLowerCase() == role.toLowerCase())) {
                  Navigator.pop(context);
                  return;
                }

                setState(() {
                  roles.add({'role': role, 'getsPercent': getsPercent});
                });
                _saveRoles();
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(
        title: const Text("👥 Customize Roles"),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "You can add or remove employee roles here.\nTick the box if the role gets a profit percentage.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddRoleDialog,
              icon: const Icon(Icons.add),
              label: const Text("Add Role"),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: roles.length,
                itemBuilder: (_, index) {
                  final role = roles[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge),
                      title: Text(role['role']),
                      subtitle: Text(
                        role['getsPercent']
                            ? "✔ Gets profit percentage"
                            : "❌ No profit percentage",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRole(role['role']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
