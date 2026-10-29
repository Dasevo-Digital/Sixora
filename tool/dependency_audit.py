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
        if (
            package.get("kind") in {"direct", "dev"}
            and resolvable
            and current.get("version") != resolvable.get("version")
        ):
            failures.append(
                f"{report.stem}: {name} kann von {current.get('version')} "
                f"auf {resolvable.get('version')} aktualisiert werden"
            )

if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)

known = sorted(seen_discontinued & ALLOWED_DISCONTINUED)
suffix = f" Bekannte Übergangspakete: {', '.join(known)}." if known else ""
print(f"Dependency audit passed.{suffix}")
