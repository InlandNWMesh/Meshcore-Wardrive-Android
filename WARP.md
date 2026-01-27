# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview
MeshCore Wardrive is a Flutter Android application for mapping MeshCore mesh network coverage in real-time. It tracks GPS location, sends ping requests via LoRa companion devices (USB/Bluetooth), listens for observer responses via MQTT, and visualizes coverage on an interactive map.

**Version**: 1.0.17  
**Minimum Android**: API 21 (Android 5.0)  
**Flutter SDK**: 3.10.0+

## Common Commands

### Development
```bash
# Get dependencies
flutter pub get

# Run on connected device (development mode)
flutter run

# Run tests
flutter test

# Analyze code for issues
flutter analyze

# Generate app icons (after changing icon image)
flutter pub run flutter_launcher_icons
```

### Building
```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Installation
```bash
# Install on connected device
flutter install
```

## Architecture

### High-Level Data Flow
```
GPS → LocationService → DatabaseService (SQLite)
                    ↓
      Manual/Auto ping trigger
                    ↓
LoRaCompanionService (USB/Bluetooth) → Physical LoRa device
                    ↓
        LoRa broadcast to mesh
                    ↓
Observers hear ping → Publish to MQTT broker
                    ↓
    MQTT listener (in LoRaCompanionService)
                    ↓
Correlate response with GPS sample → Update pingSuccess
                    ↓
AggregationService → Coverage grid calculation
                    ↓
        MapScreen (visualization)
