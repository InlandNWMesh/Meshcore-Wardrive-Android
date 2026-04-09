import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../services/location_service.dart';
import '../services/aggregation_service.dart';
import '../services/lora_companion_service.dart';
import '../services/database_service.dart';
import '../services/upload_service.dart';
import '../services/settings_service.dart';
import '../utils/geohash_utils.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'debug_log_screen.dart';
import '../constants/map_constants.dart';
import '../models/map_display_settings.dart';
import '../state/map_state_notifier.dart';
import '../widgets/map_layers.dart';
import '../widgets/map_control_panel.dart';
import 'dialogs/show_coverage_info_dialog.dart';
import 'dialogs/show_sample_info_dialog.dart';
import 'dialogs/show_repeater_info_dialog.dart';
import 'dialogs/show_repeaters_dialog.dart';
import 'dialogs/show_upload_settings_dialog.dart';
import 'map_settings_sheet.dart';
import 'chat_screen.dart';
import '../services/chat_service.dart';
import 'geofence_screen.dart';
import '../services/sonar_ping_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // App version is imported from constants/app_version.dart

  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final UploadService _uploadService = UploadService();
  final SettingsService _settingsService = SettingsService();
  late ChatService _chatService;
  late SonarPingService _sonarService;

  late MapStateNotifier _notifier;

  Timer? _updateTimer;
  StreamSubscription<LatLng>? _positionSubscription;
  StreamSubscription<void>? _sampleSavedSubscription;
  StreamSubscription<String>? _pingEventSubscription;
  StreamSubscription<int?>? _batterySubscription;
  StreamSubscription<bool>? _geofenceStatusSubscription;

  bool _outsideGeofence = false;
  Map<String, double>? _activeGeofence; // for map overlay

  @override
  void initState() {
    super.initState();
    _notifier = MapStateNotifier();
    _chatService = ChatService(_locationService.loraCompanion);
    _sonarService = SonarPingService();
    _initialize();
  }

  Future<void> _initialize() async {
    // Load saved settings
    await _loadSettings();
    
    // Subscribe to battery updates
    final loraService = _locationService.loraCompanion;
    _batterySubscription = loraService.batteryStream.listen((percent) {
      _notifier.setBattery(percent);
    });

    // Subscribe to position updates
    _positionSubscription = _locationService.currentPositionStream.listen((position) {
      _notifier.setPosition(position);
      // Auto-follow if enabled
      if (_notifier.state.followLocation) {
        _mapController.move(position, _mapController.camera.zoom);
      }
    });

    // Subscribe to sample saved events - reload map when new samples are saved
    _sampleSavedSubscription = _locationService.sampleSavedStream.listen((_) {
      _loadSamples();
    });

    // Subscribe to ping events for visual feedback
    _pingEventSubscription = _locationService.pingEventStream.listen((event) {
      if (event == 'pinging' && mounted) {
        _notifier.setPingPulse(true);
        // Hide pulse after kPingPulseDurationSeconds
        Future.delayed(Duration(seconds: kPingPulseDurationSeconds), () {
          if (mounted) _notifier.setPingPulse(false);
        });
      }
    });
    
    _geofenceStatusSubscription = _locationService.geofenceStatusStream.listen((outside) {
      if (mounted) setState(() => _outsideGeofence = outside);
    });

    await _loadSamples();
    await _getCurrentLocation();

    // Update periodically
    _updateTimer = Timer.periodic(Duration(seconds: kMapUpdateIntervalSeconds), (_) {
      _loadSamples();
    });
  }
  
  Future<void> _loadSettings() async {
    final showSamples = await _settingsService.getShowSamples();
    final showGpsSamples = await _settingsService.getShowGpsSamples();
    final showCoverage = await _settingsService.getShowCoverage();
    final showEdges = await _settingsService.getShowEdges();
    final showRepeaters = await _settingsService.getShowRepeaters();
    final colorMode = await _settingsService.getColorMode();
    final pingInterval = await _settingsService.getPingInterval();
    final coveragePrecision = await _settingsService.getCoveragePrecision();
    final ignoredPrefix = await _settingsService.getIgnoredRepeaterPrefix();
    final includeOnly = await _settingsService.getIncludeOnlyRepeaters();
    final sonarEnabled = await _settingsService.getSonarPingEnabled();
    final sonarInterval = await _settingsService.getSonarPingInterval();
    _sonarService.enabled = sonarEnabled;
    _sonarService.intervalSeconds = sonarInterval;
    final maxEdges = await _settingsService.getMaxEdgeResponses();
    final lockRotation = await _settingsService.getLockRotationNorth();
    
    _notifier.updateDisplaySettings(MapDisplaySettings(
      showSamples: showSamples,
      showGpsSamples: showGpsSamples,
      showCoverage: showCoverage,
      showEdges: showEdges,
      showRepeaters: showRepeaters,
      colorMode: colorMode,
      pingIntervalMeters: pingInterval,
      coveragePrecision: coveragePrecision,
      ignoredRepeaterPrefix: ignoredPrefix,
      includeOnlyRepeaters: includeOnly,
      maxEdgeResponses: maxEdges,
    ));
    _notifier.setLockRotation(lockRotation);

    // Apply to services
    _locationService.setPingInterval(pingInterval);
    _locationService.loraCompanion.setIgnoredRepeaterPrefix(ignoredPrefix);

    // Load geofence
    final fence = await _settingsService.getGeofence();
    _locationService.setGeofence(fence);
    if (mounted) setState(() => _activeGeofence = fence);
  }

  Future<void> _getCurrentLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _notifier.setPosition(pos);
      // Move map to user's current location on startup
      _mapController.move(pos, kDefaultMapZoom);
    }
  }

  Future<void> _loadSamples() async {
    final samples = await _locationService.getAllSamples();
    final count = await _locationService.getSampleCount();
    
    // Update connection status
    final loraService = _locationService.loraCompanion;
    
    // Sync discovered repeaters from LoRa service
    final discoveredRepeaters = loraService.discoveredRepeaters;
    
    // Aggregate data with user's chosen coverage precision and repeaters
    final result = AggregationService.buildIndexes(
      samples,
      discoveredRepeaters,
      coveragePrecision: _notifier.state.displaySettings.coveragePrecision,
    );

    _notifier.updateFromSampleLoad(
      samples: samples,
      sampleCount: count,
      aggregationResult: result,
      loraConnected: loraService.isDeviceConnected,
      connectionType: loraService.connectionType,
      autoPingEnabled: _locationService.isAutoPingEnabled,
      repeaters: discoveredRepeaters,
    );
  }

  Future<void> _toggleTracking() async {
    if (_notifier.state.isTracking) {
      // Stop tracking and auto-ping
      await _locationService.stopTracking();
      _locationService.disableAutoPing();
      _sonarService.stop();
      _notifier.setTracking(isTracking: false, autoPingEnabled: false);
    } else {
      // Start tracking
      final started = await _locationService.startTracking();
      if (started) {
        _sonarService.start();
        // Auto-enable ping if LoRa is connected
        if (_notifier.state.loraConnected) {
          _locationService.enableAutoPing();
          _notifier.setTracking(isTracking: true, autoPingEnabled: true);
          _showSnackBar('Location tracking and auto-ping started');
        } else {
          _notifier.setTracking(isTracking: true, autoPingEnabled: false);
          _showSnackBar('Location tracking started');
        }
      } else {
        _showSnackBar('Failed to start tracking. Check permissions.');
      }
    }
  }

  Future<void> _clearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Map History'),
        content: const Text('This will delete all recorded samples and coverage from the map. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _locationService.clearAllSamples();
      await _loadSamples();
      _showSnackBar('Map history cleared');
    }
  }

  Future<void> _exportData() async {
    // Ask user if they want to save to folder or share
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('How would you like to export your data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save to Folder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'share'),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (choice == null) return;
    
    try {
      final data = await _locationService.exportSamples();
      final json = jsonEncode(data);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'meshcore_export_$timestamp.json';
      
      if (choice == 'save') {
        // Let user choose where to save (provide bytes for Android/iOS)
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Export',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: utf8.encode(json), // Required on Android/iOS
        );
        
        if (outputFile != null) {
          _showSnackBar('Exported ${data.length} samples');
        }
      } else if (choice == 'share') {
        // Create temporary file and share
        final directory = await getExternalStorageDirectory();
        final file = File('${directory!.path}/$fileName');
        await file.writeAsString(json);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'MeshCore Wardrive Export',
          text: 'Exported ${data.length} samples from MeshCore Wardrive',
        );
        
        _showSnackBar('Export shared');
      }
    } catch (e) {
      _showSnackBar('Export failed: $e');
    }
  }

  Future<void> _importData() async {
    try {
      // Pick a JSON file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.single.path == null) {
        return; // User cancelled
      }
      
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final List<dynamic> jsonData = jsonDecode(jsonString);
      
      // Import samples
      final importedCount = await _locationService.importSamples(
        jsonData.cast<Map<String, dynamic>>(),
      );
      
      // Reload map
      await _loadSamples();
      
      _showSnackBar('Imported $importedCount new samples');
    } catch (e) {
      _showSnackBar('Import failed: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
  
  void _toggleFollowLocation() {
    final newFollow = !_notifier.state.followLocation;
    _notifier.setFollowLocation(newFollow);

    if (newFollow) {
      // Center on current location when enabling follow
      final pos = _notifier.state.currentPosition;
      if (pos != null) {
        _mapController.move(pos, _mapController.camera.zoom);
      }
      _showSnackBar('Auto-follow enabled');
    } else {
      _showSnackBar('Auto-follow disabled');
    }
  }
  
  void _resetMapRotation() {
    _mapController.rotate(0); // 0 degrees = north up
    _showSnackBar('Map reset to north');
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _batterySubscription?.cancel();
    _positionSubscription?.cancel();
    _sampleSavedSubscription?.cancel();
    _pingEventSubscription?.cancel();
    _geofenceStatusSubscription?.cancel();
    _sonarService.dispose();
    _locationService.dispose();
    _notifier.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('MeshCore Wardrive'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.crop_square,
              color: _activeGeofence != null ? Colors.orange : null,
            ),
            tooltip: 'Collection Geofence',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => GeofenceScreen(
                    locationService: _locationService,
                    settingsService: _settingsService,
                  ),
                ),
              );
              if (changed == true) {
                final fence = await _settingsService.getGeofence();
                setState(() => _activeGeofence = fence);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(chatService: _chatService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.terminal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugLogScreen()),
              );
            },
            tooltip: 'Debug Terminal',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showMapSettingsSheet(
              context,
              _notifier,
              _settingsService,
              _locationService,
              showSnackBar: _showSnackBar,
              onExportData: _exportData,
              onImportData: _importData,
              onConfigureUploadUrl: _configureUploadUrl,
              onLoadSamples: _loadSamples,
              onScanForRepeaters: _scanForRepeaters,
              onRefreshContacts: _refreshContacts,
              sonarPingEnabled: _sonarService.enabled,
              sonarPingInterval: _sonarService.intervalSeconds,
              onSonarEnabledChanged: (v) async {
                _sonarService.setEnabled(v);
                await _settingsService.setSonarPingEnabled(v);
              },
              onSonarIntervalChanged: (v) async {
                _sonarService.setInterval(v);
                await _settingsService.setSonarPingInterval(v);
              },
              onMaxEdgeResponsesChanged: (v) async {
                _notifier.setMaxEdgeResponses(v);
                await _settingsService.setMaxEdgeResponses(v);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          MapControlPanel(
            state: _notifier.state,
            onConnect: _showConnectionDialog,
            onDisconnect: _disconnectLoRa,
            onManualPing: _manualPing,
            onUpload: _uploadSamples,
            onClearData: _clearData,
          ),
          if (_outsideGeofence)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.not_listed_location, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Outside geofence — logging paused',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'compass',
            mini: true,
            onPressed: _resetMapRotation,
            child: const Icon(Icons.navigation),
            tooltip: 'Reset to North',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'location',
            mini: true,
            onPressed: _toggleFollowLocation,
            backgroundColor: _notifier.state.followLocation ? Colors.blue : null,
            child: Icon(
              _notifier.state.followLocation ? Icons.gps_fixed : Icons.gps_not_fixed,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'tracking',
            onPressed: _toggleTracking,
            backgroundColor: _notifier.state.isTracking ? Colors.red : Colors.green,
            child: Icon(_notifier.state.isTracking ? Icons.stop : Icons.play_arrow),
          ),
        ],
      ),
    ),  // end Scaffold (body of ListenableBuilder.builder)
  );   // end ListenableBuilder
  }   // end build

  Widget _buildMap() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _notifier.state.currentPosition ?? GeohashUtils.centerPos,
        initialZoom: kDefaultMapZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        interactionOptions: InteractionOptions(
          flags: _notifier.state.lockRotationNorth 
              ? InteractiveFlag.all & ~InteractiveFlag.rotate  // Disable rotation
              : InteractiveFlag.all,  // Allow all interactions
        ),
        onMapEvent: (event) {
          // Disable follow mode if user manually pans/drags the map
          if (event is MapEventMoveStart && event.source == MapEventSource.mapController) {
            // Ignore programmatic moves (from auto-follow)
            return;
          }
          if (event is MapEventMoveStart && _notifier.state.followLocation) {
            _notifier.setFollowLocation(false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: isDarkMode
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: isDarkMode ? const ['a', 'b', 'c', 'd'] : const [],
          userAgentPackageName: 'com.meshcore.wardrive',
        ),
        if (_notifier.state.displaySettings.showCoverage && _notifier.state.aggregationResult != null)
          ...buildCoverageLayers(
            _notifier.state.aggregationResult!,
            _notifier.state.displaySettings.colorMode,
            (cov) => showCoverageInfoDialog(context, cov),
          ),
        if (_notifier.state.displaySettings.showSamples)
          buildSampleLayer(
            _notifier.state.filteredSamples,
            (s) => _showSampleInfo(s),
          ),
        if (_notifier.state.displaySettings.showEdges && _notifier.state.aggregationResult != null)
          buildEdgeLayer(
            _notifier.state.aggregationResult!,
            maxEdgeResponses: _notifier.state.displaySettings.maxEdgeResponses,
          ),
        if (_notifier.state.displaySettings.showRepeaters)
          buildRepeaterLayer(
            _notifier.state.repeaters,
            (r) => showRepeaterInfoDialog(context, r, _mapController),
          ),
        if (_notifier.state.currentPosition != null)
          buildCurrentLocationLayer(
            _notifier.state.currentPosition!,
            _notifier.state.showPingPulse,
          ),
        if (_activeGeofence != null)
          PolygonLayer(polygons: [
            Polygon(
              points: [
                LatLng(_activeGeofence!['north']!, _activeGeofence!['west']!),
                LatLng(_activeGeofence!['north']!, _activeGeofence!['east']!),
                LatLng(_activeGeofence!['south']!, _activeGeofence!['east']!),
                LatLng(_activeGeofence!['south']!, _activeGeofence!['west']!),
              ],
              color: Colors.orange.withValues(alpha: 0.08),
              borderColor: Colors.orange.withValues(alpha: 0.6),
              borderStrokeWidth: 1.5,
              isFilled: true,
            ),
          ]),
      ],
    );
  }

  Future<void> _manualPing() async {
    if (!_notifier.state.loraConnected) {
      _showSnackBar('Connect LoRa device first');
      return;
    }

    if (_notifier.state.currentPosition == null) {
      _showSnackBar('Waiting for GPS location...');
      return;
    }

    _showSnackBar('Sending ping...');

    // Send ping via LoRa companion
    final result = await _locationService.loraCompanion.ping(
      latitude: _notifier.state.currentPosition!.latitude,
      longitude: _notifier.state.currentPosition!.longitude,
    );

    // Create and save sample
    final geohash = GeohashUtils.sampleKey(
      _notifier.state.currentPosition!.latitude,
      _notifier.state.currentPosition!.longitude,
    );
    
    final sample = Sample(
      id: '${DateTime.now().millisecondsSinceEpoch}_$geohash',
      position: _notifier.state.currentPosition!,
      timestamp: DateTime.now(),
      path: result.nodeId, // Save repeater/node ID
      geohash: geohash,
      rssi: result.rssi,
      snr: result.snr,
      pingSuccess: result.status == PingStatus.success,
    );
    
    await DatabaseService().insertSample(sample);

    // Reload samples to update map
    await _loadSamples();

    // Show result
    if (result.status == PingStatus.success) {
      _showSnackBar('✅ Ping heard by ${result.nodeId}');
    } else if (result.status == PingStatus.timeout) {
      _showSnackBar('❌ No response - dead zone');
    } else {
      _showSnackBar('❌ Ping failed: ${result.error}');
    }
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect LoRa Device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose connection method:', 
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _connectUsb();
              },
              icon: const Icon(Icons.usb),
              label: const Text('Scan USB Devices'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _connectBluetooth();
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text('Scan Bluetooth'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectUsb() async {
    try {
      final devices = await _locationService.loraCompanion.scanUsbDevices();
      
      if (!mounted) return;
      
      if (devices.isEmpty) {
        _showSnackBar('No USB devices found');
        return;
      }

      final selected = await showDialog<UsbDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select USB Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: devices.map((device) {
              return ListTile(
                title: Text(device.productName ?? 'USB Device'),
                subtitle: Text('VID: ${device.vid}, PID: ${device.pid}'),
                onTap: () => Navigator.pop(context, device),
              );
            }).toList(),
          ),
        ),
      );

      if (selected != null) {
        final connected = await _locationService.loraCompanion.connectUsb(selected);
        if (connected) {
          _showSnackBar('Connected via USB');
          await _loadSamples();
        } else {
          _showSnackBar('Failed to connect USB device');
        }
      }
    } catch (e) {
      _showSnackBar('USB error: $e');
    }
  }

  Future<void> _connectBluetooth() async {
    try {
      _showSnackBar('Scanning for Bluetooth devices...');
      final devices = await _locationService.loraCompanion.scanBluetoothDevices();
      
      if (!mounted) return;
      
      if (devices.isEmpty) {
        _showSnackBar('No LoRa devices found via Bluetooth');
        return;
      }

      final selected = await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Bluetooth Device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: devices.map((device) {
              return ListTile(
                title: Text(device.platformName),
                subtitle: Text(device.remoteId.toString()),
                onTap: () => Navigator.pop(context, device),
              );
            }).toList(),
          ),
        ),
      );

      if (selected != null) {
        _showSnackBar('Connecting to ${selected.platformName}...');
        
        final connected = await _locationService.loraCompanion.connectBluetooth(selected);
        if (connected) {
          _showSnackBar('Connected via Bluetooth!');
          await _loadSamples();
        } else {
          _showSnackBar('Failed to connect Bluetooth device');
        }
      }
    } catch (e) {
      _showSnackBar('Bluetooth error: $e');
    }
  }






  Future<void> _disconnectLoRa() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect LoRa Device'),
        content: const Text('Disconnect from your LoRa companion device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Disable auto-ping first
      if (_notifier.state.displaySettings.autoPingEnabled) {
        _locationService.disableAutoPing();
      }
      
      await _locationService.loraCompanion.disconnectDevice();
      await _loadSamples();
      _showSnackBar('LoRa device disconnected');
    }
  }
  
  
  Future<void> _refreshContacts() async {
    if (!_notifier.state.loraConnected) {
      _showSnackBar('Connect LoRa device first');
      return;
    }
    
    _showSnackBar('Refreshing contact list...');
    
    // Request full contact list from device
    await _locationService.loraCompanion.refreshContactList();
    
    // Give it a moment to process
    await Future.delayed(const Duration(seconds: 2));
    
    _showSnackBar('Contact list updated');
  }
  
  Future<void> _scanForRepeaters() async {
    if (!_notifier.state.loraConnected) {
      _showSnackBar('Connect LoRa device first');
      return;
    }
    
    _showSnackBar('Scanning for repeaters...');
    
    final repeaters = await _locationService.loraCompanion.scanForRepeaters();
    
    _notifier.updateFromSampleLoad(
      samples: _notifier.state.samples,
      sampleCount: _notifier.state.sampleCount,
      aggregationResult: _notifier.state.aggregationResult ?? AggregationService.buildIndexes([], []),
      loraConnected: _notifier.state.loraConnected,
      connectionType: _notifier.state.connectionType,
      autoPingEnabled: _notifier.state.displaySettings.autoPingEnabled,
      repeaters: repeaters,
    );
    
    if (repeaters.isEmpty) {
      _showSnackBar('No repeaters found');
    } else {
      _showSnackBar('Found ${repeaters.length} repeater(s)');
      _showRepeatersDialog();
    }
  }
  
  String? _getRepeaterName(String? repeaterId) {
    if (repeaterId == null) return null;
    
    // If it's a 2-char prefix, try to expand it first
    String? fullId = repeaterId;
    if (repeaterId.length == 2) {
      fullId = _locationService.loraCompanion.matchRepeaterPrefix(repeaterId);
      if (fullId == null) {
        // No match found, return the 2-char prefix as-is
        return repeaterId;
      }
    }
    
    // First check discovered repeaters list
    final repeater = _notifier.state.repeaters.firstWhere(
      (r) => r.id == fullId,
      orElse: () => Repeater(id: fullId!, position: const LatLng(0, 0), timestamp: DateTime.now()),
    );
    if (repeater.name != null) return repeater.name;
    
    // Fall back to checking LoRa service's contact cache
    final loraRepeater = _locationService.loraCompanion.getRepeaterLocation(fullId!);
    return loraRepeater?.name ?? fullId; // Return full ID if no name
  }
  
  void _showSampleInfo(Sample sample) {
    showSampleInfoDialog(context, sample, _getRepeaterName);
  }
  
  void _showRepeatersDialog() {
    showRepeatersDialog(context, _notifier.state.repeaters, _mapController);
  }

  Future<void> _uploadSamples() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Uploading samples...'),
          ],
        ),
      ),
    );

    try {
      // Build repeater names map from discovered repeaters and LoRa service
      final repeaterNames = <String, String>{};
      
      // Add names from discovered repeaters
      for (final repeater in _notifier.state.repeaters) {
        if (repeater.name != null) {
          repeaterNames[repeater.id] = repeater.name!;
        }
      }
      
      // Add names from LoRa service contact cache
      final loraService = _locationService.loraCompanion;
      for (final contact in loraService.discoveredRepeaters) {
        if (contact.name != null && !repeaterNames.containsKey(contact.id)) {
          repeaterNames[contact.id] = contact.name!;
        }
      }
      
      final result = await _uploadService.uploadAllSamples(repeaterNames: repeaterNames);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'Upload Complete' : 'Upload Failed'),
            content: Text(result.success ? 'Upload Complete' : result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Upload error: $e');
      }
    }
  }

  /// Shows the upload settings dialog.
  /// When [required] is true, Cancel is hidden and Save is only enabled
  /// after a successful token validation — used on first-run / invalid token.
  Future<void> _configureUploadUrl() async {
    await showUploadSettingsDialog(
      context,
      _uploadService,
      showSnackBar: _showSnackBar,
    );
  }
  
}
