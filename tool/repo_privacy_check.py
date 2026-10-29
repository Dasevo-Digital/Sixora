#!/usr/bin/env python3
"""Reject personal identifiers and common credentials without echoing them."""

from __future__ import annotations

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path


ROOT = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
)
os.chdir(ROOT)

PROJECT_EMAIL = "335995236+superkuh86" + "@users.noreply.github.com"
PROJECT_IDENTITY = f"superkuh86 <{PROJECT_EMAIL}>"
SELF_PATHS = {
    "tool/repo_privacy_check.py",
    "tool/repo_privacy_check.sh",
}
EMAIL_RE = re.compile(
    r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE
)
MESSAGE_RE = re.compile(
    r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"
    r"|co-authored-by:|generated with",
    re.IGNORECASE,
)
SECRET_RE = re.compile(
    r"-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----"
    r"|gh[pousr]_[A-Za-z0-9]{36}"
    r"|github_pat_[A-Za-z0-9_]{40,}"
    r"|AKIA[0-9A-Z]{16}"
    r"|xox[baprs]-[A-Za-z0-9-]{10,}"
    r"|sk-[A-Za-z0-9]{32,}"
)

failures: list[str] = []


def git(*args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        errors="replace",
    )
    return result.stdout


def report(message: str) -> None:
    failures.append(message)


def tracked_files() -> list[str]:
    return [p for p in git("ls-files", "-z").split("\0") if p]


def text_lines(path: str) -> list[str]:
    try:
        raw = Path(path).read_bytes()
    except OSError:
        return []
    if b"\0" in raw:
        return []
    return raw.decode("utf-8", errors="replace").splitlines()


def allowed_email(address: str, path: str) -> bool:
    value = address.lower()
    if value == PROJECT_EMAIL.lower():
        return True
    domain = value.rsplit("@", 1)[1]
    if domain in {"example.com", "example.net", "example.org"}:
        return True
    if domain.endswith(".example"):
        return True
    # Apple asset scale suffixes such as Icon-App-60x60@3x.png look like
    # addresses to a deliberately broad detector.
    if ".xcassets/" in path.lower() and re.search(
        r"@[0-9]+(?:x[0-9]+)?x?\.[a-z0-9]+$", value
    ):
        return True
    # These two values existed only as test data before reserved example
    # domains were used. They remain reachable in the public history.
    return (path, value) in {
        ("app/integration_test/screenshots_test.dart", "alex@example.social"),
        ("app/test/service_icons_test.dart", "me@gitlab.com"),
    }


def check_worktree() -> None:
    for path in tracked_files():
        if path in SELF_PATHS:
            continue
        for number, line in enumerate(text_lines(path), start=1):
            if any(not allowed_email(m.group(0), path) for m in EMAIL_RE.finditer(line)):
                report(f"Unerlaubte E-Mail-Adresse in {path}:{number}")
            if SECRET_RE.search(line):
                report(f"Mögliches Zugangsdatenmuster in {path}:{number}")


def check_email_history() -> None:
    history = git(
        "log",
        "HEAD",
        "--format=@@SIXORA_COMMIT:%H",
        "--no-ext-diff",
        "--full-history",
        "-p",
        "--",
        ".",
        ":(exclude)tool/repo_privacy_check.py",
        ":(exclude)tool/repo_privacy_check.sh",
    )
    commit = "unbekannt"
    old_path = ""
    new_path = ""
    seen: set[tuple[str, str]] = set()
    for line in history.splitlines():
        if line.startswith("@@SIXORA_COMMIT:"):
            commit = line.split(":", 1)[1]
            continue
        if line.startswith("diff --git "):
            try:
                parts = shlex.split(line)
                old_path = parts[2].removeprefix("a/")
                new_path = parts[3].removeprefix("b/")
            except (IndexError, ValueError):
                old_path = new_path = ""
            continue
        if line.startswith(("+++", "---")) or not line.startswith(("+", "-")):
            continue
        path = new_path if line.startswith("+") else old_path
        if any(not allowed_email(m.group(0), path) for m in EMAIL_RE.finditer(line[1:])):
            key = (commit, path)
            if key not in seen:
                seen.add(key)
                report(f"Unerlaubte E-Mail-Adresse in Historie {commit[:7]} ({path})")


def check_identities_and_messages() -> None:
    for line in git(
        "log", "HEAD", "--format=%H%x09%aN <%aE>%x09%cN <%cE>"
    ).splitlines():
        commit, author, committer = line.split("\t", 2)
        if author != PROJECT_IDENTITY or committer != PROJECT_IDENTITY:
            report(f"Abweichende Commit-Identität in {commit[:7]}")

    for commit in git("rev-list", "HEAD").splitlines():
        message = git("show", "-s", "--format=%B", commit)
        for match in MESSAGE_RE.finditer(message):
            if match.group(0).lower() != PROJECT_EMAIL.lower():
                report(f"Personen- oder Werkzeughinweis in Commit {commit[:7]}")
                break

    for tag in git("tag", "-l").splitlines():
        contents = git(
            "for-each-ref", f"refs/tags/{tag}", "--format=%(contents)"
        )
        for match in MESSAGE_RE.finditer(contents):
            if match.group(0).lower() != PROJECT_EMAIL.lower():
                report(f"Personen- oder Werkzeughinweis in Tag {tag}")
                break


def check_secret_history() -> None:
    history = git(
        "log",
        "HEAD",
        "--format=@@SIXORA_COMMIT:%H",
        "--no-ext-diff",
        "--full-history",
        "-p",
        "--",
        ".",
        ":(exclude)tool/repo_privacy_check.py",
        ":(exclude)tool/repo_privacy_check.sh",
    )
    commit = "unbekannt"
    seen: set[str] = set()
    for line in history.splitlines():
        if line.startswith("@@SIXORA_COMMIT:"):
            commit = line.split(":", 1)[1]
            continue
        if line.startswith(("+++", "---")) or not line.startswith(("+", "-")):
            continue
        if SECRET_RE.search(line[1:]) and commit not in seen:
            seen.add(commit)
            report(f"Mögliches Zugangsdatenmuster in Historie {commit[:7]}")


check_worktree()
check_email_history()
check_identities_and_messages()
check_secret_history()

if failures:
    for failure in dict.fromkeys(failures):
        print(failure, file=sys.stderr)
    print(
        "Datenschutzprüfung fehlgeschlagen; Fundwerte wurden absichtlich nicht ausgegeben.",
        file=sys.stderr,
    )
    raise SystemExit(1)

print("Repository privacy check passed.")
