import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/upload_service.dart';

/// Shows an admin message dialog if the user has not already acknowledged
/// this message ID. Records the acknowledgment so it never shows again.
Future<void> maybeShowAdminMessage(
  BuildContext context,
  AdminMessage message,
) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'admin_msg_ack_${message.id}';
  if (prefs.getBool(key) == true) return;

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(message.title ?? 'Notice from Admin'),
      content: Text(message.body, style: const TextStyle(height: 1.5)),
      actions: [
        ElevatedButton(
          onPressed: () async {
            await prefs.setBool(key, true);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
