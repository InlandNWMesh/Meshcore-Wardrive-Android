# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run app (with hot reload)
flutter run

# Lint / static analysis
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Regenerate app icons (after changing assets/icon/)
flutter pub run flutter_launcher_icons
```

## Architecture Overview

**MeshCore Wardrive** is a Flutter/Dart Android app that wardrives LoRa mesh networks. It sends pings via a companion LoRa radio (USB serial or BLE), listens for observer responses via MQTT, and renders coverage as color-coded geohash grid squares on an OpenStreetMap.

### Data Flow

```
GPS → LocationService → auto-ping trigger
                              ↓
LoRaCompanionService → USB/BT device → LoRa broadcast (DISCOVER_REQ)
                              ↓
Observer nodes hear ping → publish to MQTT broker
                              ↓
App receives MQTT response → correlates ping ID → marks Sample.pingSuccess
                              ↓
AggregationService → groups Samples by geohash → Coverage squares
                              ↓
MapScreen renders colored squares on flutter_map (OpenStreetMap)
```

### Key Services (`lib/services/`)

| Service | Responsibility |
|---------|---------------|
| `location_service.dart` | GPS tracking, auto-ping on distance intervals, foreground service (Android 8+), wakelock |
| `lora_companion_service.dart` | USB serial + BLE device connections, MeshCore binary protocol, MQTT subscription, ping correlation |
| `meshcore_protocol.dart` | Binary frame parser — command/response/push codes, USB vs BLE framing |
| `database_service.dart` | SQLite (`meshcore_wardrive.db`) — samples table with geohash index |
| `aggregation_service.dart` | Groups samples into Coverage squares, time-weighted scoring, contradiction detection |
| `upload_service.dart` | Upload samples to community coverage map with client + server deduplication |
| `settings_service.dart` | `shared_preferences` — ping interval, coverage precision, color mode, theme |

### Core Models (`lib/models/models.dart`)

- **Sample** — single GPS point: `position`, `timestamp`, `geohash`, `rssi`, `snr`, `pingSuccess` (bool?)
- **Coverage** — aggregated geohash square: weighted `received`/`lost` counts, `repeaters` list
- **Repeater** — mesh node discovered during scan: `id` (public key prefix), `position`, `rssi`, `snr`
- **Edge** — line from coverage square to repeater that responded (rendered purple on map)

### Ping System

- Command: `DISCOVER_REQ` (switched from legacy `#meshwar` channel messages in v1.0.19)
- Each ping gets an 8-character unique ID; MQTT responses include this ID for correlation
- 20-second timeout window to mark a sample success/fail
- Auto-ping fires when the user has traveled the configured distance (default 50m)

### Coverage Visualization

- Geohash precision 6 (default) ≈ 1.2km × 610m squares
- **Quality color mode:** green (≥80% success) → yellow-green → yellow → orange → red (<10%)
- **Age color mode:** green (recent data) → red (old data)
- Time-weighted scoring: newer samples count more; contradicted samples get 0.1× weight

### MQTT Authentication

Ed25519 key pairs stored in `FlutterSecureStorage`. Username format: `v1_{PUBLIC_KEY_HEX}`. See `MESHCORE_AUTH_SETUP.md` for setup details.

### Background Operation

Requires Android foreground service (`flutter_foreground_task`) with persistent notification. Users must disable battery optimization for the app to sustain background GPS.

### State Management

`MapStateNotifier` (`lib/state/map_state_notifier.dart`) is a `ValueNotifier<MapState>` that holds all map-related runtime state: tracking on/off, sample list, aggregation result, LoRa connection status, battery, follow-location, and rotation lock. `MapScreen` listens to it via `ValueListenableBuilder`. Map display options (color mode, precision, filter) live in `MapDisplaySettings` (`lib/models/map_display_settings.dart`).

### Screen & Widget Structure

- `lib/screens/map_screen.dart` — main screen; owns all services and the `MapStateNotifier`
- `lib/widgets/map_layers.dart` — renders coverage squares, edges, repeater markers, and ping pulse on the map
- `lib/widgets/map_control_panel.dart` — floating HUD buttons (track, ping, follow, north-lock)
- `lib/screens/map_settings_sheet.dart` — bottom sheet for display/filter settings
- `lib/screens/geofence_screen.dart` — drag-corner rectangle geofence editor (bounding box stored via `SettingsService.getGeofence()`/`saveGeofence()`)
- `lib/screens/channel_manager_screen.dart` — MeshCore channel configuration
- `lib/screens/chat_screen.dart` — in-app chat over MeshCore; backed by `ChatService`
- `lib/screens/debug_log_screen.dart` / `debug_diagnostics_screen.dart` — dev/debug tooling

### Chat & Diagnostics

- `ChatService` (`lib/services/chat_service.dart`) — sends/receives MeshCore chat messages; separate from the ping flow
- `PersistentDebugLogger` (`lib/services/persistent_debug_logger.dart`) + `DebugLogService` — write structured debug logs to disk; accessible from `DebugLogScreen`

## Important Files for Common Tasks

- Adding a new ping command: `lib/services/meshcore_protocol.dart` (protocol codes) + `lib/services/lora_companion_service.dart` (send/receive logic)
- Changing coverage colors or scoring: `lib/services/aggregation_service.dart`
- Map UI changes: `lib/screens/map_screen.dart`, `lib/widgets/map_layers.dart`
- Map runtime state: `lib/state/map_state_notifier.dart`
- New settings: `lib/services/settings_service.dart` + `SharedPreferences` key
- Geofence logic: `lib/screens/geofence_screen.dart` + `lib/services/settings_service.dart` (`getGeofence`/`saveGeofence`)
- Database schema changes: `lib/services/database_service.dart` — increment version and add migration
- App version: `lib/constants/app_version.dart` + `pubspec.yaml` — both must be updated together on each release

## Tests

The test suite (`test/`) is currently minimal (widget smoke test only). There are no unit tests for services or models yet.
