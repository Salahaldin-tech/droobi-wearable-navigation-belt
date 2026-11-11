# Droobi Navigation Engine V3 — Baseline and Execution Log

## Branch and immutable baseline

- Working branch: `v3`
- Base branch: `merge/engine-v2-with-brand-theme`
- Base commit: `822d16db6e13c67abe52f4b5a10a98449d8af42d`
- This branch was created directly from that ref. No application source files have been changed in this initial baseline commit.
- The branch preserves the brand theme and firmware as they existed at the selected base.

## Non-negotiable product constraints

- Phone held forward in the user's hand; phone is the navigation brain.
- No external IMU. Do not introduce direct accelerometer/gyroscope navigation dependencies without an explicit decision.
- Campus routing must use the approved QGIS pedestrian network; do not fabricate walkable connectors.
- When location or heading confidence is inadequate, suppress decisive guidance and command belt STOP.
- ESP32 belt is feedback-only. Preserve BLE STOP, heartbeat, watchdog and motor driver power constraints.
- Keep brand palette and fonts unchanged.

## Baseline audit — source branch

### Campus assets
The selected branch contains:
- `docs/campus-mapping/nodes.geojson`
- `docs/campus-mapping/edges.geojson`
- No `.qgz` or `.gpkg` file was present anywhere in the recursive tree returned for this branch.
- The campus mapping README labels the GeoJSON as a test snapshot, not an approved production network.

### Observed GeoJSON integrity issues
The bundled 14 point features / 7 line features require a normalized data contract before graph construction:
- Node IDs include `j2`, while edge references use alternate legacy names such as `J001`, `E002`, `ENT002`, `ENT003`, `J002`, and `ARTS DOOR 1`.
- Some edge `from_node` / `to_node` properties are null or empty.
- ED003 has a leading whitespace in its edge ID.
- The edge attribute references do not consistently match node `node_id` values.
- All current edge features are marked bidirectional; this is a source policy that must be confirmed for the approved map, not generalized automatically to future edits.
- The current map README states that Gate 1 lies approximately 144.29 m from the nearest mapped edge in this snapshot. No straight-line route connector should be added to compensate.

Physical topology has been described by the project owner as correctly drawn. V3 must preserve surveyed geometry and node locations; it should repair and validate software references without redrawing or moving features unless separately authorized.

### University destinations
- The University screen loads GeoJSON nodes.
- It still uses hardcoded presentation lists for colleges/gates/facilities.
- A node-ID mapping exists for a limited subset, but fallback name/alias matching against Firestore still supplies coordinates for unmapped entries.
- Cafeteria candidate selection uses C1/C2/C3 coordinates.
- V3 requirement: all navigable University destinations must resolve to verified GeoPackage/approved network node IDs; no Firestore or hardcoded coordinate fallback. An unmapped destination must be shown unavailable rather than routed to an approximate coordinate.

### Router
The existing CampusGraphRoutingService:
- Builds graph connectivity from shared edge geometry coordinates, not semantic node references.
- Treats all segments as bidirectional.
- Uses up to eight nearest edge-feature snap candidates and shortest route length to select a pair.
- Includes straight-line origin-to-network and network-to-destination connectors in its generated polyline.
- Uses a fixed 45 m snap maximum.
These behaviors are not sufficient for safe production guidance and are to be replaced by validated semantic graph construction and confidence-aware map matching.

### Navigation engine
The existing NavigationService:
- Starts route calculation, then obtains a stable initial compass heading.
- Updates navigation on compass and GPS callbacks, so guidance can be recalculated using stale GPS.
- Uses compass smoothing and direction confirmation, and has campus reroute logic after two accepted off-route GPS fixes.
- Arrival requires distinct GPS fix timestamps, but V3 still needs route-progress-aware, latched arrival and deterministic state transitions.
- Existing LocationFix carries only position, accuracy and timestamp; preserve available speed/course from Geolocator where supported.

### Haptics / BLE / firmware
- Current BLE command protocol: F, B, L, R, FL, FR, BL, BR, ARRIVED, STOP; heartbeat is HB.
- Firmware watchdog is 10 seconds; direction pattern is 3 seconds ON / 10 seconds OFF; arrival pulse is 1200 ms.
- Preserve STOP semantics and verify the bridge never transmits a stale direction during uncertain, recovering, stopped, or arrived transitions.
- Do not power motors from ESP32 3.3V; GPIOs are driver inputs.

## V3 target architecture and work phases

1. **Checkpoint and trace instrumentation**
   - Preserve base commit and add structured diagnostic trace records.
   - Trace timestamps, GPS fix (accuracy/speed/course), compass heading, chosen edge/segment, snap distance/confidence, cross-track, route progress, state, cue and BLE send result.
   - Never log sensitive identifiers or unnecessary personal data.

