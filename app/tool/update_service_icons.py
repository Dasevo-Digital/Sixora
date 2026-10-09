#!/usr/bin/env python3
"""Builds the bundled service icons from Simple Icons (https://simpleicons.org).

    python3 tool/update_service_icons.py      # from the app/ directory

Downloads one pinned release from the npm registry, checks its integrity
hash, keeps only icons whose terms fit this project and writes

    assets/service_icons.json.gz   title, slug, colour, SVG path, aliases
    ../THIRD_PARTY_NOTICES.md      section "Dienst-Icons" with attributions

The app never loads icons at runtime: every request would tell a third party
which services someone uses.

To update: set VERSION and INTEGRITY to a newer release
(https://registry.npmjs.org/simple-icons/<version> → dist.integrity).
"""
import base64
import gzip
import hashlib
import io
import json
import os
import re
import tarfile
import urllib.request

VERSION = "16.34.0"
INTEGRITY = "sha512-UTxKn0PVspk84B2hHF3Dqiqht1yDjJmDc/t4cO7PyCQxCMk6OjEu95pnpGjhLaGeQ4qBrGASbefTIe/+czrX7g=="

# Icons without own licence data fall under the project's CC0. Of the
# others only permissive licences are kept (attribution goes into the
# notices); copyleft, non-commercial, no-derivatives and custom terms are
# left out.
ALLOWED = {
    "CC0-1.0", "MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC",
    "CC-BY-3.0", "CC-BY-4.0",
}

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "service_icons.json.gz")
NOTICES = os.path.join(os.path.dirname(ROOT), "THIRD_PARTY_NOTICES.md")
MARK_BEGIN = "<!-- service-icons:begin -->"
MARK_END = "<!-- service-icons:end -->"


def download():
    url = f"https://registry.npmjs.org/simple-icons/-/simple-icons-{VERSION}.tgz"
    data = urllib.request.urlopen(url, timeout=120).read()
    algo, expected = INTEGRITY.split("-", 1)
    got = base64.b64encode(hashlib.new(algo, data).digest()).decode()
    if got != expected:
        raise SystemExit(f"Integrity mismatch for simple-icons {VERSION}")
    return tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")


def aliases(icon):
    a = icon.get("aliases") or {}
    out = list(a.get("aka", []))
    out += [d["title"] for d in a.get("dup", []) if "title" in d]
    out += list((a.get("loc") or {}).values())
    return sorted({x for x in out if x and x != icon["title"]})


def main():
    tar = download()
    meta = json.load(tar.extractfile("package/data/simple-icons.json"))
    icons, attributed, skipped = [], [], 0
    for icon in meta:
        licence = (icon.get("license") or {}).get("type")
        if licence and licence not in ALLOWED:
            skipped += 1
            continue
        svg = tar.extractfile(f"package/icons/{icon['slug']}.svg").read().decode()
        paths = re.findall(r'<path d="([^"]+)"', svg)
        if len(paths) != 1 or 'viewBox="0 0 24 24"' not in svg:
            skipped += 1
            continue
        icons.append([icon["title"], icon["slug"], icon["hex"], paths[0], aliases(icon)])
        if licence and licence != "CC0-1.0":
            attributed.append((icon["title"], licence, icon.get("source", "")))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    blob = json.dumps({"version": VERSION, "icons": icons}, separators=(",", ":"), ensure_ascii=False)
    with open(OUT, "wb") as f:
        # mtime=0: the same input gives the same file.
        f.write(gzip.compress(blob.encode(), 9, mtime=0))

    lines = [
        MARK_BEGIN,
        "## Dienst-Icons",
        "",
        f"Die Logos der Dienste stammen aus [Simple Icons](https://simpleicons.org) {VERSION}",
        "(CC0 1.0). Die Marken und Logos gehören ihren jeweiligen Inhabern; ihre",
        "Verwendung kennzeichnet nur den Dienst und bedeutet keine Verbindung zu",
        "Sixora. Icons mit Copyleft-, nicht-kommerziellen oder eigenen Bedingungen",
        "sind nicht enthalten. Für diese Icons gelten eigene, freizügige Lizenzen:",
        "",
        "| Icon | Lizenz | Quelle |",
        "|---|---|---|",
    ]
    lines += [f"| {t} | {lic} | {src} |" for t, lic, src in sorted(attributed)]
    lines.append(MARK_END)
    section = "\n".join(lines)
    text = open(NOTICES).read() if os.path.exists(NOTICES) else "# Hinweise zu Komponenten Dritter\n"
    if MARK_BEGIN in text:
        text = re.sub(re.escape(MARK_BEGIN) + ".*?" + re.escape(MARK_END), section, text, flags=re.S)
    else:
        text = text.rstrip() + "\n\n" + section + "\n"
    open(NOTICES, "w").write(text)
    print(f"{len(icons)} icons ({os.path.getsize(OUT) // 1024} KB), {skipped} skipped, "
          f"{len(attributed)} with attribution")


if __name__ == "__main__":
    main()
