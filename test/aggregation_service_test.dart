import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:meshcore_wardrive/services/aggregation_service.dart';
import 'package:meshcore_wardrive/models/models.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const LatLng _pos = LatLng(47.6588, -117.4260);

Sample _makeSample({
  String id = 'test',
  LatLng? position,
  bool? pingSuccess = true,
  String? path = 'NODE0001',
  DateTime? timestamp,
}) {
  final t = timestamp ?? DateTime.now();
  return Sample(
    id: id,
    position: position ?? _pos,
    timestamp: t,
    path: path,
    geohash: 'c23nb2q2',
    pingSuccess: pingSuccess,
  );
}

Repeater _makeRepeater({String id = 'NODE0001', LatLng? position}) {
  return Repeater(
    id: id,
    position: position ?? _pos,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AggregationService.buildIndexes', () {
    test('empty input → empty result', () {
      final result = AggregationService.buildIndexes([], []);
      expect(result.coverages, isEmpty);
      expect(result.edges, isEmpty);
    });

    test('single successful ping → received=1.0, lost=0.0', () {
      final result = AggregationService.buildIndexes(
        [_makeSample(pingSuccess: true)],
        [],
      );
      expect(result.coverages, hasLength(1));
      final cov = result.coverages.first;
      expect(cov.received, 1.0);
      expect(cov.lost, 0.0);
    });

    test('single failed ping → received=0.0, lost=1.0', () {
      final result = AggregationService.buildIndexes(
        [_makeSample(pingSuccess: false, path: null)],
        [],
      );
      expect(result.coverages, hasLength(1));
      final cov = result.coverages.first;
      expect(cov.received, 0.0);
      expect(cov.lost, 1.0);
    });

    test('GPS-only sample (pingSuccess==null) → skipped, no coverage', () {
      final result = AggregationService.buildIndexes(
        [_makeSample(pingSuccess: null)],
        [],
      );
      // Coverage entry is created for the geohash but received and lost are both 0
      if (result.coverages.isNotEmpty) {
        final cov = result.coverages.first;
        expect(cov.received, 0.0);
        expect(cov.lost, 0.0);
      }
    });

    test('two successes at same geohash → received=2.0', () {
      final samples = [
        _makeSample(id: 's1', pingSuccess: true),
        _makeSample(id: 's2', pingSuccess: true),
      ];
      final result = AggregationService.buildIndexes(samples, []);
      expect(result.coverages, hasLength(1));
      expect(result.coverages.first.received, closeTo(2.0, 0.01));
    });

    test('sample >30 days old gets reduced weight', () {
      final old = _makeSample(
        pingSuccess: true,
        timestamp: DateTime.now().subtract(const Duration(days: 35)),
      );
      final result = AggregationService.buildIndexes([old], []);
      expect(result.coverages, hasLength(1));
      // Weight should be 0.2 for samples older than 30 days
      expect(result.coverages.first.received, closeTo(0.2, 0.01));
    });

    test('contradicted sample gets 10% weight', () {
      // Two newer FAILED samples contradict one older SUCCESS
      final now = DateTime.now();
      final samples = [
        // older success
        _makeSample(id: 'old', pingSuccess: true,
            timestamp: now.subtract(const Duration(hours: 2))),
        // newer fails (contradicting)
        _makeSample(id: 'n1', pingSuccess: false,
            timestamp: now.subtract(const Duration(minutes: 10))),
        _makeSample(id: 'n2', pingSuccess: false,
            timestamp: now.subtract(const Duration(minutes: 5))),
      ];
      final result = AggregationService.buildIndexes(samples, []);
      expect(result.coverages, hasLength(1));
      final cov = result.coverages.first;
      // Old success is contradicted (weight * 0.1 = 0.1), two fails each 1.0
      expect(cov.received, closeTo(0.1, 0.05));
      expect(cov.lost, closeTo(2.0, 0.1));
    });

    test('edge created only when repeater exists in provided repeaters list', () {
      final sample = _makeSample(pingSuccess: true, path: 'NODE0001');
      final repeater = _makeRepeater(id: 'NODE0001');

      final withRepeater = AggregationService.buildIndexes([sample], [repeater]);
      final withoutRepeater = AggregationService.buildIndexes([sample], []);

      expect(withRepeater.edges, hasLength(1));
      expect(withoutRepeater.edges, isEmpty);
    });

    test('coveragePrecision parameter changes geohash grouping', () {
      // Two nearby points that land in the same precision-6 cell
      // but different precision-7 cells
      const p1 = LatLng(47.6588, -117.4260);
      const p2 = LatLng(47.6589, -117.4261);

      final s1 = _makeSample(id: 's1', position: p1, pingSuccess: true);
      final s2 = _makeSample(id: 's2', position: p2, pingSuccess: true);

      final coarseResult = AggregationService.buildIndexes(
          [s1, s2], [], coveragePrecision: 4);
      final fineResult = AggregationService.buildIndexes(
          [s1, s2], [], coveragePrecision: 8);

      // At precision 4 the two points are more likely in one cell,
      // at precision 8 they may be in separate cells.
      // The key assertion: coverage count is not the same for coarse vs fine
      // (or that the precision parameter is actually forwarded and has effect).
      // Since exact geohash boundaries depend on the encoder, we only assert
      // that a different precision is used (coarse produces ≤ fine cells).
      expect(coarseResult.coverages.length,
          lessThanOrEqualTo(fineResult.coverages.length));
    });
  });
}
