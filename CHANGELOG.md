# Changelog

All notable changes to MeshCore Wardrive will be documented in this file.

## [1.0.16] - 2026-01-17

### Fixed
- **CRITICAL: #meshwar channel discovery now searches all 40 channels instead of only 0-7**
  - LoRa companion devices support up to 40 channels (0-39)
  - Previously app would fail to connect if #meshwar was on channels 8-39
  - Extended discovery timeout from 3 seconds to 6 seconds to handle more channels
  - Fixes "#meshwar Not Found" error for users with channel on higher slots

### Technical
- Increased channel query loop from `i <= 7` to `i <= 39`
- Updated channel discovery timeout from 3s to 6s
- Updated empty slot search range from 1-7 to 1-39
- Updated channels queried check from `>= 8` to `>= 40`

## [1.0.15] - 2026-01-16

### Added
- **"Show Coverage Boxes" toggle in settings**
  - New toggle to show/hide coverage squares on the map
  - Helps declutter the map when you only want to see sample points
  - Located in Settings → Show Coverage Boxes
  - Setting persists between app sessions
- **Smaller sample markers for cleaner map display**
  - Reduced sample marker size by 25% (from 16px to 12px)
  - Sample dots are now less intrusive while remaining visible and tappable
  - Makes it easier to see the underlying map and coverage patterns
- **Repeater friendly names on web map**
  - App now uploads repeater friendly names (e.g., "Bob's Repeater") alongside node IDs
  - Web map displays custom repeater names instead of just prefixes
  - Names pulled from discovered repeaters and LoRa service contact cache
  - Makes it easier to identify specific repeaters in coverage data

### Fixed
- **Web map resolution reset** - Fixed coverage square size resetting to default every 30 seconds during auto-refresh
- **Web map repeater name escaping** - Fixed single quotes in repeater names breaking onclick handlers

### Technical
- Added `_showCoverage` state variable with default value `true`
- Added `getShowCoverage()` and `setShowCoverage()` methods to SettingsService
- Coverage layers now conditionally render based on toggle state
- Sample marker dimensions reduced from 16x16px to 12x12px (outer) and 8x8px to 6x6px (inner circle)
- Upload service builds repeater names map from discovered repeaters and LoRa contact cache
- Backend uses `sample.repeaterName` field if available, falls back to `nodeId`
- Web map preserves user's selected resolution during auto-refresh

## [1.0.14] - 2026-01-16

### Fixed
- **CRITICAL: Fixed repeater ID detection to correctly identify responding repeaters**
  - App now properly parses mesh network routing paths to extract actual repeater that echoed ping
  - Coverage squares and sample markers now display accurate repeater IDs
  - Fixes issue where incorrect node IDs were being recorded in wardrive data
  - Improves accuracy of repeater tracking and coverage mapping

### Technical
- Enhanced path parsing logic to identify correct repeater from mesh routing information
- Repeater ID extraction now validates against actual network topology
- Sample data now contains accurate repeater attribution for coverage analysis

## [1.0.13] - 2026-01-12

### Added
- **"Show GPS Samples" toggle in settings**
  - Toggle to show/hide blue GPS-only sample markers
  - Helps declutter map when you only want to see ping results
  - Located in Settings → Show GPS Samples
  - Subtitle explains "Show blue GPS-only markers"

### Technical
- Added SwitchListTile for GPS samples toggle in settings dialog
- Existing filter logic in `_buildSampleLayer()` now accessible via UI
- GPS-only samples (null pingSuccess) can be hidden with one tap

## [1.0.12] - 2026-01-12

### Fixed
- **CRITICAL: Fixed sample data overwriting bug**
  - Sample IDs now use timestamp + random number instead of timestamp + geohash
  - Prevents samples at same location from having identical IDs and overwriting each other
  - Database changed from REPLACE to IGNORE conflict algorithm to accumulate all samples
  - Fixes issue where uploaded data appeared to replace existing webmap data
- **Fixed coverage display showing floating point errors**
  - Weighted values now rounded to 1 decimal place (1.2 instead of 1.2000000000000002)
  - Received/Lost values on separate lines to prevent text overflow
