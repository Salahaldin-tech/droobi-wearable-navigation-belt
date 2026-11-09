# Navigation Engine V2 — Implementation Status

## Working branch and recovery point

- Recovery branch: `checkpoint/droobi-current-state-2026-11-09`
- Recovery commit: `c17216d2a9af6597d591d2cd226d1de46ef9202a`
- Working branch: `work/engine-v2-improvements`
- Base: the checkpoint above, which points to the existing `feature/navigation-engine-v2` implementation.
- Do not commit implementation changes to the recovery branch.

## Architecture decision: all campus edges are bidirectional

Every QGIS edge is treated as bidirectional by the routing engine, regardless of the source feature's previous `bidirectional` value. The current `edges.geojson` also marks all seven edge features as `bidirectional: true`.

## Work completed

### 1. Stable initial compass heading

- Added `CompassService.getStableHeading()`.
- Collects at least eight readings over a minimum 400 ms sampling window.
- Calculates a circular mean, so readings around 359°/0° are averaged correctly.
- Rejects a low resultant-vector score instead of publishing an unreliable initial direction.
- Navigation startup now waits for this stable heading before issuing its first cue.
- Added unit tests for north-boundary averaging, unstable samples, and minimum sample count.

### 2. QGIS graph routing

- Every edge segment is inserted into the graph in both directions.
- Origin and destination snaps are attached in both directions.
- The router evaluates multiple nearby edge candidates rather than only the single closest segment.
- Candidate snaps are grouped by QGIS edge feature so many adjacent vertices from one road do not crowd out nearby alternative roads.
- Added explicit failure categories in the error message:
  - `GPS_SNAP_ORIGIN`
  - `GPS_SNAP_DESTINATION`
  - `GRAPH_CONNECTIVITY`
- Added a reverse-route test that traverses the network from the Engineering entrance back toward Gate 3, including ED006.
- Added a Gate 1 coverage diagnostic test.

### 3. QGIS connectivity and destinations

- Static graph inspection of the current seven edge features found 123 coordinate nodes and one connected component when shared coordinates are keyed to six decimal places.
- All seven edge features are marked bidirectional.
- Gate 1 remains outside the mapped path coverage: its nearest current edge is ED002 at approximately 144.29 m, while the snapping limit is 45 m.
- Do not invent a straight-line connector for Gate 1. A real pedestrian path must be surveyed/drawn in QGIS and validated before it is added.
- The existing NavigationService already evaluates supplied campus destination candidates and chooses the shortest reachable route. The actual entrance coordinates still need field verification.

### 4. Arrival detection

- Existing Engine V2 arrival logic requires three distinct GPS fixes; compass callbacks do not count as independent arrival evidence.
- It checks proximity to the destination/route endpoint and remaining route distance.
- On successful route replacement during off-route recovery, arrival confirmation is now reset so samples from the old route cannot complete arrival on the new route.
- The thresholds were not reduced without field evidence; early arrival is a safety risk.

### 5. Guidance look-ahead

- Slightly reduced the adaptive target distances:
  - Very close turn: 3.5 m minimum (previously 4 m).
  - Turn within 15 m: 4.5 m (previously 5 m).
  - Turn within 25 m: 6.5 m (previously 7 m).
  - Straight sections: 7.5 m default, 9 m maximum (previously 8 m default, 10 m maximum).
- Added unit tests for a near turn and a straight route.
- This is a conservative software adjustment and still requires walking tests.

### 6. Off-route recovery and ESP32/BLE

Static review found the existing Engine V2 implementation already includes:
- Campus off-route detection after two accepted GPS fixes, with a 5-second reroute cooldown.
- A stop/error state if a replacement campus route cannot be calculated, rather than continuing stale directions.
- BLE heartbeat every 2 seconds, below the firmware's 10-second watchdog.
- Firmware direction cycle of 3 seconds ON / 10 seconds OFF.
- STOP behavior for GPS/route failure and BLE disconnect; reconnect sends the current direction only if navigation is actively running.

No firmware or BLE protocol changes were made in this pass because the current implementation already contains these safeguards. Physical verification on the actual phone, ESP32, driver, and motors is still required.

## Validation status

- GitHub source and branch changes were inspected after writing.
- QGIS coordinate connectivity was independently recalculated from the current GeoJSON: 7 edges, 123 coordinate nodes, 1 connected component.
- Gate 1 nearest-edge distance was recalculated from the current GeoJSON: 144.29 m to ED002.
- Unit tests were added/updated but have **not been executed** in a Flutter SDK environment during this session. Do not treat them as passing until `flutter test` and `flutter analyze` run locally or in CI.
- Device-level compass, walking, arrival, off-route, BLE reconnect, and motor-pattern tests remain pending.

## Next safe steps

1. Run `flutter format` on changed Dart files, then `flutter analyze`.
2. Run `flutter test`.
3. Fix any compile/analyzer/test failures before field testing.
4. Field-test initial heading, route snapping, reverse ED006 traversal, cafeteria entrances, arrival, and off-route recovery.
5. Survey the actual pedestrian route to Gate 1 and update QGIS geometry only from verified field data.
6. Test BLE reconnect and motor timing on the physical belt.
