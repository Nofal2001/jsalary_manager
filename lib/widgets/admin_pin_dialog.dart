import 'package:flutter/material.dart';
import 'package:jsalary_manager/services/settings_service.dart';

class AdminPinDialog {
  static Future<bool> verifyPin(BuildContext context) async {
    final savedPin = await SettingsService.getAdminPin();
    if (savedPin == null || savedPin.isEmpty) return true; // No PIN set

    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🔒 Admin PIN Required"),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter PIN'),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            child: const Text("Confirm"),
            onPressed: () => Navigator.pop(ctx, controller.text == savedPin),
          ),
        ],
      ),
    );

    return result == true;
  }
}
