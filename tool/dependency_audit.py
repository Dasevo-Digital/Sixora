#!/usr/bin/env python3
"""Checks resolved Pub packages for advisories and maintenance regressions."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ALLOWED_DISCONTINUED = {
    # Current window_manager release still uses these platform packages.
    "screen_retriever_linux",
    "screen_retriever_macos",
    "screen_retriever_platform_interface",
    "screen_retriever_windows",
    # Current hotkey_manager uses this compatibility package.
    "uni_platform",
    # The platform packages of hotkey_manager 0.2, until the move to 0.3
    # (see DEFERRED_UPGRADES).
    "hotkey_manager_macos",
    "hotkey_manager_platform_interface",
    "hotkey_manager_windows",
}

# Newer major versions that are known and deliberately not taken yet, with
# the version prefix that is deferred. A still newer version fails the audit
# again, and security advisories fail it for these packages as well.
DEFERRED_UPGRADES = {
    # Both move to nativeapi: closing, quitting, the menu bar and the global
    # shortcut change underneath and need a test by hand on macOS, Windows
    # and Linux before a release.
    "window_manager": "0.6.",
    "hotkey_manager": "0.3.",
}

root = Path(sys.argv[1])
failures: list[str] = []
seen_discontinued: set[str] = set()

for report in sorted(root.glob("*.json")):
    data = json.loads(report.read_text())
    for package in data.get("packages", []):
        current = package.get("current")
        if not current:
            continue
        name = package["package"]
        if package.get("isCurrentAffectedByAdvisory"):
            failures.append(f"{report.stem}: Sicherheitswarnung für {name}")
        if package.get("isDiscontinued"):
            seen_discontinued.add(name)
            if name not in ALLOWED_DISCONTINUED:
                failures.append(f"{report.stem}: eingestelltes Paket {name}")
        resolvable = package.get("resolvable")
        newer = resolvable.get("version") if resolvable else None
        deferred = DEFERRED_UPGRADES.get(name)
        if (
            package.get("kind") in {"direct", "dev"}
            and newer
            and current.get("version") != newer
            and not (deferred and newer.startswith(deferred))
        ):
            failures.append(
                f"{report.stem}: {name} kann von {current.get('version')} "
                f"auf {newer} aktualisiert werden"
            )

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)

known = sorted(seen_discontinued & ALLOWED_DISCONTINUED)
suffix = f" Bekannte Übergangspakete: {', '.join(known)}." if known else ""
print(f"Dependency audit passed.{suffix}")
