# Changelog

All notable changes to MeshCore Wardrive will be documented in this file.

## [1.0.8] - 2026-01-11

### Fixed
- **CRITICAL: Removed Seattle-area geofence that was blocking auto-ping for all users outside 60-mile radius**
  - Auto-ping now works globally, anywhere on Earth
  - Fixes issue where auto-ping appeared enabled but never triggered for users outside Seattle area
  - This was the root cause of Samsung Galaxy Fold 6/7 users reporting non-functioning auto-ping

### Technical
- Removed hardcoded distance check from `GeohashUtils.isValidLocation()`
- Location validation now only checks basic latitude/longitude bounds (-90 to 90, -180 to 180)
- App now supports worldwide coverage collection

## [1.0.7] - 2026-01-10

### Added
- Clickable coverage squares showing detailed information
- Coverage info popup displays:
  - Total samples collected in square
  - Success rate percentage
  - Received vs lost ping counts
  - Number of repeaters heard
  - Repeater ID prefixes (first 2 characters)
- Same information as webmap coverage squares
- Draggable scrollable settings menu (swipe up/down)

### Fixed
- Settings menu no longer overlaps top bar or navigation buttons
- Repeater IDs now properly tracked from actual ping responses
- Coverage squares show IDs of repeaters that actually echoed pings

### Technical
- Added invisible tap markers at coverage square centers
- Implemented coverage info dialog matching webmap functionality
- Track repeater IDs from sample.path (node that echoed)
- Wrapped settings in DraggableScrollableSheet with SafeArea

## [1.0.6] - 2026-01-10

### Changed
- Reduced ping timeout from 30 seconds to 20 seconds for faster response detection
- Improved ping reliability matching MeshCore app behavior

### Technical
- Optimized ping wait time to match typical mesh network response times

## [1.0.5] - 2026-01-09

### Fixed
- Coverage squares now populate correctly when auto-ping is enabled
- Fixed duplicate GPS sample saving that was preventing coverage squares from showing
- When auto-ping is active, only the ping result is saved (not the intermediate GPS sample)

### Technical
- Removed redundant sample saving in location_service.dart when auto-ping triggers
- GPS samples are now only saved when auto-ping is disabled or between ping intervals

## [1.0.4] - 2026-01-09

### Changed
- Increased map zoom out range from level 8 to level 3
- Allows viewing entire regions and multiple states at once

## [1.0.3] - 2026-01-09

### Added
- Auto-ping visual feedback with orange pulse animation on map
- Persistent notification updates during auto-ping:
  - Shows "Pinging..." when ping starts
  - Shows "✅ Heard by [node]" on success
  - Shows "❌ No response" on failure
  - Returns to "Location tracking active" after 3 seconds
- Check for Updates feature in settings
  - Queries GitHub API for latest release
  - Shows update available dialog when new version exists
  - Direct download link to GitHub releases
- View on GitHub link in settings
- "About" section in settings menu
- Increased map zoom out range (minZoom: 3.0) for better overview

### Technical
- Added `url_launcher` package for opening external links
- Implemented ping event stream for real-time UI feedback
- Added foreground service notification updates

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
