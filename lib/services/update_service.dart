import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String versionUrl =
      'https://raw.githubusercontent.com/Nofal2001/salary_app/main/version.json';
  static const String currentVersion = '1.0.0';

  static Future<void> checkForUpdates(BuildContext context,
      {bool showNoUpdateMessage = true}) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestVersion = json['version'];
        final downloadUrl = json['downloadUrl'];

        if (_isNewerVersion(latestVersion, currentVersion)) {
          _showUpdateDialog(context, latestVersion, downloadUrl);
        } else if (showNoUpdateMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ You're using the latest version.")),
          );
        }
      } else {
        throw Exception('Failed to load version info.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Update check failed: $e")),
      );
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
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
        title: const Text("🆕 New Update Available"),
        content: Text(
            "Version $version is available. Would you like to download it?"),
        actions: [
          TextButton(
            child: const Text("Later"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text("Download"),
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}
