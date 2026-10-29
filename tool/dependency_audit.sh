#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

(cd "$repo_dir/packages/sixora_core" && dart pub outdated --json --show-all) \
  >"$work/core.json"
(cd "$repo_dir/server" && dart pub outdated --json --show-all) \
  >"$work/server.json"
(cd "$repo_dir/browser" && dart pub outdated --json --show-all) \
  >"$work/browser.json"
(cd "$repo_dir/app" && flutter pub outdated --json --show-all) \
  >"$work/app.json"

python3 "$repo_dir/tool/dependency_audit.py" "$work"
