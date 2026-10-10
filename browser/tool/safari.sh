#!/bin/sh
# Wraps the extension (build/safari from tool/build.sh) in a small Mac app
# for Safari and builds it:
#
#   browser/tool/safari.sh
#     → browser/build/safari.noindex/Sixora für Safari.app
#       (*.noindex: Spotlight does not list the test build as an app)
#
# Open the app once, then switch the extension on in Safari → Settings →
# Extensions. It is signed locally with the "Apple Development" certificate
# (like the Sixora app, nothing is registered with Apple); Safari may also
# need Develop → "Allow Unsigned Extensions" until there is a paid
# developer account.
set -eu
cd "$(dirname "$0")/.."
[ -d build/safari ] || { echo "Erst tool/build.sh ausführen." >&2; exit 1; }
name="Sixora für Safari"
project="build/safari-xcode/$name/$name.xcodeproj/project.pbxproj"
rm -rf build/safari-xcode build/safari-dd build/safari.noindex
xcrun safari-web-extension-converter build/safari \
  --project-location build/safari-xcode \
  --app-name "$name" \
  --bundle-identifier de.status403.sixora.safari \
  --swift --macos-only --copy-resources --no-open --no-prompt --force >/dev/null
# The converter derives the app's id from its name; the extension's id must
# start with the app's. Safari 18.2 (WebAssembly GC) runs from macOS 13 on.
sed -i '' \
  -e 's/PRODUCT_BUNDLE_IDENTIFIER = "de.status403.sixora.[^"]*";/PRODUCT_BUNDLE_IDENTIFIER = de.status403.sixora.safari;/' \
  -e 's/MACOSX_DEPLOYMENT_TARGET = [0-9.]*;/MACOSX_DEPLOYMENT_TARGET = 13.0;/' \
  "$project"
# The app's own page in our languages instead of the English template.
cp safari/Script.js "build/safari-xcode/$name/$name/Resources/Script.js"
# All targets instead of the scheme: Xcode writes the "ü" of the scheme's
# name decomposed, so `-scheme` would not find it.
xcodebuild -quiet \
  -project "build/safari-xcode/$name/$name.xcodeproj" \
  -alltargets -configuration Release \
  SYMROOT="$PWD/build/safari-dd" \
  CODE_SIGNING_ALLOWED=NO build
app="build/safari.noindex/$name.app"
mkdir -p build/safari.noindex
ditto "build/safari-dd/Release/$name.app" "$app"
rm -rf build/safari-dd

identity="$(security find-identity -v -p codesigning |
  sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -n 1)"
if [ -z "$identity" ]; then
  echo "Kein „Apple Development“-Zertifikat im Schlüsselbund (Xcode → Settings → Accounts)." >&2
  exit 1
fi
entitlements="build/safari-entitlements.plist"
cat >"$entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
</dict>
</plist>
PLIST
# Inside out: the extension first, then the app around it.
codesign --force --sign "$identity" --timestamp=none --options runtime \
  --entitlements "$entitlements" "$app/Contents/PlugIns/$name Extension.appex"
codesign --force --sign "$identity" --timestamp=none --options runtime \
  --entitlements "$entitlements" "$app"
codesign --verify --deep --strict "$app"
rm -f "$entitlements"
echo "Gebaut: $app"
