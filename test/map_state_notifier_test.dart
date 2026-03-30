import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshcore_wardrive/state/map_state_notifier.dart';
import 'package:meshcore_wardrive/models/models.dart';
import 'package:meshcore_wardrive/models/map_display_settings.dart';
import 'package:meshcore_wardrive/services/lora_companion_service.dart';
import 'package:meshcore_wardrive/services/aggregation_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const LatLng _pos = LatLng(47.6588, -117.4260);

Sample _makeSample({String id = 'test', bool? pingSuccess = true}) {
  return Sample(
    id: id,
    position: _pos,
    timestamp: DateTime.now(),
    path: 'NODE0001',
    geohash: 'c23nb2q2',
    pingSuccess: pingSuccess,
  );
}

AggregationResult _emptyResult() =>
    AggregationService.buildIndexes([], []);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MapStateNotifier', () {
    late MapStateNotifier notifier;

    setUp(() {
      notifier = MapStateNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('initial state has sensible defaults', () {
      final s = notifier.state;
      expect(s.isTracking, isFalse);
      expect(s.samples, isEmpty);
      expect(s.filteredSamples, isEmpty);
      expect(s.loraConnected, isFalse);
      expect(s.showPingPulse, isFalse);
      expect(s.followLocation, isFalse);
      expect(s.lockRotationNorth, isFalse);
    });

    group('tracking transitions', () {
      test('setTracking(true) sets isTracking and autoPingEnabled', () {
        notifier.setTracking(isTracking: true, autoPingEnabled: true);
        expect(notifier.state.isTracking, isTrue);
        expect(notifier.state.displaySettings.autoPingEnabled, isTrue);
      });

      test('setTracking(false) clears both flags', () {
        notifier.setTracking(isTracking: true, autoPingEnabled: true);
        notifier.setTracking(isTracking: false, autoPingEnabled: false);
        expect(notifier.state.isTracking, isFalse);
        expect(notifier.state.displaySettings.autoPingEnabled, isFalse);
      });
    });

    group('display settings', () {
      test('setShowCoverage toggles showCoverage', () {
        expect(notifier.state.displaySettings.showCoverage, isTrue);
        notifier.setShowCoverage(false);
        expect(notifier.state.displaySettings.showCoverage, isFalse);
        notifier.setShowCoverage(true);
        expect(notifier.state.displaySettings.showCoverage, isTrue);
      });

      test('setColorMode updates colorMode', () {
        notifier.setColorMode('age');
        expect(notifier.state.displaySettings.colorMode, 'age');
      });

      test('updateDisplaySettings replaces the full settings object', () {
        const newSettings = MapDisplaySettings(showSamples: true, colorMode: 'age');
        notifier.updateDisplaySettings(newSettings);
        expect(notifier.state.displaySettings.showSamples, isTrue);
        expect(notifier.state.displaySettings.colorMode, 'age');
      });
    });

    group('sample load triggers filtered list recompute', () {
      test('successful samples pass through by default', () {
        final samples = [_makeSample(id: 's1', pingSuccess: true)];
        notifier.updateFromSampleLoad(
          samples: samples,
          sampleCount: 1,
          aggregationResult: _emptyResult(),
          loraConnected: false,
          connectionType: ConnectionType.none,
          autoPingEnabled: false,
          repeaters: [],
        );
        expect(notifier.state.filteredSamples, hasLength(1));
      });

      test('GPS-only samples filtered when showGpsSamples=false', () {
        final gpsSample = _makeSample(id: 'gps', pingSuccess: null);
        final pingSample = _makeSample(id: 'ping', pingSuccess: true);

        // First set display settings to hide GPS samples
        notifier.setShowGpsSamples(false);

        notifier.updateFromSampleLoad(
          samples: [gpsSample, pingSample],
          sampleCount: 2,
          aggregationResult: _emptyResult(),
          loraConnected: false,
          connectionType: ConnectionType.none,
          autoPingEnabled: false,
          repeaters: [],
        );
        expect(notifier.state.filteredSamples, hasLength(1));
        expect(notifier.state.filteredSamples.first.id, 'ping');
      });

      test('setShowGpsSamples refilters existing sample list', () {
        final gpsSample = _makeSample(id: 'gps', pingSuccess: null);
        notifier.updateFromSampleLoad(
          samples: [gpsSample],
          sampleCount: 1,
          aggregationResult: _emptyResult(),
          loraConnected: false,
          connectionType: ConnectionType.none,
          autoPingEnabled: false,
          repeaters: [],
        );
        expect(notifier.state.filteredSamples, hasLength(1));

        notifier.setShowGpsSamples(false);
        expect(notifier.state.filteredSamples, isEmpty);
      });
    });

    group('position and battery', () {
      test('setPosition updates currentPosition', () {
        expect(notifier.state.currentPosition, isNull);
        notifier.setPosition(_pos);
        expect(notifier.state.currentPosition, equals(_pos));
      });

      test('setBattery updates batteryPercent', () {
        notifier.setBattery(72);
        expect(notifier.state.batteryPercent, 72);
        notifier.setBattery(null);
        expect(notifier.state.batteryPercent, isNull);
      });
    });

    test('ping pulse can be set and cleared', () {
      notifier.setPingPulse(true);
      expect(notifier.state.showPingPulse, isTrue);
      notifier.setPingPulse(false);
      expect(notifier.state.showPingPulse, isFalse);
    });

    test('notifyListeners fires on state change', () {
      int callCount = 0;
      notifier.addListener(() => callCount++);

      notifier.setTracking(isTracking: true, autoPingEnabled: false);
      notifier.setPingPulse(true);
      notifier.setColorMode('age');

      expect(callCount, 3);
    });
  });
}
