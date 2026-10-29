#!/usr/bin/env bash
# Re-signs CI staging APKs with the established product key.
set -euo pipefail

if (( $# == 0 )); then
  echo 'Aufruf: sign_android.sh <Datei.stage.apk> [...]' >&2
  exit 2
fi

: "${SIXORA_ANDROID_KEYSTORE:?SIXORA_ANDROID_KEYSTORE fehlt}"
: "${SIXORA_ANDROID_KEY_ALIAS:?SIXORA_ANDROID_KEY_ALIAS fehlt}"
: "${SIXORA_ANDROID_STORE_PASSWORD:?SIXORA_ANDROID_STORE_PASSWORD fehlt}"
: "${SIXORA_ANDROID_KEY_PASSWORD:?SIXORA_ANDROID_KEY_PASSWORD fehlt}"
[[ -f "$SIXORA_ANDROID_KEYSTORE" ]] || {
  echo 'Der konfigurierte Android-Schlüsselspeicher fehlt.' >&2
  exit 2
}

if [[ -n "${SIXORA_APKSIGNER:-}" ]]; then
  signer=("$SIXORA_APKSIGNER")
elif command -v apksigner >/dev/null 2>&1; then
  signer=(apksigner)
elif [[ -n "${SIXORA_APKSIGNER_JAR:-}" && -f "$SIXORA_APKSIGNER_JAR" ]]; then
  java_bin="${SIXORA_JAVA_BIN:-java}"
  signer=("$java_bin" -jar "$SIXORA_APKSIGNER_JAR")
else
  echo 'apksigner oder SIXORA_APKSIGNER_JAR fehlt.' >&2
  exit 2
fi

expected="$(tr -d ':[:space:]' <"$(dirname "$0")/../android/release-cert-sha256.txt" | tr '[:upper:]' '[:lower:]')"
for input in "$@"; do
  [[ "$input" == *.stage.apk && -f "$input" ]] || {
    echo "Keine gültige Staging-APK: $input" >&2
    exit 2
  }
  output="${input%.stage.apk}.apk"
  "${signer[@]}" sign \
    --ks "$SIXORA_ANDROID_KEYSTORE" \
    --ks-key-alias "$SIXORA_ANDROID_KEY_ALIAS" \
    --ks-pass env:SIXORA_ANDROID_STORE_PASSWORD \
    --key-pass env:SIXORA_ANDROID_KEY_PASSWORD \
    --out "$output" \
    "$input"
  verification="$("${signer[@]}" verify --verbose --print-certs "$output")"
  digest="$(printf '%s\n' "$verification" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -n 1 | tr -d ':[:space:]' | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$digest" || "$digest" != "$expected" ]]; then
    rm -f "$output"
    echo 'Die APK trägt nicht den erwarteten, bisherigen Signaturschlüssel.' >&2
    exit 1
  fi
  echo "Signatur geprüft: $(basename "$output")"
done
