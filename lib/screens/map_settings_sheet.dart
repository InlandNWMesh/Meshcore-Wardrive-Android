import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_version.dart';
import '../state/map_state_notifier.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import 'debug_diagnostics_screen.dart';
import '../main.dart';

void showMapSettingsSheet(
  BuildContext context,
  MapStateNotifier notifier,
  SettingsService settingsService,
  LocationService locationService, {
  required void Function(String) showSnackBar,
  required Future<void> Function() onExportData,
  required Future<void> Function() onImportData,
  required Future<void> Function() onConfigureUploadUrl,
  required Future<void> Function() onLoadSamples,
  required void Function() onScanForRepeaters,
  required void Function() onRefreshContacts,
  required bool sonarPingEnabled,
  required int sonarPingInterval,
  required void Function(bool) onSonarEnabledChanged,
  required void Function(int) onSonarIntervalChanged,
  required Future<void> Function(int?) onMaxEdgeResponsesChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      'v$appVersion',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Show Coverage Boxes'),
                  value: notifier.state.displaySettings.showCoverage,
                  onChanged: (value) async {
                    notifier.setShowCoverage(value);
                    await settingsService.setShowCoverage(value);
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Samples'),
                  value: notifier.state.displaySettings.showSamples,
                  onChanged: (value) async {
                    notifier.setShowSamples(value);
                    await settingsService.setShowSamples(value);
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Edges'),
                  value: notifier.state.displaySettings.showEdges,
                  onChanged: (value) async {
                    notifier.setShowEdges(value);
                    await settingsService.setShowEdges(value);
                    Navigator.pop(context);
                  },
                ),
                if (notifier.state.displaySettings.showEdges)
                  ListTile(
                    title: const Text('Edge Line Limit'),
                    subtitle: Text(
                      notifier.state.displaySettings.maxEdgeResponses == null
                          ? 'Show all lines'
                          : 'Most recent ${notifier.state.displaySettings.maxEdgeResponses} lines',
                    ),
                    trailing: const Icon(Icons.tune),
                    onTap: () {
                      Navigator.pop(context);
                      _setMaxEdgeResponses(
                        context,
                        notifier.state.displaySettings.maxEdgeResponses,
                        onMaxEdgeResponsesChanged,
                        showSnackBar,
                      );
                    },
                  ),
                SwitchListTile(
                  title: const Text('Show Repeaters'),
                  value: notifier.state.displaySettings.showRepeaters,
                  onChanged: (value) async {
                    notifier.setShowRepeaters(value);
                    await settingsService.setShowRepeaters(value);
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show GPS Samples'),
                  subtitle: const Text('Show blue GPS-only markers'),
                  value: notifier.state.displaySettings.showGpsSamples,
                  onChanged: (value) async {
                    notifier.setShowGpsSamples(value);
                    await settingsService.setShowGpsSamples(value);
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show Successful Pings Only'),
                  subtitle: const Text('Hide failed pings and GPS-only samples'),
                  value: notifier.state.displaySettings.showSuccessfulOnly,
                  onChanged: (value) async {
                    notifier.setShowSuccessfulOnly(value);
                    Navigator.pop(context);
                    showSnackBar(value ? 'Showing successful only' : 'Showing all samples');
                  },
                ),
                SwitchListTile(
                  title: const Text('Lock Rotation to North'),
                  subtitle: const Text('Prevent map rotation'),
                  value: notifier.state.lockRotationNorth,
                  onChanged: (value) async {
                    notifier.setLockRotation(value);
                    await settingsService.setLockRotationNorth(value);
                    Navigator.pop(context);
                    showSnackBar(value ? 'Rotation locked' : 'Rotation unlocked');
                  },
                ),
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeModeText(context)),
                  trailing: const Icon(Icons.brightness_6),
                  onTap: () {
                    Navigator.pop(context);
                    _showThemeSelector(context);
                  },
                ),
                if (notifier.state.loraConnected)
                  ListTile(
                    title: const Text('Scan for Repeaters'),
                    subtitle: Text(notifier.state.repeaters.isEmpty
                        ? 'Find nearby LoRa nodes'
                        : '${notifier.state.repeaters.length} repeater(s) found'),
                    leading: const Icon(Icons.cell_tower),
                    trailing: const Icon(Icons.search),
                    onTap: () {
                      Navigator.pop(context);
                      onScanForRepeaters();
                    },
                  ),
                if (notifier.state.loraConnected)
                  ListTile(
                    title: const Text('Refresh Contact List'),
                    subtitle: const Text('Update repeater names from device'),
                    leading: const Icon(Icons.refresh),
                    onTap: () {
                      Navigator.pop(context);
                      onRefreshContacts();
                    },
                  ),
                ListTile(
                  title: const Text('Color Mode'),
                  trailing: DropdownButton<String>(
                    value: notifier.state.displaySettings.colorMode,
                    items: const [
                      DropdownMenuItem(value: 'quality', child: Text('Quality')),
                      DropdownMenuItem(value: 'age', child: Text('Age')),
                    ],
                    onChanged: (value) async {
                      notifier.setColorMode(value!);
                      await settingsService.setColorMode(value);
                      Navigator.pop(context);
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Ignore Mobile Repeater'),
                  subtitle: Text(notifier.state.displaySettings.ignoredRepeaterPrefix != null
                      ? 'Filtering: ${notifier.state.displaySettings.ignoredRepeaterPrefix}*'
                      : 'Not filtering'),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    Navigator.pop(context);
                    _setIgnoredRepeater(context, notifier, settingsService, locationService, showSnackBar);
                  },
                ),
                ListTile(
                  title: const Text('Include Only Repeaters'),
                  subtitle: Text(
                    notifier.state.displaySettings.includeOnlyRepeaters != null &&
                            notifier.state.displaySettings.includeOnlyRepeaters!.isNotEmpty
                        ? 'Whitelist: ${notifier.state.displaySettings.includeOnlyRepeaters}'
                        : 'Show all repeaters',
                  ),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    Navigator.pop(context);
                    _setIncludeOnlyRepeaters(context, notifier, settingsService, showSnackBar);
                  },
                ),
                ListTile(
                  title: const Text('Ping Interval'),
                  subtitle: Text(_getPingIntervalDescription(notifier.state.displaySettings.pingIntervalMeters)),
                  trailing: const Icon(Icons.tune),
                  onTap: () {
                    Navigator.pop(context);
                    _setPingInterval(context, notifier, settingsService, locationService, showSnackBar);
                  },
                ),
                ListTile(
                  title: const Text('Coverage Resolution'),
                  subtitle: Text(_getCoverageResolutionDescription(notifier.state.displaySettings.coveragePrecision)),
                  trailing: const Icon(Icons.grid_on),
                  onTap: () {
                    Navigator.pop(context);
                    _setCoverageResolution(context, notifier, settingsService, onLoadSamples, showSnackBar);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Sonar Ping',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Audio Ping While Recording'),
                  subtitle: const Text('Plays a sonar sound to confirm tracking is active'),
                  value: sonarPingEnabled,
                  onChanged: (value) {
                    onSonarEnabledChanged(value);
                    Navigator.pop(context);
                  },
                ),
                if (sonarPingEnabled)
                  ListTile(
                    title: const Text('Ping Interval'),
                    subtitle: Text('Every $sonarPingInterval seconds'),
                    trailing: const Icon(Icons.tune),
                    onTap: () {
                      Navigator.pop(context);
                      _setSonarInterval(context, sonarPingInterval, onSonarIntervalChanged, showSnackBar);
                    },
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Data',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                ListTile(
                  title: const Text('Export'),
                  subtitle: const Text('Save or share samples as JSON'),
                  leading: const Icon(Icons.upload),
                  onTap: () {
                    Navigator.pop(context);
                    onExportData();
                  },
                ),
                ListTile(
                  title: const Text('Import'),
                  subtitle: const Text('Load samples from a JSON file'),
                  leading: const Icon(Icons.download),
                  onTap: () {
                    Navigator.pop(context);
                    onImportData();
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Debug',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                ListTile(
                  title: const Text('Debug Diagnostics'),
                  subtitle: const Text('View debug logs for troubleshooting'),
                  leading: const Icon(Icons.bug_report),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.pop(context);
                    _openDebugDiagnostics(context, locationService);
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Online Map',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                ListTile(
                  title: const Text('Configure API'),
                  subtitle: const Text('Set upload URL'),
                  leading: const Icon(Icons.settings),
                  onTap: () {
                    Navigator.pop(context);
                    onConfigureUploadUrl();
                  },
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'About',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                ListTile(
                  title: const Text('Check for Updates'),
                  subtitle: const Text('Current version: v$appVersion'),
                  leading: const Icon(Icons.system_update),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.pop(context);
                    _checkForUpdates(context, showSnackBar);
                  },
                ),
                ListTile(
                  title: const Text('View on GitHub'),
                  subtitle: const Text('Source code and releases'),
                  leading: const Icon(Icons.code),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    Navigator.pop(context);
                    _openGitHub(context, showSnackBar);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _getPingIntervalDescription(double meters) {
  if (meters < 100) {
    return '${meters.toInt()} meters (frequent)';
  } else if (meters < 1000) {
    return '${meters.toInt()} meters';
  } else {
    final miles = (meters / 1609.34).toStringAsFixed(1);
    return '$miles miles (${meters.toInt()}m)';
  }
}

String _getCoverageResolutionDescription(int precision) {
  switch (precision) {
    case 4:
      return 'Regional (~20km squares)';
    case 5:
      return 'City-level (~5km squares)';
    case 6:
      return 'Neighborhood (~1.2km squares)';
    case 7:
      return 'Street-level (~153m squares)';
    case 8:
      return 'Building-level (~38m squares)';
    default:
      return 'Unknown';
  }
}

String _getThemeModeText(BuildContext context) {
  final appState = MyApp.of(context);
  if (appState == null) return 'System Default';
  switch (appState.themeMode) {
    case ThemeMode.light:
      return 'Light';
    case ThemeMode.dark:
      return 'Dark';
    case ThemeMode.system:
      return 'System Default';
  }
}

Future<void> _showThemeSelector(BuildContext context) async {
  final appState = MyApp.of(context);
  if (appState == null) return;

  final selected = await showDialog<ThemeMode>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Choose Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Light'),
            leading: const Icon(Icons.light_mode),
            onTap: () => Navigator.pop(context, ThemeMode.light),
          ),
          ListTile(
            title: const Text('Dark'),
            leading: const Icon(Icons.dark_mode),
            onTap: () => Navigator.pop(context, ThemeMode.dark),
          ),
          ListTile(
            title: const Text('System Default'),
            leading: const Icon(Icons.brightness_auto),
            onTap: () => Navigator.pop(context, ThemeMode.system),
          ),
        ],
      ),
    ),
  );

  if (selected != null) {
    await appState.setThemeMode(selected);
    // Theme change triggers rebuild via MyApp's ChangeNotifier — no setState needed.
  }
}

