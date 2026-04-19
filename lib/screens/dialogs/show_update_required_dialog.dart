import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _releasesUrl = 'https://github.com/george-viaud/Meshcore-Wardrive-Android/releases/latest';

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
        'Version $currentVersion is no longer supported.\n\n'
        'Please download the latest release to continue.',
        style: const TextStyle(height: 1.5),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Get Latest Release'),
          onPressed: () => launchUrl(
            Uri.parse(_releasesUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    ),
  );
}
