#!/bin/sh
# Builds the Linux server bundle for an LXC container (no Docker needed in
# the container): build/sixora-server-<version>-linux-<arch>.tar.gz
#
#   deploy/lxc/build_bundle.sh [x64|arm64]     (default: x64)
set -eu
cd "$(dirname "$0")/../.."
ARCH="${1:-x64}"
case "$ARCH" in
  x64) PLATFORM=linux/amd64 ;;
  arm64) PLATFORM=linux/arm64 ;;
  *) echo "Unknown architecture: $ARCH" >&2; exit 64 ;;
esac
VERSION=$(sed -n "s/^const serverVersion = '\(.*\)';/\1/p" server/lib/src/server_app.dart)
OUT="build/sixora-server-$VERSION-linux-$ARCH"
rm -rf "$OUT" && mkdir -p "$OUT"
docker build --platform "$PLATFORM" --target bundle --output "type=local,dest=$OUT" .
# No macOS extended attributes in the archive (GNU tar warns about them).
COPYFILE_DISABLE=1 tar --no-xattrs -czf "$OUT.tar.gz" -C "$OUT" bundle
rm -rf "$OUT"
echo "$OUT.tar.gz"
