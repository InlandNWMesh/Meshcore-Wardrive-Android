import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';

/// Full-screen map editor for the user's collection geofence rectangle.
/// The user drags the 4 corner handles to resize the rectangle.
class GeofenceScreen extends StatefulWidget {
  final LocationService locationService;
  final SettingsService settingsService;

  const GeofenceScreen({
    super.key,
    required this.locationService,
    required this.settingsService,
  });

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final MapController _mapController = MapController();

  // Rectangle bounds (lat/lng)
  late double _north, _south, _east, _west;
  bool _loaded = false;

  // Which corner is being dragged: 0=NW 1=NE 2=SE 3=SW, -1=none
  int _draggingCorner = -1;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final fence = await widget.settingsService.getGeofence();
    final pos = widget.locationService.currentPosition;
    if (fence != null) {
      setState(() {
        _north = fence['north']!;
        _south = fence['south']!;
        _east  = fence['east']!;
        _west  = fence['west']!;
        _loaded = true;
      });
    } else {
      // Default: 500m rectangle around current position (or fallback)
      final center = pos ?? const LatLng(47.6588, -117.4260);
      const delta = 0.005; // ~500m
      setState(() {
        _north = center.latitude  + delta;
        _south = center.latitude  - delta;
        _east  = center.longitude + delta;
        _west  = center.longitude - delta;
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    await widget.settingsService.setGeofence(_north, _south, _east, _west);
    widget.locationService.setGeofence({
      'north': _north, 'south': _south, 'east': _east, 'west': _west,
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear geofence?'),
        content: const Text('Logging will resume everywhere.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.settingsService.clearGeofence();
      widget.locationService.setGeofence(null);
      if (mounted) Navigator.pop(context, true);
    }
  }

  // Convert lat/lng to screen position using the map controller
  Offset? _toScreen(double lat, double lng) {
    try {
      final point = _mapController.camera.latLngToScreenPoint(LatLng(lat, lng));
      return Offset(point.x, point.y);
    } catch (_) {
      return null;
    }
  }

  // Convert screen offset to lat/lng
  LatLng _fromScreen(Offset offset) {
    return _mapController.camera.pointToLatLng(
      math.Point(offset.dx, offset.dy),
    );
  }

  List<Offset?> get _cornerOffsets => [
    _toScreen(_north, _west), // NW
    _toScreen(_north, _east), // NE
    _toScreen(_south, _east), // SE
    _toScreen(_south, _west), // SW
  ];

  void _onDragUpdate(DragUpdateDetails details, int corner) {
    final raw = details.localPosition;
    final latLng = _fromScreen(raw);
    setState(() {
      switch (corner) {
        case 0: _north = latLng.latitude;  _west = latLng.longitude; break; // NW
        case 1: _north = latLng.latitude;  _east = latLng.longitude; break; // NE
        case 2: _south = latLng.latitude;  _east = latLng.longitude; break; // SE
        case 3: _south = latLng.latitude;  _west = latLng.longitude; break; // SW
      }
      // Clamp so north > south and east > west
      if (_north < _south) { final t = _north; _north = _south; _south = t; }
      if (_east  < _west)  { final t = _east;  _east  = _west;  _west  = t; }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final center = LatLng((_north + _south) / 2, (_east + _west) / 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Geofence'),
        actions: [
          TextButton(onPressed: _clear, child: Text('Clear', style: TextStyle(color: theme.colorScheme.error))),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              interactionOptions: InteractionOptions(
                // Disable map drag when dragging a corner
                flags: _draggingCorner == -1
                    ? InteractiveFlag.all
                    : InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
              ),
              onMapEvent: (_) => setState(() {}), // rebuild handles on pan/zoom
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.inwmesh.wardrive',
              ),
              PolygonLayer(polygons: [
                Polygon(
                  points: [
                    LatLng(_north, _west),
                    LatLng(_north, _east),
                    LatLng(_south, _east),
                    LatLng(_south, _west),
                  ],
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderColor: Colors.orange,
                  borderStrokeWidth: 2,
                  isFilled: true,
                ),
              ]),
            ],
          ),

          // ── Corner drag handles ───────────────────────────────
          ...List.generate(4, (i) {
            final offsets = _cornerOffsets;
            final off = offsets[i];
            if (off == null) return const SizedBox.shrink();
            return Positioned(
              left: off.dx - 14,
              top:  off.dy - 14,
              child: GestureDetector(
                onPanStart: (_) => setState(() => _draggingCorner = i),
                onPanUpdate: (d) => _onDragUpdate(d, i),
                onPanEnd: (_) => setState(() => _draggingCorner = -1),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ),
            );
          }),

          // ── Hint banner ───────────────────────────────────────
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Drag the orange corner handles to set the collection boundary.\nPings are paused outside this area.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