2. **Map contract and validator**
   - Treat QGIS GeoPackage as authoritative source; use only a current approved export.
   - Validate schema, unique IDs, valid WGS84 export coordinates, node references, geometry endpoints, edge lengths, directionality, access, and connected components.
   - Keep node and edge geometries unchanged.
   - Require an explicit audited mapping from legacy aliases to canonical node IDs; do not infer IDs from approximate spatial proximity without review.
   - Make map status/version visible in diagnostics.

3. **University destination repository**
   - Load destinations from the validated map dataset.
   - Use stable node IDs as identity; labels/translations/categories are presentation metadata only.
   - Remove Firestore coordinate fallback and all hardcoded coordinate fallback.
   - Represent multiple entrances as node candidates under one destination, but pick the entrance by graph route cost and accessibility policy.
   - Fail closed for unmapped/unverified destinations.

4. **Graph router V3**
   - Build graph from semantic node references and validated edge endpoints.
   - Insert edge interior vertices as shape geometry while retaining node identity at endpoints.
   - Respect one-way/bidirectional properties.
   - Snap GPS to graph segments using distance, reported accuracy, temporal continuity, route context, and valid motion course when available.
   - Never select a farther edge solely because it yields a shorter route.
   - No free-space straight connectors across unmapped areas. A controlled gate-to-path access connector is allowed only when explicitly mapped/verified as traversable.
   - Reject ambiguous/low-confidence snaps.

5. **GPS quality engine**
   - Keep raw and accepted fixes plus speed/course/accuracy/time.
   - Reject stale, duplicate, out-of-order, impossible-jump and poor-accuracy fixes.
   - Compare smoothing filters on deterministic traces; do not tune from intuition alone.

6. **Route progress V3**
   - Track segment/edge identity, projected position, along-route progress, cross-track error, remaining distance and confidence.
   - Use a metre/time/speed-aware local search window and constrain backward progress unless evidence supports it.
   - Never jump to a geometrically nearby but topologically unrelated route segment.

7. **Navigation state machine**
   - Explicit states: Initializing, Navigating, PositionUncertain, OffRoute, Approaching, ArrivalCandidate, Arrived (latched), Recovery, Stopped.
   - Run guidance decisions on a fixed policy tick; sensor updates feed the policy but do not independently publish a cue from stale data.
   - PositionUncertain suppresses directional commands and sends STOP.
   - OffRoute requires persistent independent GPS evidence and map-match confidence.

8. **Direction engine**
   - Compute direction from route tangent at look-ahead target, not a straight-line vector to destination.
   - Compare route bearing to phone compass heading.
   - Use empirically justified deadband, hysteresis and minimum cue hold time.
   - Do not apply arbitrary compass bias. Learn offsets only from reliable straight-walking course evidence if the product owner approves.
   - No direct phone IMU navigation input without explicit approval.

9. **Arrival and haptic events**
   - Arrival combines entrance proximity, route progress, GPS quality and independent fixes.
   - Arrived remains latched until navigation is explicitly stopped/reset; never emit reverse guidance after arrival.
   - Haptics are event/state-based, not continuous. STOP on uncertain GPS, failed route, recovery, disconnect, and stale guidance.
   - Keep firmware command/protocol unchanged unless a separately reviewed change is necessary.

10. **Validation and field acceptance**
    - Unit tests: graph topology, alias mapping, one-way edges, snap confidence, route progress monotonicity, stale fixes, heading deadband, state transitions, arrival latch, BLE fail-safe.
    - Route scenarios: Gate 3–Cafeteria, Gate 3–IT, Cafeteria–IT both ways, C1/C2/C3, Gate 1 only after verified route coverage, intersections, poor GPS, off-route/re-entry, overshoot.
    - Measure map-match error, edge accuracy, wrong-cue changes, reroutes, arrival error, latency, and BLE stop reliability.
    - Do not declare navigation safe or successful based on unit tests alone; supervised physical field testing is mandatory.

## Execution status

- [x] Created `v3` from the exact requested branch and commit.
- [x] Inspected current map, University screen, router, navigation service, route progress, BLE bridge and firmware.
- [x] Recorded baseline and safety constraints.
- [ ] Import/verify the latest approved QGIS export (the selected branch currently has only GeoJSON exports; no QGZ/GeoPackage).
- [ ] Implement map validator and canonical node mapping.
- [ ] Implement semantic graph router and destination repository.
- [ ] Implement trace logger, GPS/map-match confidence, fixed-tick state machine, route progress, direction and arrival changes.
- [ ] Run `dart format`, `flutter analyze`, and `flutter test` in a Flutter SDK environment.
- [ ] Supervised device/field validation.

## Validation limitation

This GitHub editing session can read and write repository files but does not provide a local Flutter SDK/device runtime. No test or analyzer result should be represented as passing until run in CI or a local Flutter environment.
