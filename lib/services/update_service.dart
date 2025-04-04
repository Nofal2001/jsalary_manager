import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String versionUrl =
      'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json';

  static Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateMessage = false}) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestVersion = json['version'].toString().trim();
        final downloadUrl = json['downloadUrl'];

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        // ✅ ADD THESE TWO LINES BELOW
        print('🔍 Current Version: $currentVersion');
        print('🆕 Latest Version from JSON: $latestVersion');
        // 🧪 Show debug info
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("🔍 Version Debug"),
            content: Text(
              "Current Version: $currentVersion\nLatest from JSON: $latestVersion",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );

        if (_isNewerVersion(latestVersion, currentVersion)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog(context, latestVersion, downloadUrl);
          });
        } else if (showNoUpdateMessage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ You have the latest version.")),
            );
          });
        }
      } else {
        throw Exception('Version file not found.');
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Update check failed: $e")),
        );
      });
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    print('🔍 Comparing Versions:');
    print('Current: "$current"');
    print('Latest : "$latest"');

    final latestParts = latest.trim().split('.').map(int.parse).toList();
    final currentParts = current.trim().split('.').map(int.parse).toList();

    while (latestParts.length < 3) latestParts.add(0);
    while (currentParts.length < 3) currentParts.add(0);

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String url) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🆕 Update Available"),
        content: Text("A new version ($version) is available."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Later")),
          ElevatedButton(
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }
}
