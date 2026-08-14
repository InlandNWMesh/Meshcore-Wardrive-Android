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

  /// Link quality at the moment the request went out, from the discovery reply
  /// that put this repeater in range.
  ///
  /// Recorded because the signal floor worth asking above is unknown: the only
  /// success so far was -45 dBm at a desk, which cannot distinguish "needs -45"
  /// from "needs -95". Pairing every ask with its signal turns one drive into an
  /// answer-rate-versus-signal curve, so the threshold can be measured instead
  /// of guessed. That matters more than it looks, because RSSI is what *we* hear
  /// from *them* — repeaters usually sit higher with better antennas, so a
  /// strong reading overstates our ability to reach them, by an amount that
  /// varies per site and cannot be reasoned out from link budget alone.
  final int? rssi;
  final int? snr;

  const RegionInfo({
    required this.regions,
    required this.askedAt,
    required this.answered,
    this.rssi,
    this.snr,
  });

  bool get hasRegions => answered && regions.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'regions': regions,
    'askedAt': askedAt.toIso8601String(),
    'answered': answered,
    if (rssi != null) 'rssi': rssi,
    if (snr != null) 'snr': snr,
  };

  factory RegionInfo.fromJson(Map<String, dynamic> j) => RegionInfo(
    regions: (j['regions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    askedAt: DateTime.tryParse(j['askedAt'] as String? ?? '') ?? DateTime(1970),
    answered: j['answered'] == true,
    rssi: (j['rssi'] as num?)?.toInt(),
    snr: (j['snr'] as num?)?.toInt(),
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
  static const _askLogKey = 'region_ask_log_v1';

  /// A repeater that answered is not asked again for this long. Its regions
  /// only change when somebody reconfigures it.
  static const answeredTtl = Duration(days: 7);

  /// A repeater that ignored us is retried after this long. Short enough to
  /// pick up a node that was simply out of range on the last drive, long
  /// enough not to spend the airtime budget on a node that never answers.
  static const unansweredTtl = Duration(hours: 6);

  /// Firmware allows 4 anon requests per 3 minutes (`anon_limiter(4, 180)`).
  /// Three attempts leaves one spare for the owner/clock request types, which
  /// share that same counter. This is the ceiling, not the drive-time value —
  /// see `AppConfigService.regionDiscovery.attempts`.
  static const maxAttempts = 3;

  /// How many past asks to keep for threshold fitting. ~100 bytes each, so this
  /// is well under a megabyte and several drives deep.
  static const askLogLimit = 2000;

  final Map<String, RegionInfo> _cache = {};
  final List<Map<String, dynamic>> _askLog = [];
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
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              _cache[k.toString()] =
                  RegionInfo.fromJson(Map<String, dynamic>.from(v));
            }
          });
        }
      }
    } catch (_) {
      // A corrupt cache is not worth losing a drive over — start empty.
      _cache.clear();
    }
    // Loaded separately so a corrupt ask log cannot cost us the region cache,
    // or the other way round.
    try {
      final rawLog = prefs.getString(_askLogKey);
      if (rawLog != null) {
        final decoded = jsonDecode(rawLog);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) _askLog.add(Map<String, dynamic>.from(e));
          }
        }
      }
    } catch (_) {
      _askLog.clear();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(_cache.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await prefs.setString(_askLogKey, jsonEncode(_askLog));
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

  Future<void> record(
    String nodeId,
    List<String> regions, {
    required bool answered,
    int? rssi,
    int? snr,
  }) async {
    await _load();
    final now = DateTime.now();
    _cache[nodeId.toUpperCase()] = RegionInfo(
      regions: regions,
      askedAt: now,
      answered: answered,
      rssi: rssi,
      snr: snr,
    );
    // The cache holds only the latest state per repeater, which is what the map
    // needs but is useless for tuning: a node asked five times leaves one row.
    // The ask log keeps every attempt, and that is the sample the signal
    // threshold gets fitted from.
    _askLog.add({
      'nodeId': nodeId.toUpperCase(),
      'at': now.toIso8601String(),
      'answered': answered,
      'regionCount': answered ? regions.length : null,
      'rssi': rssi,
      'snr': snr,
    });
    if (_askLog.length > askLogLimit) {
      _askLog.removeRange(0, _askLog.length - askLogLimit);
    }
    await _save();
  }

  /// Every region request made, oldest first — the raw sample for choosing the
  /// signal floor. Bounded, so a long-running install cannot grow without limit.
  Future<List<Map<String, dynamic>>> askLog() async {
    await _load();
    return List<Map<String, dynamic>>.unmodifiable(_askLog);
  }

  /// Answer rate bucketed by RSSI — the curve the threshold comes from.
  ///
  /// Returns `{bucketFloorDbm: {asked, answered}}` in 10 dBm buckets. Reported
  /// as counts rather than a percentage on purpose: a bucket with 1 ask and 1
  /// answer is not "100%", and a rate alone hides that.
  Future<Map<int, Map<String, int>>> answerRateByRssi({int bucketSize = 10}) async {
    await _load();
    final out = <int, Map<String, int>>{};
    for (final e in _askLog) {
      final rssi = (e['rssi'] as num?)?.toInt();
      if (rssi == null) continue;
      final bucket = (rssi / bucketSize).floor() * bucketSize;
      final row = out.putIfAbsent(bucket, () => {'asked': 0, 'answered': 0});
      row['asked'] = row['asked']! + 1;
      if (e['answered'] == true) row['answered'] = row['answered']! + 1;
    }
    return out;
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
