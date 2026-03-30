# Installation Guide

## Android Installation

### Step 1: Enable Unknown Sources
1. Open **Settings** on your Android device
2. Go to **Security** or **Privacy**
3. Enable **Install from Unknown Sources** or **Allow from this source** (Android 8+)

### Step 2: Download the APK
1. Go to [github.com/george-viaud/Meshcore-Wardrive-Android/releases](https://github.com/george-viaud/Meshcore-Wardrive-Android/releases)
2. Download the latest `meshcore_wardrive_vX.X.XX.apk`
3. Transfer to your Android device if downloaded on a computer

### Step 3: Install
1. Open the APK file on your device
2. Tap **Install**
3. Tap **Open** or find the app in your app drawer

### Step 4: Grant Permissions
On first launch, grant:
- **Location** (Always) — Required for GPS tracking
- **Bluetooth** — For Bluetooth LoRa device connection
- **Storage** — For exporting data
- **USB** — For USB LoRa device connection

## First Time Setup

### Enter Your Contributor Token
The app requires a valid contributor token to upload data to the community map.

1. On first launch, the **Token Required** dialog appears automatically
2. Enter your token from [wardrive.inwmesh.org](https://wardrive.inwmesh.org)
   - If you don't have one, contact an admin for an invite link
3. Tap **Test** to verify the token is valid
4. Tap **Save**

You can update your token any time via **Settings → Configure API**.

### Connect LoRa Device

#### USB Connection
1. Connect your MeshCore companion radio via USB cable
2. Open MeshCore Wardrive
3. Tap **Connect** → **Scan USB Devices**
4. Select your device from the list
5. Grant USB permissions when prompted

#### Bluetooth Connection
1. Pair your device in Android Settings → Bluetooth first
2. Open MeshCore Wardrive
3. Tap **Connect** → **Scan Bluetooth**
4. Select your paired device
5. Wait for connection (green indicator)

### Start Wardriving
1. Press the **green play button** to start GPS tracking and auto-ping
2. Drive or walk through your area
3. Watch the map fill with coverage data

## Troubleshooting

### "Failed to install" error
- Ensure you have enough storage space (~150MB free)
- Uninstall any previous version first
- Restart your device and try again

### Token rejected on startup
- Check your internet connection
- Sign in to [wardrive.inwmesh.org](https://wardrive.inwmesh.org) → My Token to retrieve or refresh your token
- If your account was disabled, contact an admin

### Permissions denied
- Go to Settings → Apps → MeshCore Wardrive → Permissions
- Enable all required permissions manually

## Updating

1. Download the new APK from [GitHub Releases](https://github.com/george-viaud/Meshcore-Wardrive-Android/releases)
2. Install over the existing app — your data and token will be preserved

## Uninstalling

Go to Settings → Apps → MeshCore Wardrive → Uninstall.

**Note:** Uninstalling will delete all locally collected wardrive data.
