#!/usr/bin/env bash
# Step 3 on the Oracle VM: install Docker, build the campus OSRM data and
# start OSRM (private) + Caddy (public HTTPS).
#
#   sudo bash setup_server.sh droobi-campus.duckdns.org
#
# Run swap.sh and firewall.sh first; this script checks both. It uses the
# same OSRM image, stock foot.lua profile and campus map as the PC's port 5002
# test server (campus-network-map/osrm-5002/aaup-campus.osm). Safe to re-run.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

DOMAIN="${1:?usage: sudo bash setup_server.sh <domain>}"
REPO_URL="https://github.com/Salahaldin-tech/droobi-wearable-navigation-belt.git"
BRANCH="experiment/campus-public-osrm-v5"
OSRM_IMAGE="${OSRM_IMAGE:-ghcr.io/project-osrm/osrm-backend:latest}"
CADDY_IMAGE="caddy:2"
APP_DIR=/opt/droobi
DATA_DIR="$APP_DIR/osrm-data"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_OPTS=(--log-opt max-size=10m --log-opt max-file=3)
ENG="35.34562605184,32.40828122459"   # Engineering main door (lon,lat)
GATE1="35.3422267,32.4055108"         # Gate 1 (lon,lat)

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "== Pre-flight checks"
[ "$(uname -m)" = "x86_64" ] || fail "expected x86_64 (E2.1.Micro), found $(uname -m)."
swapon --show --noheadings | grep -q . || fail "no swap active. Run: sudo bash swap.sh"
if iptables -L INPUT -n | grep -q REJECT; then
  for port in 80 443; do
    iptables -C INPUT -p tcp -m state --state NEW -m tcp --dport "$port" -j ACCEPT 2>/dev/null \
      || fail "port $port is not open in the instance firewall. Run: sudo bash firewall.sh"
  done
fi
[ -f "$SCRIPT_DIR/Caddyfile" ] || fail "Caddyfile not found next to this script."

apt-get update -y
apt-get install -y docker.io git curl ca-certificates
systemctl enable --now docker

# Let's Encrypt allows only a few failed validations per hour, so do not start
# Caddy until the domain really points at this server.
public_ip=$(curl -4 -fsS --max-time 10 https://api.ipify.org) || fail "could not determine this server's public IP."
dns_ip=$(getent ahostsv4 "$DOMAIN" | awk 'NR==1 {print $1}')
[ "$dns_ip" = "$public_ip" ] || fail "$DOMAIN resolves to '${dns_ip:-nothing}', but this server is $public_ip. Fix DuckDNS first."
echo "DNS ok: $DOMAIN -> $public_ip"

echo "== Fetching campus map ($BRANCH)"
if [ -d "$APP_DIR/repo/.git" ]; then
  git -C "$APP_DIR/repo" fetch --depth 1 origin "$BRANCH"
  git -C "$APP_DIR/repo" checkout -B "$BRANCH" FETCH_HEAD
else
  mkdir -p "$APP_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$APP_DIR/repo"
fi
echo "map commit: $(git -C "$APP_DIR/repo" rev-parse --short HEAD)"

echo "== Building OSRM data with $OSRM_IMAGE (stock /opt/foot.lua)"
docker pull "$OSRM_IMAGE"
NEW="$DATA_DIR.new"
rm -rf "$NEW"; mkdir -p "$NEW"
cp "$APP_DIR/repo/campus-network-map/osrm-5002/aaup-campus.osm" "$NEW/aaup-campus.osm"
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-extract -p /opt/foot.lua /data/aaup-campus.osm
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-partition /data/aaup-campus.osrm
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-customize /data/aaup-campus.osrm
rm -rf "$DATA_DIR"; mv "$NEW" "$DATA_DIR"

echo "== Starting OSRM on 127.0.0.1:5000 (not reachable from outside)"
docker rm -f droobi-campus-osrm >/dev/null 2>&1 || true
docker run -d --name droobi-campus-osrm --restart unless-stopped "${LOG_OPTS[@]}" \
  -p 127.0.0.1:5000:5000 -v "$DATA_DIR:/data:ro" "$OSRM_IMAGE" \
  osrm-routed --algorithm mld /data/aaup-campus.osrm --port 5000

for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:5000/nearest/v1/foot/$ENG" >/dev/null && break
  sleep 1
done
route=$(curl -s "http://127.0.0.1:5000/route/v1/foot/$GATE1;$ENG?overview=false")
echo "$route" | grep -q '"code":"Ok"' || fail "OSRM test route failed: $route"
# The first "distance" in the response is the route's; later ones are snaps.
echo "OSRM ok: Gate 1 -> Engineering $(echo "$route" | grep -o '"distance":[0-9.]*' | head -1 | cut -d: -f2) m"

echo "== Starting Caddy (HTTPS for $DOMAIN)"
install -m 644 "$SCRIPT_DIR/Caddyfile" "$APP_DIR/Caddyfile"
docker rm -f droobi-caddy >/dev/null 2>&1 || true
docker run -d --name droobi-caddy --restart unless-stopped "${LOG_OPTS[@]}" \
  --network host -e DOMAIN="$DOMAIN" \
  -v "$APP_DIR/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v droobi-caddy-data:/data -v droobi-caddy-config:/config "$CADDY_IMAGE"

echo "Waiting for the HTTPS certificate (up to 2 minutes)..."
for _ in $(seq 1 24); do
  if curl -sf --max-time 5 "https://$DOMAIN/nearest/v1/foot/$ENG" | grep -q '"code":"Ok"'; then
    echo; echo "SUCCESS: https://$DOMAIN is serving campus walking routes."
    echo "App: flutter run --dart-define=CAMPUS_OSRM_URL=https://$DOMAIN"
    exit 0
  fi
  sleep 5
done
echo "HTTPS not ready yet. Recent Caddy log:" >&2
docker logs --tail 30 droobi-caddy >&2
exit 1
