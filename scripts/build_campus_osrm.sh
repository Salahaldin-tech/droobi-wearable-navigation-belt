#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSM_DIR="$ROOT_DIR/docs/campus-mapping/osm"
OSM_FILE="$OSM_DIR/aaup-campus.osm"
OSRM_BASE="$OSM_DIR/aaup-campus.osrm"
IMAGE="ghcr.io/project-osrm/osrm-backend:latest"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Desktop and start its engine." >&2
  exit 1
fi

if [[ ! -f "$OSM_FILE" ]]; then
  echo "Missing OSM source: $OSM_FILE" >&2
  exit 1
fi

# OSRM accepts OSM XML directly; no PBF conversion is required.
docker run --rm -t -v "$OSM_DIR:/data" "$IMAGE" \
  osrm-extract -p /opt/foot.lua /data/aaup-campus.osm

docker run --rm -t -v "$OSM_DIR:/data" "$IMAGE" \
  osrm-partition "$OSRM_BASE"

docker run --rm -t -v "$OSM_DIR:/data" "$IMAGE" \
  osrm-customize "$OSRM_BASE"

echo "Campus OSRM dataset prepared from aaup-campus.osm."
echo "Start it with: docker compose -f docker-compose.campus-osrm.yml up -d"
