#!/bin/sh
# Installs or updates the Sixora server on Debian/Ubuntu (e.g. a Proxmox LXC).
#
#   sh install.sh sixora-server-<version>-linux-x64.tar.gz
#
# Layout: binary in /opt/sixora (previous version in /opt/sixora.old), data
# in /var/lib/sixora, settings in /etc/sixora/sixora.env, systemd unit
# "sixora", admin commands via "sixora-admin". Data and settings survive
# updates.
set -eu

SRC="${1:-}"
[ -n "$SRC" ] && [ -f "$SRC" ] || { echo "Usage: $0 sixora-server-<version>-linux-<arch>.tar.gz" >&2; exit 64; }
[ "$(id -u)" -eq 0 ] || { echo "Please run as root." >&2; exit 1; }
HERE=$(cd "$(dirname "$0")" && pwd)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$SRC" -C "$TMP"
[ -x "$TMP/bundle/bin/server" ] || { echo "Archive does not contain bundle/bin/server" >&2; exit 1; }

id sixora >/dev/null 2>&1 || useradd --system --home /var/lib/sixora --shell /usr/sbin/nologin sixora
install -d -o sixora -g sixora -m 0700 /var/lib/sixora
install -d -m 0755 /etc/sixora
[ -f /etc/sixora/sixora.env ] || install -m 0644 "$HERE/sixora.env" /etc/sixora/sixora.env

systemctl stop sixora 2>/dev/null || true
rm -rf /opt/sixora.new && mkdir -p /opt/sixora.new
cp -R "$TMP/bundle/." /opt/sixora.new/
rm -rf /opt/sixora.old
[ ! -d /opt/sixora ] || mv /opt/sixora /opt/sixora.old
mv /opt/sixora.new /opt/sixora

# Admin commands (invite, users, admin, disable, enable) as the service user.
cat > /usr/local/bin/sixora-admin <<'WRAPPER'
#!/bin/sh
set -a
. /etc/sixora/sixora.env
set +a
exec runuser -u sixora -- /opt/sixora/bin/server "$@"
WRAPPER
chmod 0755 /usr/local/bin/sixora-admin

install -m 0644 "$HERE/sixora.service" /etc/systemd/system/sixora.service
systemctl daemon-reload
systemctl enable --now sixora
sleep 2
if sixora-admin --healthcheck; then
  echo "Sixora is running. The first account to register becomes administrator."
else
  echo "Sixora did not start – see: journalctl -u sixora" >&2
  exit 1
fi