Future<void> _setIgnoredRepeater(
  BuildContext context,
  MapStateNotifier notifier,
  SettingsService settingsService,
  LocationService locationService,
  void Function(String) showSnackBar,
) async {
  final controller = TextEditingController(
      text: notifier.state.displaySettings.ignoredRepeaterPrefix ?? '');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ignore Mobile Repeater'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter out responses from your mobile repeater to avoid false coverage.\n\n'
            'Enter the first 2-3 characters of your repeater\'s public key:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Public Key Prefix',
              hintText: 'e.g., 7E, A4F, etc.',
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final prefix = controller.text.isEmpty ? null : controller.text;
    notifier.setIgnoredRepeaterPrefix(prefix);
    locationService.loraCompanion.setIgnoredRepeaterPrefix(
        notifier.state.displaySettings.ignoredRepeaterPrefix);
    await settingsService.setIgnoredRepeaterPrefix(prefix);
    showSnackBar('Repeater prefix updated');
  }
}

Future<void> _setIncludeOnlyRepeaters(
  BuildContext context,
  MapStateNotifier notifier,
  SettingsService settingsService,
  void Function(String) showSnackBar,
) async {
  final controller = TextEditingController(
      text: notifier.state.displaySettings.includeOnlyRepeaters ?? '');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Include Only Repeaters'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Show ONLY samples from specific repeaters (whitelist). Useful for testing your own infrastructure.\n\n'
            'Enter repeater prefixes separated by commas:',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Repeater Prefixes',
              hintText: 'e.g., 7E3A, A4F2, 8B',
              isDense: true,
            ),
            textCapitalization: TextCapitalization.characters,
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final prefixes = controller.text.isEmpty ? null : controller.text;
    notifier.setIncludeOnlyRepeaters(prefixes);
    await settingsService.setIncludeOnlyRepeaters(prefixes);
    showSnackBar('Repeater whitelist updated');
  }
}

