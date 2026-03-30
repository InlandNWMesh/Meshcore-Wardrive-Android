import '../constants/map_constants.dart';

class MapDisplaySettings {
  final String colorMode;
  final bool showSamples;
  final bool showGpsSamples;
  final bool showSuccessfulOnly;
  final bool showCoverage;
  final bool showEdges;
  final bool showRepeaters;
  final bool autoPingEnabled;
  final String? ignoredRepeaterPrefix;
  final String? includeOnlyRepeaters;
  final double pingIntervalMeters;
  final int coveragePrecision;

  const MapDisplaySettings({
    this.colorMode = 'quality',
    this.showSamples = false,
    this.showGpsSamples = true,
    this.showSuccessfulOnly = false,
    this.showCoverage = true,
    this.showEdges = true,
    this.showRepeaters = true,
    this.autoPingEnabled = false,
    this.ignoredRepeaterPrefix,
    this.includeOnlyRepeaters,
    this.pingIntervalMeters = kDefaultPingIntervalMeters,
    this.coveragePrecision = kDefaultCoveragePrecision,
  });

  MapDisplaySettings copyWith({
    String? colorMode,
    bool? showSamples,
    bool? showGpsSamples,
    bool? showSuccessfulOnly,
    bool? showCoverage,
    bool? showEdges,
    bool? showRepeaters,
    bool? autoPingEnabled,
    Object? ignoredRepeaterPrefix = _sentinel,
    Object? includeOnlyRepeaters = _sentinel,
    double? pingIntervalMeters,
    int? coveragePrecision,
  }) {
    return MapDisplaySettings(
      colorMode: colorMode ?? this.colorMode,
      showSamples: showSamples ?? this.showSamples,
      showGpsSamples: showGpsSamples ?? this.showGpsSamples,
      showSuccessfulOnly: showSuccessfulOnly ?? this.showSuccessfulOnly,
      showCoverage: showCoverage ?? this.showCoverage,
      showEdges: showEdges ?? this.showEdges,
      showRepeaters: showRepeaters ?? this.showRepeaters,
      autoPingEnabled: autoPingEnabled ?? this.autoPingEnabled,
      ignoredRepeaterPrefix: identical(ignoredRepeaterPrefix, _sentinel)
          ? this.ignoredRepeaterPrefix
          : ignoredRepeaterPrefix as String?,
      includeOnlyRepeaters: identical(includeOnlyRepeaters, _sentinel)
          ? this.includeOnlyRepeaters
          : includeOnlyRepeaters as String?,
      pingIntervalMeters: pingIntervalMeters ?? this.pingIntervalMeters,
      coveragePrecision: coveragePrecision ?? this.coveragePrecision,
    );
  }
}

// Sentinel for nullable copyWith fields
const Object _sentinel = Object();
