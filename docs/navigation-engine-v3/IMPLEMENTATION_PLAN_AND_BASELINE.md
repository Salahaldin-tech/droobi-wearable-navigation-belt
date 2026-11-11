# Droobi Navigation Engine V3 — Baseline and Execution Log

## Branch and preserved baseline

- Working branch: `v3`
- Base branch: `merge/engine-v2-with-brand-theme`
- Base commit: `822d16db6e13c67abe52f4b5a10a98449d8af42d`
- V3 was created directly from this commit. The original branch and its theme/firmware remain unchanged.
- The latest QGIS GeoPackage and QGIS project were imported from `main` as map assets only; application code continues to originate from the requested base branch.

## Product and safety constraints

- Phone held forward in the user's hand; phone is the navigation brain.
- No external IMU and no new direct accelerometer/gyroscope navigation dependency.
- The belt is feedback-only. Preserve BLE STOP, heartbeat, watchdog and driver-powered motors.
- No fabricated pedestrian connectors. Low-confidence GPS/compass/map matches suppress direction and send STOP.
- Preserve the exact brand palette and fonts from the base branch.

## Latest QGIS map source

- GeoPackage: `assets/campus_map_v3/campus_network.gpkg`
- QGIS project: `assets/campus_map_v3/AAUP_Campus_Network.qgz`
- Source branch/commit: `main` / `9787d1801f132eebc7344e75e598f179ade7152a`
- Canonical layer counts: 28 nodes, 20 edges, 7 buildings, 16 barriers.
- CRS: EPSG:32636. Runtime exports are WGS84 EPSG:4326.
- The older `campus_network` duplicate points layer is not used; runtime uses `nodes`.
- The source nodes and edges are currently all `verified=false`.
- Geometry connectivity inspection found 3 weak components: one main component with 18 edges, and isolated ED011/ED012. No proximity-based connections are fabricated.
- Explicit edge-reference aliases are documented in `docs/campus-mapping/node_reference_aliases.json`.

Detailed source findings: `docs/campus-mapping/CAMPUS_MAP_V3_AUDIT.md`.

## Implemented on V3

### 1. Map data pipeline and audit
- Imported the latest native GeoPackage and QGIS project from the source branch.
- Exported the canonical nodes, edges, buildings and barriers to WGS84 GeoJSON.
- Added a reproducible standard-library Python exporter.
- Added manifest, alias mapping and source audit.
- Preserved source node IDs, edge IDs and geometry.

### 2. University destination integration
- University screen loads the V3 QGIS node export.
- Firestore coordinate fallback and fuzzy name matching were removed.
- Navigable places resolve only through explicit node IDs.
- Added QGIS-backed entries for Gate 2, Medicine and Allied Medical Sciences.
- Cafeteria and Allied Medical Sciences use their registered entrance alternatives; the route engine chooses among reachable candidates.
- Unmapped destinations remain unavailable rather than using guessed coordinates.

### 3. Campus router V3
- Builds the path graph from shared LineString vertices; validates edge references separately.
- Respects `bidirectional` per edge.
- Corrects reversed edge vertex order in memory only when endpoint geometry proves reversal.
- Chooses the nearest geometric path candidate and rejects ambiguous matches across disconnected components.
- Removes straight-line GPS-to-path and path-to-destination connectors from the pedestrian route.
- Exposes graph diagnostics and warnings for components and unverified features.

### 4. GPS quality and route progress
- LocationFix now retains OS-reported speed, GPS course and course accuracy.
- GPS filter rejects stale, future-dated, duplicate, out-of-order, implausible-jump and poor-accuracy fixes.
- Position smoothing preserves speed/course metadata.
- RouteProgressService precomputes cumulative route distance and uses metre/speed/accuracy-aware local search windows.
- Progress remains monotonic under small GPS retreats and flags large unexpected progress jumps.

### 5. Navigation policy, UI and BLE safety
- Guidance decisions run on a fixed 500 ms policy tick; GPS and compass callbacks update the latest sensor state.
- Added PositionUncertain, OffRoute, Approaching and ArrivalCandidate states.
- Stale/failed GPS or compass, implausible progress jumps and off-route positions suppress directional output.
- Route bearing comes from the route tangent; the direct GPS-to-target bearing fallback was removed.
- Arrival still requires three distinct GPS fixes and a nearly completed route; ArrivalCandidate suppresses direction while confirmation is pending.
- BLE now sends direction only in Navigating/Approaching; every other state sends STOP.
- Arrival pulse is one-shot in the bridge. Firmware protocol/timing was not changed.

### 6. Diagnostic trace
- Added a bounded in-memory trace logger for accepted GPS quality metadata, compass heading and navigation snapshots.
- The trace omits exact latitude/longitude coordinates.
- Export is available as JSON Lines through NavigationService.traceLogger.

## Work remaining

- [ ] Add full deterministic tests for navigation state transitions, arrival latching, BLE fail-safe and map-match edge cases.
- [ ] Run formatter, analyzer and unit tests in GitHub Actions; fix all failures.
- [ ] Audit QGIS project relative datasource paths and verify the project opens against the bundled GeoPackage.
- [ ] Validate destination-node/route endpoint offsets with the map owner; do not bridge them in software.
- [ ] Supervised phone/ESP32/motor field trials for compass stability, route matching, wrong cues, off-route recovery, arrival overshoot and BLE reconnect.
- [ ] Complete field measurements and acceptance thresholds before calling V3 field-ready.

## Validation status

No Flutter analyzer or test results have been claimed yet. CI is being added to execute the real Flutter toolchain against this branch. Even a fully green unit-test run is not a safety certification and does not replace supervised field tests.
