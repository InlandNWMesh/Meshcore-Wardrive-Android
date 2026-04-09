import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geohash_plus/geohash_plus.dart' as geohash;
import '../models/models.dart';
import '../services/aggregation_service.dart';

// ── Coverage layer ────────────────────────────────────────────────────────────

List<Widget> buildCoverageLayers(
  AggregationResult result,
  String colorMode,
  void Function(Coverage) onCoverageTap,
) {
  final coveragePolygons = <Polygon>[];
  final coverageMarkers = <Marker>[];

  for (final coverage in result.coverages) {
    final gh = geohash.GeoHash.decode(coverage.id);
    final color = Color(AggregationService.getCoverageColor(coverage, colorMode));
    final opacity = AggregationService.getCoverageOpacity(coverage);

    final sw = gh.bounds.southWest;
    final ne = gh.bounds.northEast;

    coveragePolygons.add(
      Polygon(
        points: [
          LatLng(sw.latitude, sw.longitude),
          LatLng(sw.latitude, ne.longitude),
          LatLng(ne.latitude, ne.longitude),
          LatLng(ne.latitude, sw.longitude),
        ],
        color: color.withValues(alpha: opacity),
        borderColor: color,
        borderStrokeWidth: 1,
        isFilled: true,
      ),
    );

    coverageMarkers.add(
      Marker(
        point: coverage.position,
        width: 100,
        height: 100,
        child: GestureDetector(
          onTap: () => onCoverageTap(coverage),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  return [
    PolygonLayer(polygons: coveragePolygons),
    MarkerLayer(markers: coverageMarkers),
  ];
}

// ── Sample layer ──────────────────────────────────────────────────────────────

Widget buildSampleLayer(
  List<Sample> filteredSamples,
  void Function(Sample) onSampleTap,
) {
  if (filteredSamples.isEmpty) return const SizedBox.shrink();

  final markers = filteredSamples.map((sample) {
    Color markerColor;
    if (sample.pingSuccess == true) {
      markerColor = Colors.green;
    } else if (sample.pingSuccess == false) {
      markerColor = Colors.red;
    } else {
      markerColor = Colors.blue;
    }

    return Marker(
      point: sample.position,
      width: 12,
      height: 12,
      child: GestureDetector(
        onTap: () => onSampleTap(sample),
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: markerColor.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(
              color: markerColor.withValues(alpha: 0.9),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }).toList();

  return MarkerLayer(markers: markers);
}

// ── Edge layer ────────────────────────────────────────────────────────────────

Widget buildEdgeLayer(AggregationResult result, {int? maxEdgeResponses}) {
  var edges = result.edges;

  if (maxEdgeResponses != null && edges.length > maxEdgeResponses) {
    // Keep only the N most-recently-active edges
    final sorted = List<Edge>.from(edges)
      ..sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // newest first
      });
    edges = sorted.take(maxEdgeResponses).toList();
  }

  final polylines = edges.map((edge) {
    return Polyline(
      points: [edge.coverage.position, edge.repeater.position],
      color: Colors.purple.withValues(alpha: 0.6),
      strokeWidth: 2,
    );
  }).toList();

  return PolylineLayer(polylines: polylines);
}

// ── Repeater layer ────────────────────────────────────────────────────────────

Widget buildRepeaterLayer(
  List<Repeater> repeaters,
  void Function(Repeater) onRepeaterTap,
) {
  if (repeaters.isEmpty) return const SizedBox.shrink();

  final markers = repeaters.map((repeater) {
    return Marker(
      point: repeater.position,
      width: 30,
      height: 30,
      child: GestureDetector(
        onTap: () => onRepeaterTap(repeater),
        child: const Icon(Icons.cell_tower, color: Colors.purple, size: 30),
      ),
    );
  }).toList();

  return MarkerLayer(markers: markers);
}

// ── Current location layer ────────────────────────────────────────────────────

Widget buildCurrentLocationLayer(LatLng position, bool showPingPulse) {
  final markers = <Marker>[
    Marker(
      point: position,
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    ),
  ];

  if (showPingPulse) {
    markers.add(
      Marker(
        point: position,
        width: 60,
        height: 60,
        child: TweenAnimationBuilder(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, double value, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 1.0 - value),
                  width: 3,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  return MarkerLayer(markers: markers);
}