- **Map now centers on user's location on startup**
  - Fixes issue where map always loaded at Seattle/default location
  - Map automatically moves to GPS position when app opens

### Added
- **Color-coded sample markers**
  - Green dots = Successful pings
  - Red dots = Failed pings
  - Blue dots = GPS-only samples (no ping attempt)
  - Makes it easy to visually identify coverage at a glance

### Technical
- Added `_generateUniqueId()` function with random component
- Changed `ConflictAlgorithm.replace` to `ConflictAlgorithm.ignore` in database
- Added `_showGpsSamples` toggle for future GPS sample filtering
- Coverage info dialog uses `toStringAsFixed(1)` and Flexible widgets
- Map controller automatically moves to user position after `getCurrentLocation()`

## [1.0.11] - 2026-01-11

### Added
- **Clickable Sample Markers** - Tap any sample dot on the map to view details
  - Shows ping status (Success/Failed/GPS Only)
  - Displays timestamp when sample was collected
  - Shows latitude/longitude coordinates
  - Displays repeater ID that heard the ping
  - Shows RSSI (signal strength) and SNR (signal quality) values
  - Matches webmap functionality with additional signal metrics

### Fixed
- **CRITICAL: Fixed RSSI/SNR values showing as null in ping results**
  - 0x88 frames are raw radio log frames (PUSH_CODE_LOG_RX_DATA), not channel echoes
  - SNR and RSSI now correctly extracted from bytes 0-1 of frame payload
  - SNR value automatically descaled from firmware's 4x multiplier
  - RSSI properly converted from signed byte value
  - Ping results now show accurate signal strength and quality metrics

### Technical
- Added `parseRawLogFrame()` function to handle 0x88 frame format: [SNR][RSSI][raw_packet...]
- Modified frame handler to use new parser instead of `parseChannelMessageFrame()` for 0x88
- SNR extracted from byte 0, divided by 4 to get actual value
- RSSI extracted from byte 1, converted from unsigned to signed byte
- Parser also extracts sender/repeater info from raw packet data when available
- Added `_showSampleInfo()` dialog with GestureDetector on sample markers
- Sample markers expanded to 16x16px tap targets with 8x8px visible circles

## [1.0.10] - 2026-01-11

### Added
- **Configurable Coverage Resolution** - Dynamically adjust coverage square size
  - 5 precision levels: Regional (~20km), City (~5km), Neighborhood (~1.2km), Street (~153m), Building (~38m)
  - Samples stored at high precision (38m), re-aggregated on-the-fly based on user preference
  - Accessible via Settings → Coverage Resolution
  - Allows drivers to see regional trends and walkers to map precise street-level coverage
- **Smart Sample Weighting System** - Intelligently handles conflicting coverage data
  - Newer samples receive higher weight than older samples
  - Old samples contradicted by 2+ newer samples are heavily discounted (10% weight)
  - Samples that agree with newer data maintain full weight
  - Time-based decay: Fresh (100%), 1-day (80%), 1-week (50%), 30+ days (20%)
  - Dead zones can become green if new data shows coverage, and vice versa

### Changed
- Coverage model now uses weighted fractional counts (double) instead of integer counts
- Aggregation service groups samples by coverage area before processing
- Success rate calculations now factor in sample age and contradictions

### Technical
- Modified `GeohashUtils.coverageKey()` to accept precision parameter (4-8)
- Updated `AggregationService.buildIndexes()` with coveragePrecision parameter
- Coverage.received and Coverage.lost changed from int to double
- Added contradiction detection algorithm comparing samples in same coverage area

## [1.0.9] - 2026-01-11

### Added
- **Auto-follow GPS location button** - Map automatically centers and follows your position
  - Toggle on/off with GPS button (above play/stop button)
  - Shows `gps_fixed` icon (blue background) when active
  - Shows `gps_not_fixed` icon (gray) when inactive
  - Automatically disables when you manually pan/drag the map
  - Toast notifications show when enabled/disabled

### Technical
- Added `_followLocation` state variable
- Map controller automatically moves to GPS position on location updates when enabled
- `onMapEvent` handler detects manual map panning and disables auto-follow
- Replaced `my_location` button with toggle-able GPS follow button

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
