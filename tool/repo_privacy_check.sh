#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$repo_dir/tool/repo_privacy_check.py"
