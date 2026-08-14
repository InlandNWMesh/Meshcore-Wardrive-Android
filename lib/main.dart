import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/map_screen.dart';
import 'services/app_config_service.dart';
import 'services/upload_service.dart';
import 'screens/dialogs/show_upload_settings_dialog.dart';
import 'screens/dialogs/show_update_required_dialog.dart';
import 'screens/dialogs/show_update_available_dialog.dart';
import 'screens/dialogs/show_admin_message_dialog.dart';
import 'utils/version_utils.dart';
import 'constants/app_version.dart';

void main() {
  // Lock to portrait mode (true north)
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString('theme_mode') ?? 'system';
    setState(() {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeString,
        orElse: () => ThemeMode.system,
      );
    });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshCore Wardrive',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: const StartupGate(),
    );
  }
}

/// Checks contributor token validity before showing the map.
///
/// Shows a loading indicator while validating, forces the token setup dialog
/// if the token is missing or rejected, then navigates to [MapScreen].
/// Network errors are treated as offline (map loads without blocking).
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  void initState() {
    super.initState();
    _checkAndProceed();
  }

  Future<void> _checkAndProceed() async {
    final uploadService = UploadService();

    // Load cached tunables now, and refresh in the background. Deliberately not
    // awaited: config must never sit between the user and a drive, and a phone
    // with no signal is the normal case out here, not an error. Whatever was
    // cached last time (or the shipped defaults) is already in force.
    final appConfig = AppConfigService();
    await appConfig.load();
    unawaited(uploadService.getApiUrl().then(appConfig.refresh));

    if (!mounted) return;

    // Ensure a token exists before doing anything else.
    if ((await uploadService.getContributorToken()).isEmpty) {
      await showUploadSettingsDialog(context, uploadService, required: true);
      if (!mounted) return;
    }

    // Always validate with whatever token is now set (covers first-run too).
    final token = await uploadService.getContributorToken();
    final url = await uploadService.getApiUrl();

    if (token.isNotEmpty) {
      final result = await uploadService.validateToken(url, token);
      if (!mounted) return;

      if (!result.isOffline) {
        if (!result.isValid) {
          // Server explicitly rejected the token — force re-entry.
          await showUploadSettingsDialog(context, uploadService, required: true);
          if (!mounted) return;
        } else {
          // Check minimum version (blocking — user cannot proceed if outdated).
          if (result.minVersion != null &&
              isVersionBelow(appVersion, result.minVersion!)) {
            await showUpdateRequiredDialog(
              context,
              currentVersion: appVersion,
              minVersion: result.minVersion!,
              updateUrl: result.updateUrl,
            );
            return; // Do not navigate to map — user must update.
          }

          // Non-blocking nag when a newer build is recommended. Only reached
          // when the hard block above did not fire, so the two never stack.
          await maybeShowUpdateAvailable(
            context,
            currentVersion: appVersion,
            recommendedVersion: result.recommendedVersion,
            updateUrl: result.updateUrl,
            updateNotes: result.updateNotes,
          );
          if (!mounted) return;

          // Show any unseen admin messages.
          if (result.messages.isNotEmpty) {
            await maybeShowAdminMessages(context, result.messages);
            if (!mounted) return;
          }
        }
      }
      // isOffline → proceed normally (skip all checks).
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
