# Droobi Campus Navigation — OSM + OSRM V4

## Decision

The AAUP campus map exported by the user from OpenStreetMap is the authoritative campus routing source for this branch. The campus graph is no longer loaded from the legacy QGIS `nodes.geojson` / `edges.geojson` assets.

The supplied source snapshot is stored at:

- `docs/campus-mapping/osm/aaup-campus.osm`
- Source format: OpenStreetMap XML
- OSM attribution and ODbL licence metadata are retained in the source file.

The app uses a separate OSRM endpoint for campus navigation. The general routing provider remains separate.

## Why a dedicated OSRM instance is required

The public OSRM demo endpoint is not guaranteed to contain the user's latest AAUP edits. Campus routing must use an OSRM dataset extracted from the exact `aaup-campus.osm` snapshot in this repository.

OSRM's built-in `foot` profile is used. OSRM profiles are applied during data extraction, not per request. Rebuild the OSRM dataset whenever the OSM source snapshot changes.

## Build and run

Requirements: Docker Desktop / Docker Engine.

PowerShell:

```powershell
.scriptsuild_campus_osrm.ps1
docker compose -f docker-compose.campus-osrm.yml up -d
```

Bash / WSL:

```bash
bash scripts/build_campus_osrm.sh
docker compose -f docker-compose.campus-osrm.yml up -d
```

The OSRM HTTP service is exposed on port `5001`.

Health / route smoke test (coordinates are longitude,latitude):

```text
http://127.0.0.1:5001/route/v1/foot/35.3434195,32.4067799;35.3445806,32.4079498?overview=full&geometries=geojson
```

A successful response must contain `"code":"Ok"` and a non-empty route geometry. This smoke test must be run after each rebuild.

## Flutter configuration

The campus OSRM endpoint is supplied at build/run time:

- Android emulator: `--dart-define=CAMPUS_OSRM_BASE_URL=http://10.0.2.2:5001`
- Physical Android phone on the same LAN: `--dart-define=CAMPUS_OSRM_BASE_URL=http://<COMPUTER_LAN_IP>:5001`
- iOS simulator: `--dart-define=CAMPUS_OSRM_BASE_URL=http://127.0.0.1:5001`

Debug Android builds allow local HTTP for this endpoint. Release builds keep cleartext traffic disabled; deploy the OSRM service behind HTTPS before configuring a release build.

Do not use `localhost` from a physical phone; it points to the phone itself. Campus navigation deliberately fails with a configuration error if this endpoint is absent. It must not silently fall back to the public demo or to the old QGIS graph.

The campus OSRM client uses the `foot` route profile and a bounded 20 m snap radius for both endpoints. If OSRM cannot snap an endpoint within this radius, routing should fail rather than inventing a long straight-line connector.

## OSM entrance points

`aaup-campus-entrances.geojson` is a compact app asset generated from the main entrance nodes in the OSM source snapshot. It currently contains the five named main doors:

- IT main door
- Arts main door
- Engineering main door
- AMS_A main door
- cafeteria main door

These are destination anchors. The route itself is computed by OSRM over the OSM pedestrian graph.

Other destinations that do not yet have a mapped OSM entrance may continue to use the existing Firestore location record temporarily; they are still snapped by the campus OSRM endpoint and must pass the 20 m snap limit. Add explicit OSM entrance nodes for these destinations before production use.

## Scope and safety

- This branch changes the campus routing data source and endpoint wiring only.
- It does not redesign compass, GPS filtering, route progress, haptic patterns, or arrival logic.
- No routing result has been field-validated by this commit.
- A successful OSRM route proves graph reachability in the imported OSM data, not that a path is physically accessible, unobstructed, or safe for a blind pedestrian.
- Review access restrictions, steps, surface, width, slopes, gates, temporary closures, and entrance-to-path connections before supervised field testing.
- Preserve OSM attribution and comply with ODbL when distributing derived data.
