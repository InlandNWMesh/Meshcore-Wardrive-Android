import 'package:flutter/material.dart';

/// Shows a non-dismissible dialog when the installed app version is below
/// the server's declared minimum. The user cannot proceed to the map.
Future<void> showUpdateRequiredDialog(
  BuildContext context, {
  required String currentVersion,
  required String minVersion,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update_alt, color: Colors.red, size: 26),
          SizedBox(width: 10),
          Text('Update Required'),
        ],
      ),
      content: Text(
        'This version of the app ($currentVersion) is no longer supported.\n\n'
        'Please update to version $minVersion or later to continue.',
        style: const TextStyle(height: 1.5),
      ),
    ),
  );
}
