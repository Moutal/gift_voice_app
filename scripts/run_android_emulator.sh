#!/usr/bin/env bash
set -euo pipefail

ADB="$HOME/Library/Android/sdk/platform-tools/adb"
EMU="$HOME/Library/Android/sdk/emulator/emulator"
AVD_NAME="${1:-Pixel_3a_API_33_arm64-v8a}"

"$ADB" start-server >/dev/null
nohup "$EMU" -avd "$AVD_NAME" -no-snapshot-load >/tmp/android_emulator.log 2>&1 &

echo "Waiting for emulator boot..."
"$ADB" wait-for-device
for _ in {1..120}; do
  BOOTED=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
  if [[ "$BOOTED" == "1" ]]; then
    break
  fi
  sleep 1
done

"$ADB" devices -l
flutter run -d emulator-5554
