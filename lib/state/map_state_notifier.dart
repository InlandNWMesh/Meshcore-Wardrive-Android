import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../models/map_display_settings.dart';
import '../services/aggregation_service.dart';
import '../services/lora_companion_service.dart';

// ── MapState ─────────────────────────────────────────────────────────────────

class MapState {
  final bool isTracking;
  final int sampleCount;
  final List<Sample> samples;
  final List<Sample> filteredSamples;
  final AggregationResult? aggregationResult;
  final MapDisplaySettings displaySettings;
  final List<Repeater> repeaters;
  final LatLng? currentPosition;
  final bool showPingPulse;
  final bool loraConnected;
  final ConnectionType connectionType;
  final int? batteryPercent;
  final bool followLocation;
  final bool lockRotationNorth;

  const MapState({
    this.isTracking = false,
    this.sampleCount = 0,
    this.samples = const [],
    this.filteredSamples = const [],
    this.aggregationResult,
    this.displaySettings = const MapDisplaySettings(),
    this.repeaters = const [],
    this.currentPosition,
    this.showPingPulse = false,
    this.loraConnected = false,
    this.connectionType = ConnectionType.none,
    this.batteryPercent,
    this.followLocation = false,
    this.lockRotationNorth = false,
  });

  MapState copyWith({
    bool? isTracking,
    int? sampleCount,
    List<Sample>? samples,
    List<Sample>? filteredSamples,
    AggregationResult? aggregationResult,
    MapDisplaySettings? displaySettings,
    List<Repeater>? repeaters,
    LatLng? currentPosition,
    bool? showPingPulse,
    bool? loraConnected,
    ConnectionType? connectionType,
    int? batteryPercent,
    bool? followLocation,
    bool? lockRotationNorth,
    bool clearBattery = false,
    bool clearPosition = false,
    bool clearAggregation = false,
  }) {
    return MapState(
      isTracking: isTracking ?? this.isTracking,
      sampleCount: sampleCount ?? this.sampleCount,
      samples: samples ?? this.samples,
      filteredSamples: filteredSamples ?? this.filteredSamples,
      aggregationResult: clearAggregation ? null : (aggregationResult ?? this.aggregationResult),
      displaySettings: displaySettings ?? this.displaySettings,
      repeaters: repeaters ?? this.repeaters,
      currentPosition: clearPosition ? null : (currentPosition ?? this.currentPosition),
      showPingPulse: showPingPulse ?? this.showPingPulse,
      loraConnected: loraConnected ?? this.loraConnected,
      connectionType: connectionType ?? this.connectionType,
      batteryPercent: clearBattery ? null : (batteryPercent ?? this.batteryPercent),
      followLocation: followLocation ?? this.followLocation,
      lockRotationNorth: lockRotationNorth ?? this.lockRotationNorth,
    );
  }
}

// ── MapStateNotifier ─────────────────────────────────────────────────────────

class MapStateNotifier extends ChangeNotifier {
  MapState _state = const MapState();

  MapState get state => _state;

  void _update(MapState next) {
    _state = next;
    notifyListeners();
  }

  // ── Tracking ───────────────────────────────────────────────────────────────

  void setTracking({required bool isTracking, required bool autoPingEnabled}) {
    _update(_state.copyWith(
      isTracking: isTracking,
      displaySettings: _state.displaySettings.copyWith(autoPingEnabled: autoPingEnabled),
    ));
  }

  // ── Samples ────────────────────────────────────────────────────────────────

  void updateFromSampleLoad({
    required List<Sample> samples,
    required int sampleCount,
    required AggregationResult aggregationResult,
    required bool loraConnected,
    required ConnectionType connectionType,
    required bool autoPingEnabled,
    required List<Repeater> repeaters,
  }) {
    final filtered = _computeFilteredSamples(samples, _state.displaySettings);
    _update(_state.copyWith(
      samples: samples,
      sampleCount: sampleCount,
      aggregationResult: aggregationResult,
      loraConnected: loraConnected,
      connectionType: connectionType,
      displaySettings: _state.displaySettings.copyWith(autoPingEnabled: autoPingEnabled),
      repeaters: repeaters,
      filteredSamples: filtered,
    ));
  }

  // ── Position ───────────────────────────────────────────────────────────────

  void setPosition(LatLng position) {
    _update(_state.copyWith(currentPosition: position));
  }

  // ── Battery ────────────────────────────────────────────────────────────────

  void setBattery(int? percent) {
    if (percent == null) {
      _update(_state.copyWith(clearBattery: true));
    } else {
      _update(_state.copyWith(batteryPercent: percent));
    }
  }

  // ── Ping pulse ─────────────────────────────────────────────────────────────

  void setPingPulse(bool value) {
    _update(_state.copyWith(showPingPulse: value));
  }

  // ── Map controls ───────────────────────────────────────────────────────────

  void setFollowLocation(bool value) {
    _update(_state.copyWith(followLocation: value));
  }

  void setLockRotation(bool value) {
    _update(_state.copyWith(lockRotationNorth: value));
  }

  // ── Display settings ───────────────────────────────────────────────────────

  void updateDisplaySettings(MapDisplaySettings settings) {
    final filtered = _computeFilteredSamples(_state.samples, settings);
    _update(_state.copyWith(displaySettings: settings, filteredSamples: filtered));
  }

  // Convenience single-field updates that go through display settings
  void setShowCoverage(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showCoverage: v));
  void setShowSamples(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showSamples: v));
  void setShowEdges(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showEdges: v));
  void setShowRepeaters(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showRepeaters: v));
  void setShowGpsSamples(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showGpsSamples: v));
  void setShowSuccessfulOnly(bool v) => updateDisplaySettings(_state.displaySettings.copyWith(showSuccessfulOnly: v));
  void setColorMode(String v) => updateDisplaySettings(_state.displaySettings.copyWith(colorMode: v));
  void setPingIntervalMeters(double v) => updateDisplaySettings(_state.displaySettings.copyWith(pingIntervalMeters: v));
  void setCoveragePrecision(int v) => updateDisplaySettings(_state.displaySettings.copyWith(coveragePrecision: v));
  void setIgnoredRepeaterPrefix(String? v) => updateDisplaySettings(_state.displaySettings.copyWith(ignoredRepeaterPrefix: v));
  void setIncludeOnlyRepeaters(String? v) => updateDisplaySettings(_state.displaySettings.copyWith(includeOnlyRepeaters: v));

  // ── Filtered sample computation ────────────────────────────────────────────

  static List<Sample> _computeFilteredSamples(
    List<Sample> samples,
    MapDisplaySettings settings,
  ) {
    return samples.where((sample) {
      if (!settings.showGpsSamples && sample.pingSuccess == null) return false;
      if (settings.showSuccessfulOnly && sample.pingSuccess != true) return false;
      if (settings.includeOnlyRepeaters != null && settings.includeOnlyRepeaters!.isNotEmpty) {
        final allowedPrefixes = settings.includeOnlyRepeaters!
            .split(',').map((s) => s.trim().toUpperCase()).toList();
        final sampleNodeId = sample.path?.toUpperCase() ?? '';
        if (!allowedPrefixes.any((prefix) => sampleNodeId.startsWith(prefix))) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
