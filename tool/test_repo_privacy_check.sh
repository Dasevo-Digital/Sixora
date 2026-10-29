#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

new_repo() {
  local target="$1"
  mkdir -p "$target/tool"
  cp "$repo_dir/tool/repo_privacy_check.py" "$target/tool/"
  cp "$repo_dir/tool/repo_privacy_check.sh" "$target/tool/"
  git -C "$target" init -q
  git -C "$target" config user.name superkuh86
  git -C "$target" config user.email \
    '335995236+superkuh86'@'users.noreply.github.com'
  printf 'sicher\n' >"$target/README.md"
  printf '%s@%s\n' tester example.org >"$target/example.txt"
  git -C "$target" add .
  git -C "$target" commit -qm 'Ausgangszustand'
}

safe="$work/safe"
new_repo "$safe"
(cd "$safe" && tool/repo_privacy_check.sh >/dev/null)

email_repo="$work/email"
new_repo "$email_repo"
address="$(printf '%s@%s' real.person private-domain.test)"
printf '%s\n' "$address" >"$email_repo/private.txt"
git -C "$email_repo" add private.txt
if output=$(cd "$email_repo" && tool/repo_privacy_check.sh 2>&1); then
  echo 'Klein geschriebene Adresse wurde nicht abgelehnt.' >&2
  exit 1
fi
if [[ "$output" == *"$address"* ]]; then
  echo 'Datenschutzprüfung hat den Fundwert ausgegeben.' >&2
  exit 1
fi
git -C "$email_repo" commit -qm 'Prüffall'
rm "$email_repo/private.txt"
git -C "$email_repo" add -u
git -C "$email_repo" commit -qm 'Prüffall entfernt'
if (cd "$email_repo" && tool/repo_privacy_check.sh >/dev/null 2>&1); then
  echo 'Adresse in der Historie wurde nicht abgelehnt.' >&2
  exit 1
fi

secret_repo="$work/secret"
new_repo "$secret_repo"
secret="ghp_$(printf 'A%.0s' {1..36})"
printf '%s\n' "$secret" >"$secret_repo/credential.txt"
git -C "$secret_repo" add credential.txt
if output=$(cd "$secret_repo" && tool/repo_privacy_check.sh 2>&1); then
  echo 'Zugangsdatenmuster wurde nicht abgelehnt.' >&2
  exit 1
fi
if [[ "$output" == *"$secret"* ]]; then
  echo 'Datenschutzprüfung hat Zugangsdaten ausgegeben.' >&2
  exit 1
fi

echo 'Repository privacy check tests passed.'
