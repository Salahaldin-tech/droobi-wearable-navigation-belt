$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$OsmDir = Join-Path $RootDir "docs/campus-mapping/osm"
$OsmFile = Join-Path $OsmDir "aaup-campus.osm"
$OsrmBase = "/data/aaup-campus.osrm"
$Image = "ghcr.io/project-osrm/osrm-backend:latest"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is required. Install Docker Desktop and start its engine."
}
if (-not (Test-Path $OsmFile)) {
    throw "Missing OSM source: $OsmFile"
}

# OSRM accepts OSM XML directly; no PBF conversion is required.
docker run --rm -t -v "${OsmDir}:/data" $Image osrm-extract -p /opt/foot.lua /data/aaup-campus.osm
if ($LASTEXITCODE -ne 0) { throw "osrm-extract failed." }

docker run --rm -t -v "${OsmDir}:/data" $Image osrm-partition $OsrmBase
if ($LASTEXITCODE -ne 0) { throw "osrm-partition failed." }

docker run --rm -t -v "${OsmDir}:/data" $Image osrm-customize $OsrmBase
if ($LASTEXITCODE -ne 0) { throw "osrm-customize failed." }

Write-Host "Campus OSRM dataset prepared from aaup-campus.osm."
Write-Host "Start it with: docker compose -f docker-compose.campus-osrm.yml up -d"
