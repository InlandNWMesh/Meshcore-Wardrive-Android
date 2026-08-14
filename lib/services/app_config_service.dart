import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tunables for region discovery, resolved from the server when possible.
class RegionDiscoveryConfig {
  /// Signal floor for spending an anon request on a repeater.
  final int minRssi;
  final int minSnr;

  /// Attempts per repeater. One while moving — see
  /// `LocationService._maybeDiscoverRegions`.
  final int attempts;

  final int batchBudgetSeconds;
  final int perAttemptTimeoutSeconds;

  const RegionDiscoveryConfig({
    this.minRssi = -118,
    this.minSnr = -15,
    this.attempts = 1,
    this.batchBudgetSeconds = 25,
    this.perAttemptTimeoutSeconds = 8,
  });

  /// Parse a server section, keeping the shipped default for any field that is
  /// missing or out of range.
  ///
  /// Ranges are enforced here as well as on the server. The server is the only
  /// writer today, but a client that trusts whatever arrives would let one bad
  /// row stop collection on every phone at once — and that failure is invisible,
  /// because it looks exactly like a quiet mesh.
  factory RegionDiscoveryConfig.fromJson(Map<String, dynamic>? j) {
    const d = RegionDiscoveryConfig();
    if (j == null) return d;
    int pick(String key, int fallback, int lo, int hi) {
      final v = j[key];
      if (v is! num || !v.isFinite) return fallback;
      final i = v.toInt();
      return (i < lo || i > hi) ? fallback : i;
    }

    return RegionDiscoveryConfig(
      minRssi: pick('minRssi', d.minRssi, -140, -30),
      minSnr: pick('minSnr', d.minSnr, -25, 15),
      attempts: pick('attempts', d.attempts, 1, 4),
      batchBudgetSeconds: pick('batchBudgetSeconds', d.batchBudgetSeconds, 5, 120),
      perAttemptTimeoutSeconds:
          pick('perAttemptTimeoutSeconds', d.perAttemptTimeoutSeconds, 2, 30),
    );
  }

  Map<String, dynamic> toJson() => {
    'minRssi': minRssi,
    'minSnr': minSnr,
    'attempts': attempts,
    'batchBudgetSeconds': batchBudgetSeconds,
    'perAttemptTimeoutSeconds': perAttemptTimeoutSeconds,
  };
}

/// Client tunables served by the wardrive server, so thresholds can be retuned
/// from drive data without shipping a new APK.
///
/// Resolution order is deliberate: **last fetched value, else shipped default**,
/// and the network fetch only ever updates the cache. Wardriving happens in
/// places with no signal — that is the point of it — so config must never be on
/// the path to collecting. Nothing here blocks, and a failed refresh is normal
/// rather than an error.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._();
  factory AppConfigService() => _instance;
  AppConfigService._();

  static const _cacheKey = 'app_config_cache_v1';
  static const _fetchedAtKey = 'app_config_fetched_at';

  /// Refresh no more than this often; the app also refreshes on startup.
  static const refreshInterval = Duration(hours: 6);

  RegionDiscoveryConfig _regionDiscovery = const RegionDiscoveryConfig();
  bool _loaded = false;

  /// Current values. Safe to read before [load] — it returns shipped defaults.
  RegionDiscoveryConfig get regionDiscovery => _regionDiscovery;

  /// Read the cached config off disk. Cheap; call before the first drive.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _regionDiscovery = RegionDiscoveryConfig.fromJson(
        (decoded['regionDiscovery'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (_) {
      // Corrupt cache — shipped defaults are already in place.
    }
  }

  /// Fetch from the server and cache the result.
  ///
  /// [baseUrl] is the upload API base (e.g. `https://host/api/samples/`); the
  /// config endpoint is derived from its origin so a self-hoster pointing at
  /// their own server gets their own config, not ours.
  ///
  /// Returns true when values were refreshed. Never throws.
  Future<bool> refresh(String baseUrl, {bool force = false}) async {
    await load();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force) {
        final last = DateTime.tryParse(prefs.getString(_fetchedAtKey) ?? '');
        if (last != null &&
            DateTime.now().difference(last) < refreshInterval) {
          return false;
        }
      }

      final uri = Uri.tryParse(baseUrl);
      if (uri == null || !uri.hasScheme) return false;
      final endpoint = uri.replace(path: '/api/app-config', query: '');

      final resp = await http
          .get(endpoint)
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return false;

      _regionDiscovery = RegionDiscoveryConfig.fromJson(
        (decoded['regionDiscovery'] as Map?)?.cast<String, dynamic>(),
      );
      await prefs.setString(
        _cacheKey,
        jsonEncode({'regionDiscovery': _regionDiscovery.toJson()}),
      );
      await prefs.setString(_fetchedAtKey, DateTime.now().toIso8601String());
      return true;
    } catch (_) {
      // Offline, DNS down, server restarting — all expected. Keep what we have.
      return false;
    }
  }
}
