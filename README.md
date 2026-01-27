# MeshCore Wardrive

A Flutter-based Android application for mapping MeshCore mesh network coverage in real-time.

## 📥 Downloads

**Latest Release APK:** Available in the [releases](releases/) folder

**Source Code:** [Meshcore-Wardrive-Android-Source](https://github.com/mintylinux/Meshcore-Wardrive-Android-Source)

## 🚀 Quick Start

1. **Download the APK** from the releases folder
2. **Enable "Install from Unknown Sources"** in your Android settings
3. **Install the APK** on your device
4. **Connect your LoRa device** via USB or Bluetooth
5. **Start wardriving!**

## ✨ Features

### Mobile App
- **Real-time GPS Tracking** - Background support with screen-lock capability
- **LoRa Device Support** - Connect via USB or Bluetooth to MeshCore companion radios
- **Auto-Ping Mode** - Configurable intervals from 50 meters to 1 mile
- **Manual Ping** - Test coverage at specific locations
- **Success Rate Visualization** - Color-coded coverage map:
  - 🟢 **Green (≥80%)**: Very reliable coverage
  - 🟢 **Yellow-Green (50-80%)**: Usually works
  - 🟡 **Yellow (30-50%)**: Spotty coverage
  - 🟠 **Orange (10-30%)**: Rarely works
  - 🔴 **Red (<10%)**: Dead zone
- **Repeater Discovery** - See which repeaters are in range
- **Data Export** - Save and share your wardrive data
- **Web Map Upload** - Contribute to community coverage map

### Web Map
View the live community coverage map at: **https://meshwar-map.pages.dev**

- Interactive coverage visualization
- Success rate analytics per grid square
- Repeater tracking
- Real-time updates every 30 seconds

## 📋 Requirements

- Android device with GPS
- MeshCore companion radio device
- Access to #meshwar channel (shared via QR code)

## 🎯 How It Works

1. The app connects to your MeshCore companion radio
3. Repeaters that hear your ping respond with an echo
4. The app records which repeaters responded and their signal quality
5. Coverage is visualized as colored grid squares (~1.2km x 610m)
6. Data can be uploaded to the web map for community viewing

## 🔧 Configuration

### Adjustable Settings
- **Ping Interval**: 50m, 200m, 0.5 miles, or 1 mile
- **Ignore Mobile Repeater**: Filter out your own mobile repeater by prefix
- **Map Theme**: Light or dark mode
- **Color Mode**: Quality (signal strength) or Age (data freshness)

### Default Settings
- Ping interval: 0.5 miles (805 meters)
- Grid size: ~1.2km x 610m squares (precision 6)
- GPS accuracy: High
- Update frequency: Every 5 meters of movement

## 🎨 Understanding the Map

**Grid Squares** show coverage quality based on success rate:
- Multiple users' pings are aggregated per square
- Color shows: `successful pings / total pings`
- More samples = more accurate representation
- Gray squares = no ping data (GPS tracking only)

**Each square popup shows:**
- Number of samples collected
- Success rate percentage
- Received vs. lost pings
- Number of repeaters heard
- Repeater IDs (first 2 characters)

## 📖 Usage Tips

1. **Connect Device**: Use USB for most reliable connection
2. **Enable Tracking**: Press green play button to start GPS tracking
3. **Enable Auto-Ping**: Toggle the switch to auto-ping while driving
4. **Manual Testing**: Use manual ping button to test specific locations
5. **Upload Data**: Share your findings via Settings → Upload Data

## 🐛 Troubleshooting

**Location not updating?**
- Check GPS permissions are granted
- Enable "Location Always" for background tracking
- Press the manual location button to refresh

**Can't connect to device?**
- Check USB cable supports data transfer (not just charging)
- For Bluetooth: Make sure device is paired in Android settings first
- Try disconnecting and reconnecting

**Samsung Galaxy Fold GPS/Auto-Ping Issues?**
- Go to Settings → Debug → Debug Diagnostics
- Start tracking, reproduce the issue, then share the debug log
- Check Samsung battery optimization settings:
  - Set app to "Unrestricted" battery usage
  - Add to "Never sleeping apps" in Device Care
  - Disable "Put app to sleep" for this app
  - Use "Allow all the time" location permission (not just "While using")
  
**No repeater responses?**
- Verify you're in an area with repeater coverage
- Check LoRa device is connected (icon in app)
- Try manual ping to test connection

## 📊 Statistics

The top panel shows:
- **Total Samples**: Number of pings collected
- **Total Repeaters Heard**: Unique repeaters across entire map
- **Last Update**: When data was last refreshed

## 🔐 Privacy

- GPS data is only stored locally on your device
- Only uploaded to web map when you explicitly choose to upload
- No personal information is collected or transmitted
- Repeater IDs are shortened to first 2 characters on web map

## 🤝 Contributing to Coverage

Help build the community coverage map:
1. Wardrive your local area
2. Open Settings → Upload Data
3. Your samples contribute to the global success rate statistics

The more users contribute, the more accurate the coverage map becomes!

## 📜 Version History

### v1.0.19 (2026-01-20)
**Data Upload Improvements:**
- 🧠 Client-side dedupe for your default map: app only uploads new samples once per device for your endpoint
- 🌐 Other endpoints (self-hosted maps) remain unrestricted; users can upload as often as they want
- 🪪 Each sample now includes a stable ID in uploads

**Server (map) changes:**
- 🔁 Server-side dedupe with 90‑day TTL per-sample ID to prevent re-uploads after reinstall
- 🧹 Continues to overwrite revisited coverage squares; old cells decay until replaced

### v1.0.18 (2026-01-19)
**Critical Fix:**
- 🐛 **FIXED: Discovery protocol now working** - Changed type_filter from raw enum value (0x02) to bitmask (0x04)
- 📡 Repeaters now respond to Discovery requests as intended
- 🔍 Fixed protocol implementation to match MeshCore firmware expectations
- ✨ Shortened repeater public key display in logs from 64 to 8 characters for readability

### v1.0.17 (2026-01-18)
**New Features:**
- 📱 **Portrait mode lock** - App stays in true north orientation, no longer rotates with device
- 🎮 **Unified tracking button** - Play button now starts both GPS tracking AND auto-ping together
- ✅ **Simplified upload message** - Success dialog now shows just "Upload Complete"

**Changes:**
- ❌ Removed auto-ping toggle switch - now controlled by tracking button
- 🚀 Auto-ping automatically starts when tracking starts (if LoRa device connected)
- 🛑 Both tracking and auto-ping stop together when pressing stop

### v1.0.16 (2026-01-17)
**Critical Fix:**
- 🔍 **FIXED: #meshwar channel discovery now searches all 40 channels**
- 📡 Previously only searched channels 0-7, missing #meshwar on higher channels
- ⏱️ Extended discovery timeout from 3s to 6s to accommodate more channels
- ✅ Fixes connection issues for users with #meshwar on channels 8-39

### v1.0.15 (2026-01-16)
**New Features:**
- 👁️ **Show Coverage Boxes toggle** - Hide/show coverage squares in settings
- 🎯 **Smaller sample markers** - Reduced sample dot size by 25% for cleaner map display
- 📡 **Repeater friendly names on web map** - Map now displays custom repeater names instead of just node IDs
- 🗺️ Declutter the map by toggling coverage boxes on/off

### v1.0.14 (2026-01-16)
**Critical Fix:**
- 🛠️ **FIXED: Repeater ID detection** - App now correctly identifies which repeater responded to pings
- 📡 Proper parsing of mesh network routing paths to extract actual responding repeater
- 🎯 Coverage squares and sample popups now show accurate repeater IDs
- ✅ Fixes issue where wrong node IDs were being recorded in wardrive data

### v1.0.13 (2026-01-12)
**New Features:**
- 👁️ **Show GPS Samples toggle** - Hide blue GPS-only markers to declutter map
- 🗺️ Focus on ping results by toggling GPS samples on/off in settings

### v1.0.12 (2026-01-12)
**Critical Fixes:**
- 🛠️ **FIXED: Sample data overwriting bug** - Data now accumulates instead of replacing
- 📊 Fixed coverage showing decimal errors (1.2000000000000002)
- 🗺️ Map now auto-centers on your location at startup

**New Features:**
- 🟢 **Color-coded samples**: Green=success, Red=fail, Blue=GPS-only
- 🎯 Visual coverage quality at a glance

### v1.0.11 (2026-01-11)
**New Features:**
- 👆 **Clickable sample markers** - Tap any sample dot to see repeater, RSSI, and SNR
- 📊 View detailed ping info including signal strength and quality
- ⏱️ Sample timestamps and GPS coordinates in popup

**Critical Fix:**
- 🔧 **FIXED: RSSI/SNR values now display correctly in ping results**
- 📶 Signal strength and quality metrics now accurate
- 🎯 0x88 frames properly parsed as raw radio log data
- ✅ Fixes null values in debug terminal

### v1.0.10 (2026-01-11)
**Major Features:**
- 🏛️ **Configurable Coverage Resolution** - Adjust square size from 20km (regional) down to 38m (building-level)
- 🧠 **Smart Sample Weighting** - Newer data automatically overrides contradicting old data
- ⏳ Time-based decay keeps maps accurate as coverage changes
- 📊 Perfect for both drivers (large squares) and walkers (small squares)

### v1.0.9 (2026-01-11)
**New Features:**
- 📍 **Auto-follow GPS location** - Map automatically centers and follows your blue dot
- 🔄 Toggle with GPS button - blue when active, gray when inactive
- 👆 Automatically disables when you manually pan the map

### v1.0.8 (2026-01-11)
**Critical Fix:**
- 🚨 **FIXED: Removed Seattle-area geofence blocking auto-ping outside 60-mile radius**
- 🌍 Auto-ping now works globally, anywhere on Earth
- 🔧 Fixes Samsung Galaxy Fold 6/7 and other users' auto-ping not triggering
- ✅ App now supports worldwide coverage collection

### v1.0.7 (2026-01-10)
**New Features:**
- 📱 Tap coverage squares to see detailed info
- 📊 Shows samples, success rate, received/lost pings, and repeater IDs
- 🗺️ Same coverage info as webmap
- 👆 Draggable scrollable settings menu

**Bug Fixes:**
- 🔧 Fixed settings menu overlapping top bar and nav buttons
- 🔧 Fixed repeater IDs showing actual nodes that echoed pings

### v1.0.6 (2026-01-10)
**Improvements:**
- ⚡ Reduced ping timeout from 30s to 20s for faster response detection
- ⚡ Improved ping reliability matching MeshCore app behavior

### v1.0.5 (2026-01-09)
**Bug Fix:**
- 🔧 Fixed coverage squares not populating when auto-ping is enabled
- 🔧 Eliminated duplicate GPS samples that were preventing coverage display

### v1.0.4 (2026-01-09)
**Improvements:**
- ✨ Increased map zoom out range for better overview

### v1.0.3 (2026-01-09)
**New Features:**
- ✨ Auto-ping visual feedback - Orange pulse animation on map when pinging
- ✨ Persistent notification updates show ping status and results
- ✨ Check for Updates - Compare your version with latest GitHub release
- ✨ View on GitHub link in settings
- ✨ Increased map zoom out range for better overview

### v1.0.2 (2026-01-09)
**Bug Fix:**
- 🔧 Fixed settings menu being hidden behind navigation bar on devices with on-screen buttons

### v1.0.1 (2026-01-09)
**Bug Fixes:**
- 🔧 Fixed background GPS tracking on modern Android devices (Pixel 8, etc.)
- 🔧 Implemented foreground service with persistent notification
- 🔧 Fixed map not updating in real-time during tracking
- 🔧 Fixed auto-ping blocking location updates
- 🔧 Debug terminal now scrolls to latest logs when opened

**Improvements:**
- ⚡ Non-blocking ping system - location tracking continues smoothly
- ⚡ Real-time map updates when samples are saved
- ⚡ Changed grid precision to 6 for better coverage while walking
- 📱 Added notification permission request for Android 13+

**Web Map Updates:**
- 🌐 Disabled infinite horizontal scrolling
- 🌐 Fixed repeater display to only show when pings received
- 🌐 Filtered out "Unknown" nodes from repeater lists
- 🌐 Synced grid precision with Android app

### v1.0.0 (2026-01-08)
- Initial release
- GPS tracking with background support
- USB and Bluetooth device support
- Auto-ping functionality
- Success rate based coverage visualization
- Web map integration
- Repeater discovery
- Data export and upload

## 🆘 Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing issues for solutions

## 🛠️ Development

For developers who want to build from source, see the [source code repository](https://github.com/mintylinux/Meshcore-Wardrive-Android-Source) which includes:

- Complete Flutter project structure
- Development setup instructions
- Build configuration
- Architecture documentation
- Contributing guidelines

## 📄 License

[Specify your license here]

## 🙏 Credits

Built for the MeshCore mesh networking community.

## 📧 Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation in the repository

---

**Current Version:** 1.0.24

**Minimum Android Version:** Android 5.0 (API 21)

**Happy Wardriving! 🚗📡**
