import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:salary_app/screens/roles_screen.dart';
import 'package:salary_app/services/settings_service.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String exportPath = '';
  bool autoBackup = false;
  String fontSize = 'Medium';
  String? adminPin;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final pin = await SettingsService.getAdminPin();
    setState(() {
      exportPath = SettingsService.get('exportPath', '');
      autoBackup = SettingsService.get('autoBackup', false);
      fontSize = SettingsService.get('fontSize', 'Medium');
      adminPin = pin;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await SettingsService.set(key, value);
    _loadSettings();
  }

  Future<void> _chooseExportFolder() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      await SettingsService.set('exportPath', selectedDir);
      setState(() => exportPath = selectedDir);
    }
  }

  Future<void> _changePinDialog() async {
    final controller = TextEditingController();
    final newPin = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🔒 Set Admin PIN"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "New PIN"),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text("Save")),
        ],
      ),
    );

    if (newPin != null && newPin.trim().isNotEmpty) {
      await SettingsService.setAdminPin(newPin.trim());
      _loadSettings();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("✅ Admin PIN updated.")));
    }
  }

  Future<void> _checkForUpdates() async {
    const versionUrl =
        'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json';
    const currentVersion = '1.0.0'; // Update this with each release

    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final remote = jsonDecode(response.body);
        final latestVersion = remote['version'];
        final downloadUrl = remote['downloadUrl'];

        if (latestVersion != currentVersion) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("🆕 Update Available"),
              content: Text("A new version ($latestVersion) is available."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Later")),
                ElevatedButton(
                  onPressed: () => launchUrl(Uri.parse(downloadUrl)),
                  child: const Text("Download"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ You have the latest version.")),
          );
        }
      } else {
        throw Exception("Failed to load version info");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Update check failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text("⚙ App Settings")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text("📂 DATA & STORAGE",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          _settingRow(
            label: "Export Folder",
            child: Row(
              children: [
                Expanded(
                  child: Text(exportPath.isNotEmpty ? exportPath : "Not Set",
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                    onPressed: _chooseExportFolder,
                    child: const Text("Choose")),
              ],
            ),
          ),
          _settingRow(
            label: "Enable Auto Backup",
            child: Switch(
                value: autoBackup,
                onChanged: (val) => _updateSetting('autoBackup', val)),
          ),
          const Divider(height: 36),
          Text("🔒 SECURITY", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _settingRow(
            label: "Admin PIN",
            child: ElevatedButton(
                onPressed: _changePinDialog, child: const Text("Set PIN")),
          ),
          const Divider(height: 36),
          Text("📝 GENERAL DISPLAY",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _settingRow(
            label: "Font Size",
            child: DropdownButton<String>(
              value: fontSize,
              items: const [
                DropdownMenuItem(value: 'Small', child: Text('Small')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'Large', child: Text('Large')),
              ],
              onChanged: (val) {
                if (val != null) _updateSetting('fontSize', val);
              },
            ),
          ),
          const Divider(height: 36),
          Text("🌐 INTERNET & UPDATES",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.update),
            label: const Text("Check for Updates"),
            onPressed: _checkForUpdates,
          ),
          const Divider(height: 36),
          Text("📦 ADVANCED", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text("Export DB"),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("📤 Export logic coming soon.")),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download),
                label: const Text("Import DB"),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("📥 Import logic coming soon.")),
                  );
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.warning_amber),
                label: const Text("Reset All"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("🗑️ Confirm Reset"),
                      content: const Text(
                          "This will delete all data. Are you sure?"),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel")),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Yes, Reset")),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("✅ Data reset (not implemented yet).")),
                    );
                  }
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings_suggest),
                label: const Text("Customize Roles"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RolesScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settingRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 3,
              child: Text(label, style: const TextStyle(fontSize: 16))),
          Expanded(flex: 5, child: child),
        ],
      ),
    );
  }
}
