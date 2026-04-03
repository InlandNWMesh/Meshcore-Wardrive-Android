import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';

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
  final GlobalKey _mapKey = GlobalKey();

  // null = no fence drawn yet
  double? _north, _south, _east, _west;
  bool _loaded = false;

  // Which corner is being dragged: 0=NW 1=NE 2=SE 3=SW, -1=none
  int _draggingCorner = -1;

  static const double _handleRadius = 20.0; // touch target radius in pixels

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final fence = await widget.settingsService.getGeofence();
    setState(() {
      if (fence != null) {
        _north = fence['north'];
        _south = fence['south'];
        _east  = fence['east'];
        _west  = fence['west'];
      }
      // else: all null → blank state, no rectangle drawn
      _loaded = true;
    });
  }

  bool get _hasFence => _north != null;

  void _drawDefaultRectangle() {
    final pos = widget.locationService.currentPosition;
    final center = pos ?? const LatLng(47.6588, -117.4260);
    const delta = 0.005; // ~500m
    setState(() {
      _north = center.latitude  + delta;
      _south = center.latitude  - delta;
      _east  = center.longitude + delta;
      _west  = center.longitude - delta;
    });
  }

  Future<void> _save() async {
    if (!_hasFence) return;
    await widget.settingsService.setGeofence(_north!, _south!, _east!, _west!);
    widget.locationService.setGeofence({
      'north': _north!, 'south': _south!, 'east': _east!, 'west': _west!,
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

  // Convert lat/lng → pixel position relative to the map widget
  Offset? _toLocal(double lat, double lng) {
    try {
      final pt = _mapController.camera.latLngToScreenPoint(LatLng(lat, lng));
      return Offset(pt.x, pt.y);
    } catch (_) {
      return null;
    }
  }

  // Convert a global screen position → lat/lng via the map widget's RenderBox
  LatLng? _globalToLatLng(Offset globalPos) {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(globalPos);
    return _mapController.camera.pointToLatLng(
      math.Point(local.dx, local.dy),
    );
  }

  List<Offset?> get _cornerOffsets => _hasFence
      ? [
          _toLocal(_north!, _west!), // 0 NW
          _toLocal(_north!, _east!), // 1 NE
          _toLocal(_south!, _east!), // 2 SE
          _toLocal(_south!, _west!), // 3 SW
        ]
      : [null, null, null, null];

  int _nearestCorner(Offset localPos) {
    int best = -1;
    double bestDist = _handleRadius * 2;
    final offsets = _cornerOffsets;
    for (int i = 0; i < 4; i++) {
      if (offsets[i] == null) continue;
      final d = (offsets[i]! - localPos).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!_hasFence) return;
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(details.globalPosition);
    final corner = _nearestCorner(localPos);
    if (corner != -1) {
      setState(() => _draggingCorner = corner);
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_draggingCorner == -1) return;
    final latLng = _globalToLatLng(details.globalPosition);
    if (latLng == null) return;
    setState(() {
      switch (_draggingCorner) {
        case 0: _north = latLng.latitude; _west = latLng.longitude; break; // NW
        case 1: _north = latLng.latitude; _east = latLng.longitude; break; // NE
        case 2: _south = latLng.latitude; _east = latLng.longitude; break; // SE
        case 3: _south = latLng.latitude; _west = latLng.longitude; break; // SW
      }
      // Ensure north > south, east > west
      if (_north! < _south!) { final t = _north!; _north = _south; _south = t; }
      if (_east!  < _west!)  { final t = _east!;  _east  = _west;  _west  = t; }
    });
  }

  void _handlePanEnd(DragEndDetails _) {
    setState(() => _draggingCorner = -1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final center = _hasFence
        ? LatLng((_north! + _south!) / 2, (_east! + _west!) / 2)
        : (widget.locationService.currentPosition ?? const LatLng(47.6588, -117.4260));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Geofence'),
        actions: [
          if (_hasFence)
            TextButton(
              onPressed: _clear,
              child: Text('Clear', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_hasFence)
            TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────
          GestureDetector(
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            // Only block map panning when actively dragging a corner
            behavior: HitTestBehavior.translucent,
            child: FlutterMap(
              key: _mapKey,
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                interactionOptions: InteractionOptions(
                  flags: _draggingCorner == -1
                      ? InteractiveFlag.all
                      : InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
                onMapEvent: (_) => setState(() {}),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.inwmesh.wardrive',
                ),
                if (_hasFence)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: [
                        LatLng(_north!, _west!),
                        LatLng(_north!, _east!),
                        LatLng(_south!, _east!),
                        LatLng(_south!, _west!),
                      ],
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderColor: Colors.orange,
                      borderStrokeWidth: 2,
                      isFilled: true,
                    ),
                  ]),
              ],
            ),
          ),

          // ── Corner handles (rendered in Stack above map) ────────
          if (_hasFence)
            ...List.generate(4, (i) {
              final off = _cornerOffsets[i];
              if (off == null) return const SizedBox.shrink();
              final isActive = _draggingCorner == i;
              return Positioned(
                left: off.dx - _handleRadius,
                top:  off.dy - _handleRadius,
                width:  _handleRadius * 2,
                height: _handleRadius * 2,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange : Colors.orange.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isActive ? 0.4 : 0.25),
                          blurRadius: isActive ? 8 : 4,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

          // ── No-fence empty state ────────────────────────────────
          if (!_hasFence)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No geofence set.\nLogging is active everywhere.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.crop_square),
                    label: const Text('Draw Rectangle'),
                    onPressed: _drawDefaultRectangle,
                  ),
                ],
              ),
            ),

          // ── Hint when fence is drawn ────────────────────────────
          if (_hasFence)
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Drag the orange corner handles to resize.\nPings pause when outside this area.',
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