Future<void> _setPingInterval(
  BuildContext context,
  MapStateNotifier notifier,
  SettingsService settingsService,
  LocationService locationService,
  void Function(String) showSnackBar,
) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ping Interval'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How often should pings be sent?'),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Frequent'),
            subtitle: const Text('Every 50 meters'),
            onTap: () => Navigator.pop(context, '50'),
          ),
          ListTile(
            title: const Text('Normal'),
            subtitle: const Text('Every 200 meters (~0.12 miles)'),
            onTap: () => Navigator.pop(context, '200'),
          ),
          ListTile(
            title: const Text('Sparse'),
            subtitle: const Text('Every 0.5 miles (805 meters)'),
            onTap: () => Navigator.pop(context, '805'),
          ),
          ListTile(
            title: const Text('Very Sparse'),
            subtitle: const Text('Every 1 mile (1609 meters)'),
            onTap: () => Navigator.pop(context, '1609'),
          ),
        ],
      ),
    ),
  );

  if (selected != null) {
    final interval = double.parse(selected);
    notifier.setPingIntervalMeters(interval);
    locationService.setPingInterval(notifier.state.displaySettings.pingIntervalMeters);
    await settingsService.setPingInterval(interval);
    showSnackBar('Ping interval: ${_getPingIntervalDescription(notifier.state.displaySettings.pingIntervalMeters)}');
  }
}