```

### Core Service Architecture

**LocationService** (`lib/services/location_service.dart`)
- Manages GPS tracking with foreground service
- Coordinates auto-ping based on distance intervals
- Saves samples to database with ping results
- Broadcasts position updates and ping events

**LoRaCompanionService** (`lib/services/lora_companion_service.dart`)
- Handles USB/Bluetooth connections to LoRa devices
- Implements MeshCore binary protocol (see `meshcore_protocol.dart`)
- Sends ping commands to physical LoRa radio
- Listens to MQTT for observer responses
- Correlates ping IDs with responses to determine success/failure
- Tracks discovered repeaters during wardriving

**DatabaseService** (`lib/services/database_service.dart`)
- SQLite database for persisting GPS samples
- Schema includes: position, timestamp, geohash, rssi, snr, pingSuccess
- Indexes on geohash and timestamp for query performance

**AggregationService** (`lib/services/aggregation_service.dart`)
- Aggregates GPS samples into coverage grid squares (geohash-based)
- Implements time-weighted scoring: newer samples get higher weight
- Handles contradiction detection: recent samples override old ones
- Calculates success rate (received/lost) per coverage area
- Generates color coding based on success rate or age

**MeshCoreProtocol** (`lib/services/meshcore_protocol.dart`)
- Binary protocol parser for companion radio communication
- Supports USB mode (framed with `>` + length) and BLE mode (unwrapped)
- Handles commands: send ping, get contacts, scan repeaters, etc.
- Parses responses: contact info, advertisements, battery status

### Data Models

**Sample** (`lib/models/models.dart`)
- Individual GPS point with optional ping data
- Fields: id, position (LatLng), timestamp, geohash, rssi, snr, pingSuccess
- pingSuccess: true (observer heard), false (dead zone), null (GPS-only)

**Coverage** (`lib/models/models.dart`)
- Aggregated coverage area (geohash square)
- Tracks received (weighted successful pings) and lost (weighted failed pings)
- Contains list of repeater IDs that responded in this area

**Repeater** (`lib/models/models.dart`)
- Mesh network repeater/node information
- Fields: id (public key prefix), position, elevation, name, rssi, snr

### Geohash System

Configurable precision for coverage grid (`lib/utils/geohash_utils.dart`):
- Precision 4: ~20km × 20km (regional)
- Precision 5: ~5km × 5km (city)
- Precision 6: ~1.2km × 610m (default, neighborhood)
- Precision 7: ~153m × 153m (street-level)
- Precision 8: ~38m × 19m (building-level)

Default coverage precision is 6. Users can adjust in settings.

## Key Configuration Points

### Ping Interval
Default: 805 meters (0.5 miles). Adjustable in app settings or `LocationService._pingIntervalMeters`.

### Ping Timeout
Default: 20 seconds. Located in `LocationService._handleAutoPing()` → `loraCompanion.ping(timeoutSeconds: 20)`.

### MQTT Settings
Default broker: `mqtt.meshcore.io`. Configurable in `LoRaCompanionService` (supports custom brokers).

### Coverage Grid Precision
Default: 6. Adjustable in app settings, affects map visualization granularity.

## Authentication & Security

**MeshCore MQTT Authentication** (see `MESHCORE_AUTH_SETUP.md`):
- Uses Ed25519 signature-based authentication
- Public/private key pair stored securely on device (`flutter_secure_storage`)
- JWT token generation with signed payloads
- Username format: `v1_{PUBLIC_KEY_HEX}`

**Encryption**: Uses `pointycastle` package for Ed25519 cryptography.

## Testing Strategy

Minimal test coverage currently exists. When adding tests:
- Use `flutter test` to run
- Test files in `test/` directory
- Mock LoRa/MQTT connections for unit tests
- Consider integration tests with simulated MQTT broker

## Important Implementation Details

### Auto-Ping Logic
Auto-ping only triggers when:
1. GPS tracking is active
2. Auto-ping toggle is enabled
3. LoRa device is connected (USB or Bluetooth)
4. Sufficient distance traveled since last ping

### Ping Correlation
Each ping has a unique 8-character ID. When LoRa device broadcasts, observers respond via MQTT with the ping ID. The app correlates MQTT messages containing the ping ID to mark the sample as successful.

### Weighted Coverage
The aggregation system uses time-based weighting:
- Recent samples (< 1 day): full weight (1.0)
- Week-old samples: 0.8 weight
- Month-old samples: 0.5 weight
- Older samples: 0.2 weight

Contradictions: If newer samples show opposite results (e.g., dead zone vs covered), older samples are reduced to 0.1 weight.

### Foreground Service
Required for background GPS tracking on Android 8+. Displays persistent notification when tracking is active. Uses `flutter_foreground_task` package.

### USB vs Bluetooth
- **USB**: Preferred, more stable, less battery drain. Requires OTG cable and data-capable USB cable.
- **Bluetooth**: More convenient but higher latency. Device must be paired in Android settings first.

## Protocol Specifics

### Binary Protocol Frame Structure (USB)
```
'<' (start marker) | 2-byte length (LE) | command code | payload
```

### BLE Protocol
Unwrapped frames sent directly via UART characteristic (no start marker or length prefix).

### Ping Command Format
```
CMD_SEND_CONTROL_DATA (55) + subtype DISCOVER_REQ (0x8) + 8-char ping ID
```

### Expected MQTT Response
Topic: `meshcore/{IATA}/{OBSERVER_KEY}/packets`  
Payload should contain the ping ID and optionally rssi, snr, observer position.

## Development Workflow

1. **Make code changes** in `lib/`
2. **Test on device**: `flutter run` (hot reload enabled)
3. **Verify no issues**: `flutter analyze`
4. **Run tests**: `flutter test`
5. **Build release**: `flutter build apk --release` when ready

## Common Issues & Debugging

### Location Not Updating
- Check location permissions: "Allow all the time" required for background tracking
- Verify GPS is enabled on device
- Check foreground service is running (notification visible)

### LoRa Device Won't Connect
- USB: Verify cable is data-capable, not charge-only
- Bluetooth: Ensure device is paired in Android settings first
- Check device name matches expected patterns (contains "lora", "meshtastic", etc.)

### No Observer Responses
- Verify MQTT broker connection is active
- Check LoRa device is actually transmitting (view in debug logs)
- Confirm you're in range of active observers
- Validate MQTT topic subscription pattern matches observer publish topics

### False Positives from Mobile Repeater
- Set "Ignore Repeater Prefix" in settings to filter out your own portable repeater

## File Structure Notes

```
lib/
├── main.dart                   # App entry, theme configuration
├── models/
│   └── models.dart             # Data classes (Sample, Coverage, Repeater, Edge)
├── screens/
│   ├── map_screen.dart         # Main UI with map, controls, settings
│   ├── debug_log_screen.dart   # Debug terminal for logs
│   └── debug_diagnostics_screen.dart  # Advanced diagnostics
├── services/
│   ├── location_service.dart           # GPS tracking & auto-ping orchestration
│   ├── lora_companion_service.dart     # LoRa device communication & MQTT
│   ├── meshcore_protocol.dart          # Binary protocol parser
│   ├── database_service.dart           # SQLite persistence
│   ├── aggregation_service.dart        # Coverage calculation engine
│   ├── upload_service.dart             # Web map upload (future feature)
│   ├── settings_service.dart           # User preferences
│   ├── debug_log_service.dart          # Debug logging
│   └── persistent_debug_logger.dart    # Persistent log storage
└── utils/
    └── geohash_utils.dart      # Geohash encoding/decoding utilities
```

## Dependencies of Note

- **flutter_map**: Interactive map display (OpenStreetMap tiles)
- **geolocator**: GPS positioning
- **flutter_foreground_task**: Background location service
- **usb_serial**: USB connection to LoRa devices
- **flutter_blue_plus**: Bluetooth Low Energy communication
- **sqflite**: Local SQLite database
- **geohash_plus**: Geohash encoding/decoding
- **pointycastle**: Cryptography (Ed25519 signatures)
- **http**: MQTT over WebSocket (may use mqtt_client in future)

## Code Style & Conventions

- Follow standard Dart/Flutter conventions
- Use `analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`)
- Prefix private fields/methods with underscore (`_`)
- Use broadcast streams for multi-subscriber event propagation
- Prefer async/await over raw Futures
- Use `setState()` for UI updates in StatefulWidgets
- Store persistent data in SQLite, transient settings in SharedPreferences
- Secure credentials in FlutterSecureStorage

## Related Documentation

- `README.md`: User-facing setup and features
- `QUICKSTART.md`: First-time user guide
- `LORA_COMPANION_GUIDE.md`: Detailed LoRa device setup and MQTT configuration
- `MESHCORE_AUTH_SETUP.md`: Ed25519 authentication for MQTT broker
- `CHANGELOG.md`: Version history
