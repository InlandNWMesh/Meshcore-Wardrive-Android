#!/usr/bin/env bash
# build_and_install.sh — Build debug APK and install to connected Android device.
#
# Usage:
#   ./build_and_install.sh           # build + install
#   ./build_and_install.sh --build   # build only, skip install
#   ./build_and_install.sh --install # install only (skip build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APK="$SCRIPT_DIR/build/app/outputs/flutter-apk/app-debug.apk"

BUILD=true
INSTALL=true

for arg in "$@"; do
  case "$arg" in
    --build)   INSTALL=false ;;
    --install) BUILD=false ;;
  esac
done

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   MeshCore Wardrive — Build & Install    ║"
echo "╚══════════════════════════════════════════╝"
echo ""

cd "$SCRIPT_DIR"

# ── 1. Build ──────────────────────────────────────────────────────────────────

if $BUILD; then
  echo "→ Building debug APK..."
  flutter build apk --debug
  echo "  Built: $APK"
fi

# ── 2. Wait for device ────────────────────────────────────────────────────────

if $INSTALL; then
  echo "→ Waiting for Android device (USB debugging must be enabled)..."
  adb wait-for-device
  DEVICE=$(adb devices | awk '/\tdevice$/{print $1; exit}')
  if [ -z "$DEVICE" ]; then
    echo "✗ No authorised device found. Check USB debugging and authorise this computer."
    exit 1
  fi
  echo "  Device: $DEVICE"

  # ── 3. Install ───────────────────────────────────────────────────────────────

  echo "→ Installing APK..."
  adb -s "$DEVICE" install -r "$APK"
  echo ""
  echo "✓ Installed successfully on $DEVICE."
  echo ""
fi
