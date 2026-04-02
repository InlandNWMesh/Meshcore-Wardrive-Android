import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _showSamplesKey = 'show_samples';
  static const String _showGpsSamplesKey = 'show_gps_samples';
  static const String _showCoverageKey = 'show_coverage';
  static const String _showEdgesKey = 'show_edges';
  static const String _showRepeatersKey = 'show_repeaters';
  static const String _colorModeKey = 'color_mode';
  static const String _pingIntervalKey = 'ping_interval_meters';
  static const String _coveragePrecisionKey = 'coverage_precision';
  static const String _ignoredRepeaterPrefixKey = 'ignored_repeater_prefix';
  static const String _geofenceNorthKey = 'geofence_north';
  static const String _geofenceSouthKey = 'geofence_south';
  static const String _geofenceEastKey  = 'geofence_east';
  static const String _geofenceWestKey  = 'geofence_west';
  static const String _includeOnlyRepeatersKey = 'include_only_repeaters';
  
  Future<bool> getShowSamples() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showSamplesKey) ?? false;
  }
  
  Future<void> setShowSamples(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSamplesKey, value);
  }
  
  Future<bool> getShowGpsSamples() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showGpsSamplesKey) ?? true;
  }
  
  Future<void> setShowGpsSamples(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showGpsSamplesKey, value);
  }
  
  Future<bool> getShowCoverage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showCoverageKey) ?? true;
  }
  
  Future<void> setShowCoverage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCoverageKey, value);
  }
  
  Future<bool> getShowEdges() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showEdgesKey) ?? true;
  }
  
  Future<void> setShowEdges(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showEdgesKey, value);
  }
  
  Future<bool> getShowRepeaters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showRepeatersKey) ?? true;
  }
  
  Future<void> setShowRepeaters(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showRepeatersKey, value);
  }
  
  Future<String> getColorMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_colorModeKey) ?? 'quality';
  }
  
  Future<void> setColorMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_colorModeKey, value);
  }
  
  Future<double> getPingInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_pingIntervalKey) ?? 50.0; // Default 50 meters
  }
  
  Future<void> setPingInterval(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pingIntervalKey, value);
  }
  
  Future<int> getCoveragePrecision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_coveragePrecisionKey) ?? 6; // Default precision 6
  }
  
  Future<void> setCoveragePrecision(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coveragePrecisionKey, value);
  }
  
  Future<String?> getIgnoredRepeaterPrefix() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ignoredRepeaterPrefixKey);
  }
  
  Future<void> setIgnoredRepeaterPrefix(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_ignoredRepeaterPrefixKey);
    } else {
      await prefs.setString(_ignoredRepeaterPrefixKey, value);
    }
  }
  
  /// Get comma-separated list of repeater prefixes to ONLY hear from (whitelist)
  /// Empty or null = hear from all repeaters
  Future<String?> getIncludeOnlyRepeaters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_includeOnlyRepeatersKey);
  }
  
  Future<void> setIncludeOnlyRepeaters(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_includeOnlyRepeatersKey);
    } else {
      await prefs.setString(_includeOnlyRepeatersKey, value);
    }
  }

  /// Returns the user collection geofence as {north, south, east, west}, or null if not set.
  Future<Map<String, double>?> getGeofence() async {
    final prefs = await SharedPreferences.getInstance();
    final north = prefs.getDouble(_geofenceNorthKey);
    if (north == null) return null;
    return {
      'north': north,
      'south': prefs.getDouble(_geofenceSouthKey)!,
      'east':  prefs.getDouble(_geofenceEastKey)!,
      'west':  prefs.getDouble(_geofenceWestKey)!,
    };
  }

  Future<void> setGeofence(double north, double south, double east, double west) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_geofenceNorthKey, north);
    await prefs.setDouble(_geofenceSouthKey, south);
    await prefs.setDouble(_geofenceEastKey,  east);
    await prefs.setDouble(_geofenceWestKey,  west);
  }

  Future<void> clearGeofence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_geofenceNorthKey);
    await prefs.remove(_geofenceSouthKey);
    await prefs.remove(_geofenceEastKey);
    await prefs.remove(_geofenceWestKey);
  }
}
