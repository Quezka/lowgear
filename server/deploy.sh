#!/usr/bin/env bash
# Deploys the Lowgear relay to a Debian/Ubuntu box (e.g. an LXC on the home server).
# Usage: server/deploy.sh root@HOST
# Afterwards: forward UDP 24680 on the router to HOST (Cloudflare tunnels can't carry UDP),
# or have friends join over Tailscale. In the game: Join -> the server's address.
set -euo pipefail
HOST="${1:?usage: server/deploy.sh root@HOST}"
GODOT_VER="4.7.2-stable"
cd "$(dirname "$0")/.."
rsync -az --delete --exclude .git --exclude .godot --exclude export ./ "$HOST:/opt/lowgear/"
ssh "$HOST" bash -s <<REMOTE
set -euo pipefail
id lowgear >/dev/null 2>&1 || useradd --system --create-home lowgear
if ! /usr/local/bin/godot --version 2>/dev/null | grep -q "${GODOT_VER%-stable}"; then
  apt-get install -y -q unzip curl >/dev/null
  tmp=\$(mktemp -d); cd \$tmp
  base=https://github.com/godotengine/godot/releases/download/$GODOT_VER
  curl -fsSLO \$base/Godot_v${GODOT_VER}_linux.x86_64.zip
  curl -fsSLO \$base/SHA512-SUMS.txt
  grep " Godot_v${GODOT_VER}_linux.x86_64.zip" SHA512-SUMS.txt | sha512sum -c -
  unzip -q Godot_*.zip && install -m755 Godot_v${GODOT_VER}_linux.x86_64 /usr/local/bin/godot
fi
chown -R lowgear: /opt/lowgear
sudo -u lowgear /usr/local/bin/godot --headless --path /opt/lowgear --import >/dev/null 2>&1 || true
install -m644 /opt/lowgear/server/lowgear-server.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now lowgear-server && systemctl restart lowgear-server
sleep 2; journalctl -u lowgear-server -n 5 --no-pager
REMOTE
