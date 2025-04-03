import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<String> roles = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      roles =
          prefs.getStringList('customRoles') ?? ['Worker', 'Manager', 'Owner'];
    });
  }

  Future<void> _saveRoles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customRoles', roles);
  }

  void _addRole(String newRole) {
    if (newRole.trim().isEmpty || roles.contains(newRole.trim())) return;
    setState(() {
      roles.add(newRole.trim());
    });
    _saveRoles();
    _controller.clear();
  }

  void _deleteRole(String role) {
    setState(() {
      roles.remove(role);
    });
    _saveRoles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("👥 Customize Roles")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Add New Role",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addRole(_controller.text),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: roles.length,
                itemBuilder: (_, index) => ListTile(
                  title: Text(roles[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteRole(roles[index]),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
