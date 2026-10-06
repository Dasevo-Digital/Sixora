#!/bin/sh
# Builds Sixora from the working copy and installs it on this Mac:
#
#   tool/mac_install.sh          "Sixora" (the real app, own data)
#   tool/mac_install.sh dev      "Sixora Dev" (own bundle id and data)
#
# The app is signed with a stable identity (tool/sign_macos.sh), so the
# Keychain keeps "Immer erlauben" across updates. Build products stay out of
# Spotlight (build → build.noindex), so Spotlight shows only /Applications.
set -eu
cd "$(dirname "$0")/.."

# Spotlight skips folders named *.noindex.
if [ -d build ] && [ ! -L build ]; then
  rm -rf build.noindex
  mv build build.noindex
fi
mkdir -p build.noindex
[ -L build ] || ln -s build.noindex build

# Replaces the app in /Applications; a running copy is quit first and
# started again afterwards.
replace_app() { # <source .app> <target .app>
  was_running=0
  if pgrep -f "$2/Contents/MacOS/" >/dev/null 2>&1; then
    was_running=1
    osascript -e "tell application \"$2\" to quit" >/dev/null 2>&1 || true
    i=0
    while pgrep -f "$2/Contents/MacOS/" >/dev/null 2>&1; do
      i=$((i + 1))
      if [ $i -gt 30 ]; then
        echo "$(basename "$2") läuft noch – bitte beenden und erneut aufrufen." >&2
        exit 1
      fi
      sleep 1
    done
  fi
  rm -rf "$2"
  ditto "$1" "$2"
  [ $was_running -eq 0 ] || open "$2"
}

case "${1:-prod}" in
prod)
  flutter build macos --release
  APP="build/macos/Build/Products/Release/Sixora.app"
  TARGET="/Applications/Sixora.app"
  ;;
dev)
  FLUTTER_XCODE_SIXORA_APP_NAME="Sixora Dev" \
  FLUTTER_XCODE_SIXORA_BUNDLE_ID=de.status403.sixora.dev \
    flutter build macos --release --dart-define=SIXORA_ENV=dev
  APP="build/macos/Build/Products/Release/Sixora Dev.app"
  TARGET="/Applications/Sixora Dev.app"
  ;;
*)
  echo "Aufruf: tool/mac_install.sh [prod|dev]" >&2
  exit 64
  ;;
esac
tool/sign_macos.sh "$APP"
replace_app "$APP" "$TARGET"
# No second copy for Spotlight to find.
rm -rf "$APP"
echo "Installiert: $TARGET"
