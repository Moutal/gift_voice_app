#!/usr/bin/env bash
set -euo pipefail

# Workaround for simulator codesign failure caused by copied file metadata.
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1
export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"
export RUBYOPT='-rlogger'
export PATH="$PWD/scripts/toolshim:$PATH"

DEVICE_NAME="${1:-iPhone 17 Pro}"

find_udid() {
  xcrun simctl list devices available | \
    awk -v target="$1" '
      index($0, target " (") {
        if (match($0, /\(([0-9A-F-]{36})\)/)) {
          print substr($0, RSTART + 1, RLENGTH - 2);
          exit;
        }
      }'
}

UDID="$(find_udid "$DEVICE_NAME")"
if [[ -z "${UDID:-}" ]]; then
  # Fallback to the first available iPhone simulator.
  UDID="$(xcrun simctl list devices available | awk '
    /iPhone/ && /\([0-9A-F-]{36}\)/ {
      if (match($0, /\(([0-9A-F-]{36})\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2);
        exit;
      }
    }')"
fi

if [[ -z "${UDID:-}" ]]; then
  echo "No available iPhone simulator found."
  exit 1
fi

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b

flutter run -d "$UDID"
