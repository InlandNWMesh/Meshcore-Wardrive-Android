# Installation Guide

## Android Installation

### Step 1: Enable Unknown Sources
1. Open **Settings** on your Android device
2. Go to **Security** or **Privacy**
3. Enable **Install from Unknown Sources** or **Allow from this source** (for Android 8+)

### Step 2: Download the APK
1. Download `meshcore_wardrive_v1.0.0.apk` from the releases folder
2. Transfer to your Android device if downloaded on computer

### Step 3: Install
1. Open the APK file on your device
2. Tap **Install**
3. Wait for installation to complete
4. Tap **Open** or find the app in your app drawer

### Step 4: Grant Permissions
On first launch, grant these permissions:
- **Location** (Always) - Required for GPS tracking
- **Bluetooth** - For Bluetooth LoRa device connection
- **Storage** - For exporting data
- **USB** - For USB LoRa device connection (when connected)

## First Time Setup

### Join #meshwar Channel
1. Open the **MeshCore app** on your device
2. Get the **#meshwar QR code** from another user
3. Scan the QR code to join the channel
4. The channel will now appear in your channels list

### Connect LoRa Device

#### USB Connection
1. Connect your MeshCore companion radio via USB cable
2. Open MeshCore Wardrive app
3. Tap **Connect** → **Scan USB Devices**
4. Select your device from the list
5. Grant USB permissions when prompted

#### Bluetooth Connection
1. Pair your device in Android Settings → Bluetooth first
2. Open MeshCore Wardrive app
3. Tap **Connect** → **Scan Bluetooth**
4. Select your paired device
5. Wait for connection (green indicator)

### Start Wardriving
1. Press the **green play button** to start GPS tracking
2. Toggle **Auto-Ping switch** to enable automatic pinging
3. Drive/walk through your area
4. Watch the map fill with coverage data!

## Troubleshooting

### "Failed to install" error
- Make sure you have enough storage space (need ~100MB free)
- Uninstall any previous version first
- Restart your device and try again

### Permissions denied
- Go to Settings → Apps → MeshCore Wardrive → Permissions
- Enable all required permissions manually

### App crashes on startup
- Clear app data: Settings → Apps → MeshCore Wardrive → Storage → Clear Data
- Reinstall the app
- Make sure your Android version is 7.0 or higher

## Updating

To update to a new version:
1. Download the new APK
2. Install over the existing app (data will be preserved)
3. Or uninstall old version first for a clean install

## Uninstalling

1. Go to Settings → Apps → MeshCore Wardrive
2. Tap **Uninstall**
3. Or long-press the app icon → App info → Uninstall

Note: Uninstalling will delete all your collected wardrive data.
