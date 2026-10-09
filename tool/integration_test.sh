#!/usr/bin/env bash
# Runs the app's end-to-end test against a fresh, temporary Sixora server.
# Usage: tool/integration_test.sh [device]   (default: macos)
# The app runs with SIXORA_ENV=test: own data folder and no keychain, so the
# real app and its data stay untouched.
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-macos}"
port=18081
data="$(mktemp -d)"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$data"' EXIT

(cd server && SIXORA_DATA_DIR="$data" SIXORA_HOST=127.0.0.1 SIXORA_PORT=$port \
  exec dart run bin/server.dart) >"$data.log" 2>&1 &
server=$!
for _ in $(seq 1 60); do
  curl -fs "http://127.0.0.1:$port/api/v1/info" >/dev/null && break
  sleep 1
done

cd app
# Only the functional test: screenshots_test.dart has its own script, and
# every extra file means one more app start.
flutter test integration_test/app_test.dart -d "$device" \
  --dart-define=SIXORA_ENV=test \
  --dart-define=SIXORA_TEST_SERVER="http://127.0.0.1:$port"