Future<void> _setCoverageResolution(
  BuildContext context,
  MapStateNotifier notifier,
  SettingsService settingsService,
  Future<void> Function() onLoadSamples,
  void Function(String) showSnackBar,
) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Coverage Resolution'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose the size of coverage squares:'),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Regional'),
            subtitle: const Text('~20km squares (precision 4)'),
            onTap: () => Navigator.pop(context, '4'),
          ),
          ListTile(
            title: const Text('City-level'),
            subtitle: const Text('~5km squares (precision 5)'),
            onTap: () => Navigator.pop(context, '5'),
          ),
          ListTile(
            title: const Text('Neighborhood'),
            subtitle: const Text('~1.2km squares (precision 6)'),
            onTap: () => Navigator.pop(context, '6'),
          ),
          ListTile(
            title: const Text('Street-level'),
            subtitle: const Text('~153m squares (precision 7, default)'),
            onTap: () => Navigator.pop(context, '7'),
          ),
          ListTile(
            title: const Text('Building-level'),
            subtitle: const Text('~38m squares (precision 8, detailed)'),
            onTap: () => Navigator.pop(context, '8'),
          ),
        ],
      ),
    ),
  );

  if (selected != null) {
    final precision = int.parse(selected);
    notifier.setCoveragePrecision(precision);
    await settingsService.setCoveragePrecision(precision);
    await onLoadSamples();
    showSnackBar('Coverage resolution: ${_getCoverageResolutionDescription(notifier.state.displaySettings.coveragePrecision)}');
  }
}

Future<void> _setMaxEdgeResponses(
  BuildContext context,
  int? current,
  Future<void> Function(int?) onChanged,
  void Function(String) showSnackBar,
) async {
  const options = [null, 10, 25, 50, 100];
  final labels = {
    null: 'Show all lines',
    10: 'Most recent 10',
    25: 'Most recent 25',
    50: 'Most recent 50',
    100: 'Most recent 100',
  };

  final selected = await showDialog<Object>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edge Line Limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Limit which lines are drawn to the most recent responses. '
            'Helps reduce clutter over long drives.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) => RadioListTile<Object>(
                title: Text(labels[opt]!),
                value: opt ?? 'unlimited',
                groupValue: current ?? 'unlimited',
                onChanged: (v) => Navigator.pop(context, v),
                dense: true,
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (selected != null) {
    final value = selected == 'unlimited' ? null : selected as int;
    await onChanged(value);
    showSnackBar(value == null ? 'Showing all edge lines' : 'Showing most recent $value lines');
  }
}

Future<void> _setSonarInterval(
  BuildContext context,
  int currentInterval,
  void Function(int) onChanged,
  void Function(String) showSnackBar,
) async {
  int selected = currentInterval;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Sonar Ping Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Every $selected seconds',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Slider(
              value: selected.toDouble(),
              min: 5,
              max: 60,
              divisions: 11, // 5,10,15,20,25,30,35,40,45,50,55,60
              label: '${selected}s',
              onChanged: (v) => setState(() => selected = v.round()),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5s', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text('60s', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (confirmed == true) {
    onChanged(selected);
    showSnackBar('Sonar ping every ${selected}s');
  }
}

void _openDebugDiagnostics(BuildContext context, LocationService locationService) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => DebugDiagnosticsScreen(locationService: locationService),
    ),
  );
}

Future<void> _checkForUpdates(BuildContext context, void Function(String) showSnackBar) async {
  try {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/george-viaud/Meshcore-Wardrive-Android/releases/latest'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tagName = data['tag_name'].toString();
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (latestVersion != appVersion) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
              'New version $latestVersion is available!\n\n'
              'Current version: $appVersion\n\n'
              'Would you like to download it?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openGitHub(context, showSnackBar);
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      } else {
        showSnackBar('You\'re on the latest version!');
      }
    } else {
      showSnackBar('Could not check for updates');
    }
  } catch (e) {
    showSnackBar('Error checking for updates: $e');
  }
}

Future<void> _openGitHub(BuildContext context, void Function(String) showSnackBar) async {
  final url = Uri.parse('https://github.com/george-viaud/Meshcore-Wardrive-Android/releases');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    showSnackBar('Could not open GitHub');
  }
}
