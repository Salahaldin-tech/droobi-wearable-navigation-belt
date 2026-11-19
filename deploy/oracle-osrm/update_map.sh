#!/usr/bin/env bash
# Rebuild the campus OSRM data after a map change has been pushed to GitHub.
#
#   sudo bash update_map.sh
#
# Builds into a fresh folder first, so a failed build leaves the running
# server untouched. If the new data fails a test route, the previous data is
# restored automatically.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo." >&2; exit 1; }

BRANCH="experiment/campus-public-osrm-v5"
OSRM_IMAGE="${OSRM_IMAGE:-ghcr.io/project-osrm/osrm-backend:latest}"
APP_DIR=/opt/droobi
DATA_DIR="$APP_DIR/osrm-data"
NEW="$DATA_DIR.new"
PREV="$DATA_DIR.previous"
TEST_URL="http://127.0.0.1:5000/route/v1/foot/35.3422267,32.4055108;35.34562605184,32.40828122459?overview=false"

healthy() {
  for _ in $(seq 1 30); do
    curl -s "$TEST_URL" | grep -q '"code":"Ok"' && return 0
    sleep 1
  done
  return 1
}

git -C "$APP_DIR/repo" fetch --depth 1 origin "$BRANCH"
git -C "$APP_DIR/repo" checkout -B "$BRANCH" FETCH_HEAD
echo "map commit: $(git -C "$APP_DIR/repo" rev-parse --short HEAD)"

rm -rf "$NEW"; mkdir -p "$NEW"
cp "$APP_DIR/repo/campus-network-map/osrm-5002/aaup-campus.osm" "$NEW/aaup-campus.osm"
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-extract -p /opt/foot.lua /data/aaup-campus.osm
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-partition /data/aaup-campus.osrm
docker run --rm -v "$NEW:/data" "$OSRM_IMAGE" osrm-customize /data/aaup-campus.osrm

rm -rf "$PREV"
mv "$DATA_DIR" "$PREV"
mv "$NEW" "$DATA_DIR"
docker restart droobi-campus-osrm >/dev/null

if healthy; then
  echo "Updated. Previous data kept in $PREV."
else
  echo "New data failed the test route; restoring the previous data." >&2
  rm -rf "$DATA_DIR"; mv "$PREV" "$DATA_DIR"
  docker restart droobi-campus-osrm >/dev/null
  healthy && echo "Previous data restored and serving." >&2
  exit 1
fi
