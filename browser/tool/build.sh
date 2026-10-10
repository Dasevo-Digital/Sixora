#!/bin/sh
# Builds the browser extension for Chromium browsers (Chrome, Edge, Opera,
# Brave, Vivaldi), Firefox and Safari:
#
#   browser/tool/build.sh
#     → browser/build/<browser>/      to load unpacked for testing
#     → browser/build/sixora-browser-<version>-<browser>.zip
#
# The popup is Dart compiled to WebAssembly, with sixora_core's crypto.
# Safari wraps the extension in a Mac app: tool/safari.sh afterwards.
set -eu
cd "$(dirname "$0")/.."
version="$(sed -n 's/^version: *//p' pubspec.yaml)"
rm -rf build
mkdir -p build/wasm
dart pub get >/dev/null
dart compile wasm -O2 -o build/wasm/popup.wasm web/popup.dart >/dev/null
for target in chromium firefox safari; do
  out="build/$target"
  mkdir -p "$out"
  cp -R static/. "$out/"
  cp build/wasm/popup.wasm build/wasm/popup.mjs "$out/"
  dart run tool/manifest.dart "$target" "$version" >"$out/manifest.json"
  (cd "$out" && zip -qrX "../sixora-browser-$version-$target.zip" .)
done
rm -rf build/wasm
echo "Gebaut: build/{chromium,firefox,safari} (Version $version)"
