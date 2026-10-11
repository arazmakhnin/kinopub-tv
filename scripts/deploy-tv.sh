#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_ID="evekeen001.KinoPub"

# Pass the TV IP as TV_IP or as the first positional argument.
TV_IP="${TV_IP:-}"
for arg in "$@"; do
  if [ "$arg" != "--build" ]; then
    TV_IP="$arg"
  fi
done

if [ -z "$TV_IP" ]; then
  echo "Error: set TV_IP or pass the TV IP as the first argument."
  exit 2
fi

export PATH="$HOME/tizen-studio/tools:$HOME/tizen-studio/tools/ide/bin:$PATH"

WGT_PATH="$PROJECT_DIR/dist/KinoPub.wgt"
SHOULD_BUILD=false

for arg in "$@"; do
  if [ "$arg" = "--build" ]; then
    SHOULD_BUILD=true
  fi
done

if [ "$SHOULD_BUILD" = true ]; then
  if [ -z "${CERT_PROFILE:-}" ]; then
    echo "Error: set CERT_PROFILE to a configured Tizen certificate profile."
    exit 2
  fi
  echo "Building signed .wgt..."
  cd "$PROJECT_DIR"
  npm run build
  cp "$PROJECT_DIR/tizen/config.xml" "$PROJECT_DIR/dist/config.xml"
  cp "$PROJECT_DIR/tizen/icon.png" "$PROJECT_DIR/dist/icon.png"
  tizen package -t wgt -s "$CERT_PROFILE" -- "$PROJECT_DIR/dist"
fi

if [ ! -f "$WGT_PATH" ]; then
  echo "Error: KinoPub.wgt not found. Use --build flag to build and sign it first."
  exit 1
fi

echo "Connecting to TV at $TV_IP..."
SDB_CONNECTED=false
for attempt in 1 2 3; do
  OUTPUT=$(sdb connect "$TV_IP":26101 2>&1 || true)
  echo "$OUTPUT"
  if echo "$OUTPUT" | grep -qE "connected to|already connected"; then
    SDB_CONNECTED=true
    break
  fi
  echo "sdb retry $attempt..."
  sleep 2
done
if [ "$SDB_CONNECTED" = false ]; then
  echo "ERROR: Failed to connect sdb to $TV_IP"
  echo "Check the TV is on, on the same LAN, and Developer Mode is on."
  echo "If the IP changed, pass it explicitly: bash scripts/deploy-tv.sh <TV_IP>"
  ping -c 1 -W 1 "$TV_IP" >/dev/null 2>&1 && echo "$TV_IP is up (ping ok)" || echo "$TV_IP is not responding to ping"
  exit 1
fi
echo "Connected via $TV_IP"

echo "Pushing KinoPub.wgt to TV..."
PUSHED=false
for attempt in 1 2 3; do
  if sdb -s "$TV_IP":26101 push "$WGT_PATH" /home/owner/share/tmp/sdk_tools/tmp/KinoPub.wgt 2>&1; then
    PUSHED=true
    break
  fi
  echo "Push retry $attempt — reconnecting sdb..."
  sdb disconnect "$TV_IP":26101 2>/dev/null || true
  sleep 3
  sdb connect "$TV_IP":26101 2>&1 || true
  sleep 2
done
if [ "$PUSHED" = false ]; then
  echo "ERROR: Failed to push file after 3 attempts"
  exit 1
fi

echo "Installing KinoPub.wgt on TV..."
if ! sdb -s "$TV_IP":26101 shell 0 vd_appinstall evekeen001 /home/owner/share/tmp/sdk_tools/tmp/KinoPub.wgt 2>&1; then
  echo "Direct install failed; trying the Tizen CLI..."
  tizen install -n "$WGT_PATH" -s "$TV_IP":26101
fi

echo "Launching app..."
sdb -s "$TV_IP:26101" shell 0 debug "$APP_ID"

echo "Done!"
