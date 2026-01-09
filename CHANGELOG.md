# Changelog

All notable changes to MeshCore Wardrive will be documented in this file.

## [1.0.2] - 2026-01-09

### Fixed
- Settings menu now properly accounts for system navigation bar padding
- Bottom sheet no longer hidden behind on-screen navigation buttons (back/home/recent apps)
- Improved compatibility with devices using gesture navigation vs button navigation

## [1.0.1] - 2026-01-09

### Fixed
- Background GPS tracking now works reliably on modern Android devices (Pixel 8, Samsung S24, etc.)
- Map updates in real-time during tracking instead of waiting up to 5 seconds
- Auto-ping no longer blocks location updates - tracking continues smoothly while pings are in progress
- Debug terminal now automatically scrolls to latest logs when opened
- Web map repeater display now only shows when pings were actually received
- Filtered out "Unknown" nodes from web map repeater lists (no more "UN" prefix)

### Added
- Foreground service with persistent notification during tracking
- Notification shows "MeshCore Wardrive - Location tracking active" with stop button
- Notification permission request for Android 13+ devices
- Real-time sample saved event system for instant UI updates
- Non-blocking ping architecture for better performance

### Changed
- Grid precision changed from 7 (153m x 153m) to 6 (~1.2km x 610m) for better walking coverage
- Web map grid precision synced with Android app
- Disabled infinite horizontal scrolling on web map

### Technical
- Added `flutter_foreground_task` package
- Implemented sample saved event stream
- Added POST_NOTIFICATIONS permission
- Improved location service architecture

## [1.0.0] - 2026-01-08

### Added
- Initial release
- GPS tracking with background support via wakelock
- USB and Bluetooth connectivity for MeshCore companion radios
- Auto-ping functionality with configurable intervals (50m, 200m, 0.5 miles, 1 mile)
- Manual ping testing
- Success rate based coverage visualization with color coding
- Repeater discovery and tracking
- Data export to JSON
- Web map upload functionality
- Debug terminal with logging
- Light/Dark theme support
- #meshwar channel discovery and validation

### Features
- Real-time location tracking
- Coverage grid visualization
- Repeater connection display
- Battery status monitoring for connected devices
- Sample count and statistics
- Map controls (show/hide samples, edges, repeaters)
