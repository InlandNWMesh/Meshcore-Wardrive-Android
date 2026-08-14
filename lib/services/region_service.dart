import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What we know about one repeater's regions.
///
/// [regions] is only meaningful when [answered] is true. An empty list from a
/// repeater that *did* answer is a real result — it means "no flood-enabled
/// regions" — and must not be confused with "we never got a reply".
class RegionInfo {
  final List<String> regions;
  final DateTime askedAt;
  final bool answered;

  const RegionInfo({
    required this.regions,
    required this.askedAt,
    required this.answered,
  });

  bool get hasRegions => answered && regions.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'regions': regions,
    'askedAt': askedAt.toIso8601String(),
    'answered': answered,
  };

  factory RegionInfo.fromJson(Map<String, dynamic> j) => RegionInfo(
    regions: (j['regions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    askedAt: DateTime.tryParse(j['askedAt'] as String? ?? '') ?? DateTime(1970),
    answered: j['answered'] == true,
  );
}

/// Caches per-repeater region lists and decides who is worth asking.
///
/// Regions are a property of the repeater, not of where you were standing when
/// you asked, so this is keyed by node id and deliberately kept out of the
/// geohash/coverage pipeline.
class RegionService {
  static const _enabledKey = 'region_discovery_enabled';
  static const _cacheKey = 'region_cache_v1';

  /// A repeater that answered is not asked again for this long. Its regions
  /// only change when somebody reconfigures it.
  static const answeredTtl = Duration(days: 7);

  /// A repeater that ignored us is retried after this long. Short enough to
  /// pick up a node that was simply out of range on the last drive, long
  /// enough not to spend the airtime budget on a node that never answers.
  static const unansweredTtl = Duration(hours: 6);

  /// Firmware allows 4 anon requests per 3 minutes (`anon_limiter(4, 180)`).
  /// Three attempts leaves one spare for the owner/clock request types, which
  /// share that same counter.
  static const maxAttempts = 3;

  final Map<String, RegionInfo> _cache = {};
  bool _loaded = false;

  // ── setting ────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Off by default: this is beta, and it spends airtime the user did not
    // ask for when they started a drive.
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  // ── cache ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((k, v) {
        if (v is Map) {
          _cache[k.toString()] = RegionInfo.fromJson(Map<String, dynamic>.from(v));
        }
      });
    } catch (_) {
      // A corrupt cache is not worth losing a drive over — start empty.
      _cache.clear();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(_cache.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// Regions for a repeater, or null if we have never had an answer from it.
  Future<RegionInfo?> get(String nodeId) async {
    await _load();
    return _cache[nodeId.toUpperCase()];
  }

  /// Synchronous read for map rendering. Only valid after [preload].
  RegionInfo? peek(String nodeId) => _cache[nodeId.toUpperCase()];

  Future<void> preload() => _load();

  /// True when this repeater is worth spending an anon request on.
  Future<bool> shouldAsk(String nodeId) async {
    await _load();
    final info = _cache[nodeId.toUpperCase()];
    if (info == null) return true;
    final age = DateTime.now().difference(info.askedAt);
    return age > (info.answered ? answeredTtl : unansweredTtl);
  }

  Future<void> record(String nodeId, List<String> regions, {required bool answered}) async {
    await _load();
    _cache[nodeId.toUpperCase()] = RegionInfo(
      regions: regions,
      askedAt: DateTime.now(),
      answered: answered,
    );
    await _save();
  }

  /// Node ids we have region lists for, for map colouring and export.
  Future<Map<String, List<String>>> allKnown() async {
    await _load();
    return {
      for (final e in _cache.entries)
        if (e.value.hasRegions) e.key: e.value.regions,
    };
  }
}
