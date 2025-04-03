import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String versionUrl =
      'https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/version.json';
  static const String currentVersion = '1.0.0'; // ← Change when updating

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(versionUrl));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestVersion = json['version'];
        final downloadUrl = json['downloadUrl'];

        if (_isNewerVersion(latestVersion, currentVersion)) {
          if (!context.mounted) return;
          _showUpdateDialog(context, latestVersion, downloadUrl);
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ You have the latest version.")),
          );
        }
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Version file not found.")),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
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
        title: const Text("🆕 Update Available"),
        content: Text("A new version ($version) is available."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("❌ Could not open update link.")),
                );
              }
            },
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }
}
