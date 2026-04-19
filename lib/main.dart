import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/map_screen.dart';
import 'services/upload_service.dart';
import 'screens/dialogs/show_upload_settings_dialog.dart';
import 'screens/dialogs/show_update_required_dialog.dart';
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
    final token = await uploadService.getContributorToken();
    final url = await uploadService.getApiUrl();

    if (!mounted) return;

    if (token.isEmpty) {
      // No token — must set one before the map loads.
      await showUploadSettingsDialog(context, uploadService, required: true);
    } else {
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
            );
            return; // Do not navigate to map — user must update.
          }

          // Show admin message if unseen.
          if (result.message != null) {
            await maybeShowAdminMessage(context, result.message!);
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
