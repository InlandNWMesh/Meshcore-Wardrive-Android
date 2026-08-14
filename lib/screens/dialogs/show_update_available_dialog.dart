import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/update_url.dart';
import '../../utils/version_utils.dart';

/// How long to wait before nagging again about the same version.
///
/// A prompt on every launch trains people to dismiss it without reading, which
/// is precisely the habit we cannot afford when an update actually matters. Once
/// a day is visible without becoming wallpaper. A NEW recommended version resets
/// this immediately — a fresh release is worth interrupting for, a repeat of
/// yesterday's is not.
const Duration updateNagInterval = Duration(hours: 24);

const _lastNagVersionKey = 'update_nag_version';
const _lastNagAtKey = 'update_nag_at';

/// Nag — never block — when a newer build is recommended.
///
/// Deliberately separate from `showUpdateRequiredDialog`: that one is a gate and
/// stops the user reaching the map, which also stops them collecting. Blocking
/// costs real coverage data, so it is reserved for data-corrupting or security
/// problems. Everything else belongs here, where the user can say "later" and
/// still go drive.
///
/// Returns true if the dialog was shown.
Future<bool> maybeShowUpdateAvailable(
  BuildContext context, {
  required String currentVersion,
  required String? recommendedVersion,
  String? updateUrl,
  String? updateNotes,
}) async {
  if (recommendedVersion == null || recommendedVersion.isEmpty) return false;
  // isVersionBelow fails open on a malformed string, so a bad server value
  // means no nag rather than a permanent one.
  if (!isVersionBelow(currentVersion, recommendedVersion)) return false;

  final prefs = await SharedPreferences.getInstance();
  final lastVersion = prefs.getString(_lastNagVersionKey);
  final lastAt = DateTime.tryParse(prefs.getString(_lastNagAtKey) ?? '');

  final sameVersionAsLastNag = lastVersion == recommendedVersion;
  final naggedRecently = lastAt != null &&
      DateTime.now().difference(lastAt) < updateNagInterval;
  if (sameVersionAsLastNag && naggedRecently) return false;

  if (!context.mounted) return false;

  final url = resolveUpdateUrl(updateUrl);

  await showDialog<void>(
    context: context,
    // Dismissible on purpose. This is a suggestion, and a contributor about to
    // head out should never be stuck behind it.
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update_alt, size: 24),
          SizedBox(width: 10),
          Flexible(child: Text('Update Available')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have $currentVersion. Version $recommendedVersion is available.',
            style: const TextStyle(height: 1.5),
          ),
          if (updateNotes != null && updateNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(updateNotes, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 12),
          const Text(
            'You can keep using this version for now.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Get Update'),
          onPressed: () async {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );

  // Recorded after showing, not after a choice: dismissing by tapping outside
  // still counts, or the same prompt reappears on the next launch.
  await prefs.setString(_lastNagVersionKey, recommendedVersion);
  await prefs.setString(_lastNagAtKey, DateTime.now().toIso8601String());
  return true;
}
