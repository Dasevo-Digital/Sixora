#!/usr/bin/env bash
# Runs the app's end-to-end test against a fresh, temporary Sixora server.
# Usage: tool/integration_test.sh [device]   (default: macos)
# The app runs with SIXORA_ENV=test: own data folder and no keychain, so the
# real app and its data stay untouched.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
device="${1:-macos}"
port=18081
data="$(mktemp -d)"
server=""
cleanup() {
  if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; fi
  rm -rf "$data"
  # flutter test leaves a real-looking app bundle behind. Remove only the
  # test build products so Spotlight can never open them as the user's app.
  for builds in "$root/app/build" "$root/app/build.noindex"; do
    [ ! -d "$builds" ] || find "$builds" -type d \
      \( -name 'Sixora.app' -o -name 'Sixora Dev.app' \) -prune \
      -exec rm -rf -- {} +
  done
}
trap cleanup EXIT

# The test registers the first account with this setup code.
(cd server && SIXORA_DATA_DIR="$data" SIXORA_HOST=127.0.0.1 SIXORA_PORT=$port \
  SIXORA_SETUP_CODE=TEST-SETUP-CODE-0001 \
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
