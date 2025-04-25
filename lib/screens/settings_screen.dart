import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:jsalary_manager/screens/roles_screen.dart';
import 'package:jsalary_manager/services/settings_service.dart';
import 'package:jsalary_manager/services/local_db_service.dart';
import '../theme/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String exportPath = '';
  bool autoBackup = false;
  bool darkMode = false;
  bool dbLogging = false;
  bool autoExportOnUpdate = true;
  String fontSize = 'Medium';
  String? adminPin;
  String appVersion = 'Loading...';
  bool _isCheckingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final pin = await SettingsService.getAdminPin();
    final info = await PackageInfo.fromPlatform();

    setState(() {
      exportPath = SettingsService.get('exportPath', '');
      autoBackup = SettingsService.get('autoBackup', false);
      fontSize = SettingsService.get('fontSize', 'Medium');
      darkMode = SettingsService.get('darkMode', false);
      dbLogging = SettingsService.get('dbLogging', false);
      autoExportOnUpdate = SettingsService.get('autoExportOnUpdate', true);
      adminPin = pin;
      appVersion = info.version;
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
    setState(() => _isCheckingForUpdates = true);
    const versionUrl =
        'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json';

    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final remote = jsonDecode(response.body);
        final latestVersion = remote['version'];
        final downloadUrl = remote['downloadUrl'];
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

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
                    child: const Text("Download")),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ You have the latest version.")));
        }
      } else {
        throw Exception("Failed to fetch version info.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("❌ Update check failed: ${e.toString()}"),
        action: SnackBarAction(label: "Retry", onPressed: _checkForUpdates),
      ));
    } finally {
      setState(() => _isCheckingForUpdates = false);
    }
  }

  Future<void> _showFinancialSummary() async {
    final summary = await LocalDBService.getFinancialSummary();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Financial Overview"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryItem("Total Income", summary['totalIncome']),
            _summaryItem("Total Expenses", summary['totalExpense']),
            _summaryItem("Total Salaries", summary['totalSalary']),
            _summaryItem("Total Advances", summary['totalAdvance']),
            const Divider(),
            _summaryItem("Net Balance", summary['netBalance'], isTotal: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _summaryItem(String label, dynamic value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            "\$${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? (value >= 0 ? Colors.green : Colors.red) : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  // Everything remains the same above your build method...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      appBar: AppBar(title: const Text("⚙ App Settings")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _section("📂 DATA & STORAGE"),
          _settingRow(
            label: "Export Folder",
            child: Row(
              children: [
                Expanded(
                    child: Text(exportPath.isNotEmpty ? exportPath : "Not Set",
                        overflow: TextOverflow.ellipsis)),
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
          _section("🔒 SECURITY"),
          _settingRow(
            label: "Admin PIN",
            child: ElevatedButton(
                onPressed: _changePinDialog, child: const Text("Set PIN")),
          ),
          _settingRow(
            label: "Enable DB Logging",
            child: Switch(
              value: dbLogging,
              onChanged: (val) {
                _updateSetting('dbLogging', val);
                LocalDBService.enableLogging(val);
              },
            ),
          ),
          const Divider(height: 36),
          _section("📝 GENERAL DISPLAY"),
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
          _settingRow(
            label: "Dark Mode",
            child: Switch(
                value: darkMode,
                onChanged: (val) => _updateSetting('darkMode', val)),
          ),
          const Divider(height: 36),
          _section("🌐 INTERNET & UPDATES"),
          ElevatedButton.icon(
            icon: const Icon(Icons.update),
            label: const Text("Check for Updates"),
            onPressed: _isCheckingForUpdates ? null : _checkForUpdates,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 12),
          Text("📌 App Version: $appVersion",
              style:
                  const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
          _settingRow(
            label: "Auto-export Before Update",
            child: Switch(
                value: autoExportOnUpdate,
                onChanged: (val) => _updateSetting('autoExportOnUpdate', val)),
          ),
          const Divider(height: 36),
          _section("📦 ADVANCED"),

          /// First row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _advancedBtn(Icons.file_upload, "Export DB", () async {
                final path = await LocalDBService.exportDatabaseToJson();
                _showSnack("📤 Exported to: $path");
              }),
              _advancedBtn(Icons.file_download, "Import DB", () async {
                final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom, allowedExtensions: ['json']);
                if (result != null) {
                  final success = await LocalDBService.importDatabaseFromJson(
                      result.files.single.path!);
                  _showSnack(success
                      ? "✅ Imported successfully."
                      : "❌ Import failed.");
                }
              }),
              _advancedBtn(Icons.backup, "Backup DB", () async {
                final path = await LocalDBService.backupDatabase();
                _showSnack("✅ Backup to: $path");
              }),
            ],
          ),
          const SizedBox(height: 12),

          /// Second row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _advancedBtn(Icons.health_and_safety, "Check DB", () async {
                final results =
                    await LocalDBService.validateDatabaseIntegrity();
                final allGood = results.values.every((v) => v == true);
                _showSnack(allGood
                    ? "✅ Database integrity check passed."
                    : "⚠️ Issues found in database.");
              }),
              _advancedBtn(Icons.history, "Version Log", () async {
                final history = await LocalDBService.getVersionHistory();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Database Version History"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return ListTile(
                            title: Text(
                                "v${item['oldVersion']} → v${item['newVersion']}"),
                            subtitle: Text("Updated: ${item['updateDate']}"),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close"))
                    ],
                  ),
                );
              }),
              _advancedBtn(
                  Icons.analytics, "Financial 📊", _showFinancialSummary),
            ],
          ),
          const SizedBox(height: 12),

          /// Final row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.warning_amber),
                  label: const Text("Reset All"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(48)),
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
                      await LocalDBService.clearAllData();
                      _showSnack("✅ Data reset complete.");
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.settings_suggest),
                  label: const Text("Customize Roles"),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RolesScreen())),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper section title
  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      );

  /// Helper for key-value settings rows
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

  /// Reusable button layout
  Widget _advancedBtn(IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 18),
          label: Text(label, overflow: TextOverflow.ellipsis),
          onPressed: onPressed,
          style:
              ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
    );
  }

  /// Helper to show snack
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
