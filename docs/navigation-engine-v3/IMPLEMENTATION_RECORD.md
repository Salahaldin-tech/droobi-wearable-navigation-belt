# Droobi Navigation Engine V3 — Implementation Record

## Branch baseline

- Working branch: `feature/navigation-engine-v3-clean`
- Base branch: `merge/engine-v2-with-brand-theme`
- Base commit: `822d16db6e13c67abe52f4b5a10a98449d8af42d`
- This branch was created from the exact base commit and does not inherit the previous experimental `v3` branch.
- QGIS source: `main` commit `9787d1801f132eebc7344e75e598f179ade7152a`.

## User-defined implementation constraints

- The phone is held forward and is the navigation brain.
- No external IMU and no new direct accelerometer/gyroscope navigation integration.
- Use the existing phone compass interface only.
- The belt remains feedback-only.
- Use event/state-based haptics; STOP on uncertain state.
- Preserve the two-color theme and fonts from the base branch.
- Do not run, launch, simulate, benchmark, test, format, analyze or inspect the application on the user's behalf. The user will perform application and route trials.

## Source map

The native QGIS project and GeoPackage are included in the branch without changing source geometry or IDs. The project-relative GeoPackage path is supported by a byte-identical copy under `assets/campus_map_v3/data/`.

Canonical counts:
- 28 nodes
- 20 edges
- 7 buildings
- 16 barriers

The `nodes` layer is the sole destination coordinate source. The older duplicate `campus_network` point layer is not used.

Detailed data facts and known limitations are recorded in `docs/campus-mapping/CAMPUS_MAP_V3_AUDIT.md`.

## Implementation completed

### A. Map data pipeline
- Added WGS84 GeoJSON exports of the canonical nodes, edges, buildings and barriers.
- Added a repeatable Python exporter operating directly on the GeoPackage.
- Added explicit node-reference aliases. Source IDs and geometry are preserved.
- Added a map source manifest and topology notes.

### B. University destination resolution
- The University screen loads only `nodes_v3.geojson`.
- Removed the Firestore provider dependency and fuzzy name fallback from the University screen.
- Spatial destinations resolve through explicit QGIS `node_id` mappings.
- Cafeteria selection supplies C1/C2/C3 entrance alternatives to the navigation engine; the engine selects among reachable routes.
- The current mapped destinations include G1/G2/G3, IT1, AR1, E1, C1/C2/C3 and AMS_A.
- MED and AMS_B remain unavailable because their source path fragments are disconnected from the main pedestrian network.
- The existing University page styling and brand palette are preserved.
- The legacy `UniversityLocation.fromFirestore` factory remains only for other existing Firebase consumers; the University screen does not use it.

### C. Campus graph router
- Builds graph connectivity from canonical QGIS `from_node` / `to_node` IDs; interior vertices are private to each Edge, so coordinate coincidence cannot join separate Edges.
- Validates edge references against source nodes and explicit aliases.
- Attaches line endpoints to their declared node only when the offset is at most 5m; offsets above 0.2m become explicit connector geometry and warnings, while larger offsets fail graph loading.
- Current `main` source includes Gate 1 as `G1` and edge `ED08` (`J90_3` → `G1`); the previously reported 144.4m nearest-path distance is not supported by this dataset snapshot.
- Corrects reversed LineString orientation in memory when endpoint geometry proves that orientation is reversed.
- Respects source `bidirectional` flags.
- Uses one nearest snap per edge with separate conservative limits for GPS and destination.
- Rejects ambiguous snaps across disconnected components.
- Does not add the raw GPS coordinate or raw destination coordinate to the walking polyline.
- Exposes graph metadata and warnings for unverified map features.

### D. GPS quality
- `LocationFix` retains OS-reported speed, GPS course and course accuracy.
- The GPS filter rejects invalid accuracy, stale/future readings, duplicate/out-of-order timestamps, implausible jumps and implausible reported speed.
- Accepted GPS events record inter-fix timing in the trace; the actual device cadence remains unmeasured until a user field capture.
- The position smoother preserves speed/course metadata.
- No direct accelerometer or gyroscope navigation dependency was introduced.

### E. Route progress
- Caches cumulative route distance.
- Performs a metre-based local route search whose backward/forward windows respond to GPS accuracy and speed.
- Keeps accepted progress monotonic during small GPS retreats.
- Flags unexpected large progress jumps so they do not silently skip route sections.

### F. Navigation state machine and direction policy
- Guidance decisions run on a fixed 500 ms policy timer.
- GPS and compass callbacks update data; they do not issue direction decisions directly.
- Added PositionUncertain, OffRoute, Approaching and ArrivalCandidate states.
- Stale or poor-quality GPS, stale/failed compass, map-match failures, progress jumps and missing route bearings suppress directional guidance.
- Initial compass qualification now collects at least 12 samples over at least 1s and requires a circular resultant vector of 0.95; sample count, window and resultant are recorded.
- Compass declination correction is configurable but remains 0° by default until a device/location-specific WMM or field calibration value is supplied.
- Route tangent bearing is required; the GPS-to-target bearing fallback was removed.
- Direction changes require repeated policy observations and a minimum confirmation interval. The previous haptic direction is not retained while a new turn is pending.
- Arrival confirmation requires three distinct GPS fixes, with a 1s minimum and 20s maximum spacing between counted fixes.
- Arrival evidence includes a bounded 20m along-route endpoint-overshoot check, so a slow GPS cadence does not automatically keep guiding the user beyond the entrance.
- Campus rerouting uses the current GPS fix and the same mapped pedestrian graph; failure to reconnect ends navigation safely.

### G. Belt safety
- The BLE bridge sends direction only in Navigating and Approaching.
- All other states send STOP.
- Arrival feedback is one-shot.
- Reconnect reasserts the current safe command rather than replaying an old direction.
- The existing BLE protocol and firmware motor patterns were not changed.

### H. Navigation trace
- Added a bounded in-memory trace logger.
- Captures accepted GPS quality metadata, compass heading, selected route metadata, route progress, state transitions, reroute results and belt commands.
- Exact latitude/longitude values are not recorded by default.
- Trace data can be exported as JSON Lines through `NavigationService.traceLogger`.

## Not performed

- No application launch or app inspection.
- No route simulations, path checks, benchmarks, tests, Flutter analyzer, formatter or app build.
- No GitHub Actions workflow was added to launch or test the app.
- No physical GPS/compass/belt or field trials were performed.

## Remaining implementation work

1. Integrate barrier and accessibility constraints only after source attributes and their operational meaning are formally defined; current barrier labels/access values are inconsistent.
2. Complete missing destination mappings only when node IDs and connected paths are present in the QGIS source.
3. Review endpoint attachment warnings in QGIS and verify each short node connector is physically walkable; the source map remains `verified=false`.
4. Supply the campus/device-specific magnetic declination or measured heading offset; no unverified fixed +5° correction is applied.
5. Define and integrate barrier/accessibility semantics after the source barrier attributes are normalized; barrier geometry is exported but not yet used to block edges.
6. Use user-owned trace captures to validate GPS cadence and tune compass deadband, turn confirmation, GPS windows, off-route thresholds and arrival hysteresis.
7. Run the user's own phone and ESP32 field trials; report field readiness only after those trials.

No application or route test results are claimed in this record.
