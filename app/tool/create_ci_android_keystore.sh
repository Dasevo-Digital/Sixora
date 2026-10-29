#!/usr/bin/env bash
# Creates a short-lived signing identity for build validation only.
set -euo pipefail

if [[ -z "${GITHUB_ENV:-}" || -z "${RUNNER_TEMP:-}" ]]; then
  echo 'Dieses Werkzeug läuft ausschließlich auf einem GitHub-Actions-Runner.' >&2
  exit 2
fi

umask 077
keystore="$RUNNER_TEMP/sixora-ci.jks"
password="$(openssl rand -hex 24)"
echo "::add-mask::$password"
keytool -genkeypair -noprompt \
  -keystore "$keystore" \
  -storepass "$password" \
  -keypass "$password" \
  -alias sixora-ci \
  -keyalg RSA \
  -keysize 3072 \
  -validity 2 \
  -dname 'CN=Sixora CI'

{
  printf 'SIXORA_ANDROID_KEYSTORE=%s\n' "$keystore"
  printf 'SIXORA_ANDROID_KEY_ALIAS=%s\n' sixora-ci
  printf 'SIXORA_ANDROID_STORE_PASSWORD=%s\n' "$password"
  printf 'SIXORA_ANDROID_KEY_PASSWORD=%s\n' "$password"
} >>"$GITHUB_ENV"
