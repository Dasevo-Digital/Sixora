#!/usr/bin/env bash
# Renders the README screenshots (docs/screenshots) with demo accounts:
# the real app (SIXORA_ENV=test, own data, no keychain) against a fresh,
# temporary server. Usage: tool/screenshots.sh
set -euo pipefail
cd "$(dirname "$0")/.."
port=18082
data="$(mktemp -d)"
log="$(mktemp)"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$data" "$log"' EXIT

(cd server && SIXORA_DATA_DIR="$data" SIXORA_HOST=127.0.0.1 SIXORA_PORT=$port \
  SIXORA_REGISTRATION=open exec dart run bin/server.dart) >"$data.log" 2>&1 &
server=$!
for _ in $(seq 1 60); do
  curl -fs "http://127.0.0.1:$port/api/v1/info" >/dev/null && break
  sleep 1
done

mkdir -p docs/screenshots
(cd app && flutter test integration_test/screenshots_test.dart -d macos \
  --dart-define=SIXORA_ENV=test \
  --dart-define=SIXORA_SHOTS=1 \
  --dart-define=SIXORA_TEST_SERVER="http://127.0.0.1:$port") | tee "$log"
for name in $(grep -o 'SHOT [a-z-]* ' "$log" | cut -d' ' -f2 | sort -u); do
  grep -o "SHOT $name [A-Za-z0-9+/=]*" "$log" | cut -d' ' -f3 | tr -d '\n' \
    | base64 -d >"docs/screenshots/$name.png"
  echo "docs/screenshots/$name.png"
done
# The test build is a Sixora.app like the real one: keep it out of
# Spotlight and Launchpad.
rm -rf app/build/macos/Build/Products/Debug/Sixora.app
