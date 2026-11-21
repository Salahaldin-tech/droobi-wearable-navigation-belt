# Droobi Campus Navigation — OSM + Campus OSRM (foot profile)

## Current setup (2026-11)

| Part | Where |
|---|---|
| Campus map (edited in JOSM) | `campus-network-map/josm/aaup-campus-edit.osm` |
| Build copy used for routing | `campus-network-map/osrm-5002/aaup-campus.osm` (see `campus-network-map/README.md`) |
| Routing engine | OSRM `ghcr.io/project-osrm/osrm-backend`, stock `/opt/foot.lua`, MLD |
| Server | Oracle Cloud Always Free VM (`VM.Standard.E2.1.Micro`, Ubuntu 24.04, `il-jerusalem-1`) |
| Public endpoint | `https://droobi-campus.duckdns.org` (Caddy, Let's Encrypt) |
| Deployment scripts | `deploy/oracle-osrm/` |
| App configuration | `CAMPUS_OSRM_URL` in `dart_defines.local.json` (see README, "How to Run Droobi") |

```
phone ──HTTPS──> Caddy ──> OSRM 127.0.0.1:5000 (foot profile)
```

The server and the app no longer depend on a development PC.

## Campus destinations

The University screen uses **fixed, hard-coded coordinates** in
`lib/models/campus_destination.dart`. Each one was copied from an entrance node
placed in JOSM, and every node lies on the foot-routable network of the server's
map, so routes end at the entrance itself. The app does not read the OSM file,
OpenStreetMap, Overpass or Firestore at runtime.

- 21 cards are navigable: AMS-A, AMS-B, Arts and Education, Business, DEN-A,
  DEN-B, Engineering, Information Technology, Law, Medicine, Sports Sciences
  (Sports Hall entrance), Gates 1–5, Cafeteria, Administration (Administrative
  Departments Building), Deanship of Admission and Registration, Presidential
  Building, International Soccer Stadium.
- Nursing, Pharmacy, Science and Library have no entrance in the map and show
  "not available yet". No coordinates are invented for them.
- Card names in `university_locations_screen.dart` must match
  `CampusDestination.name` exactly; `test/models/campus_destination_test.dart`
  checks every coordinate and every card.

Each card passes one entrance. The navigation service can also take several
candidate entrances and pick the shortest reachable route, but the University
screen does not currently use that.

`lib/services/routing/campus_osm_entrance_service.dart` (Overpass) is unused and
must not be used: public OpenStreetMap does not contain the local JOSM edits.

## Campus route calculation (corrected in V5)

**Earlier versions of this document were wrong.** They stated that campus
navigation used the OSRM `foot` profile on `https://router.project-osrm.org`.
That server is OSRM's demo instance and is built with the **car** profile only.
OSRM ignores the profile name in the URL: `/foot/`, `/driving/` and even `/xyz/`
return byte-identical car routes, with every step reporting `"mode": "driving"`.
A V5 audit (2026-11-15) found:

- The tested campus routes used only roads (`unclassified`, `service`,
  `residential`). None of the 14 campus footways was used.
- The Faculty of IT entrance could not be routed: the nearest car road is 53 m
  away, while footways pass within 4 m.

Campus routing now works as follows:

- It uses the dedicated campus OSRM server built from the JOSM map with OSRM's
  stock `foot.lua` profile.
- The app gets the server URL at build time (`CAMPUS_OSRM_URL`). If it is
  missing, campus navigation fails with a clear message; it never falls back to
  another server.
- Every response must contain steps with `mode: walking`, otherwise it is
  rejected. A car-profile server can therefore never silently guide a pedestrian
  along roads.
- The 20 m endpoint snap radius is enforced in the app as well as sent as
  `radiuses`. The snap distances (`waypoints[].distance`) are kept on the route
  and shown in debug builds.

General (Home) navigation still uses the public demo server. Those routes are
car routes.

### Walking rules of `foot.lua` on this map

- All road and path types in the map have the same walking speed (5 km/h), so
  the shortest walkable path wins.
- `oneway=yes` is ignored for walking (`oneway_handling = 'specific'`; only
  `oneway:foot` would restrict direction). Routes are the same length in both
  directions.
- `foot=no`, `access=no` and `access=private` exclude a way. Tag the way, not
  its nodes: a node with `foot=no` becomes a barrier.
- The Engineering loop is intentionally walkable.

### Verifying a route

1. Request a route:
   `curl "https://droobi-campus.duckdns.org/route/v1/foot/<lon>,<lat>;<lon>,<lat>?overview=full&geometries=geojson&steps=true"`
2. Check the response:
   - every `steps[].mode` is `walking`;
   - the speed (`distance / duration`) is about 5 km/h;
   - `waypoints[].distance` is small (0 m for the fixed entrances).
3. To check visually, paste `routes[0].geometry` into geojson.io.

Only `GET /route/v1/foot/...` and `/nearest/v1/foot/...` are exposed; other
paths return 404 and OSRM's port 5000 is not reachable from outside.

### Data freshness

The server routes on the committed build copy, not live OSM. After editing the
map in JOSM:

1. Regenerate `campus-network-map/osrm-5002/aaup-campus.osm`
   (`campus-network-map/README.md`).
2. If an entrance moved, update `lib/models/campus_destination.dart` and its test.
3. Push, then on the server run `sudo bash ~/oracle-osrm/update_map.sh`. It
   builds into a new folder and restores the previous data if the new data fails
   a test route.

### Local test server (optional)

A server on the development PC is still useful for testing map edits before
deploying. Build `campus-network-map/osrm-5002` with the commands in
`campus-network-map/README.md` and run it on port 5002, then point a test build
at `http://<PC-LAN-IP>:5002`. The older `scripts/build_campus_osrm.ps1` and
`docker-compose.campus-osrm.yml` build the previous V5 snapshot
(`docs/campus-mapping/osm/aaup-campus.osm`, port 5001), which does not contain
the new entrances.

## Navigation continuity

A single rejected GPS fix, sudden movement, temporary GPS degradation, compass
outlier, or failed reroute must not stop an active navigation session.

Campus GPS filtering is isolated from general navigation. Suspicious fixes are
rejected while the last accepted position is retained. If a campus reroute
request fails, guidance pauses for that fix and the navigation session remains
active so recovery can be retried on a later accepted fix.

## Scope and safety

These changes apply to University/campus navigation. General navigation retains
its existing routing provider and separate GPS filter.

An OSM entrance node or successful OSRM route does not prove that a path is
physically accessible, unobstructed, or safe for a blind pedestrian. Verify
gates, steps, surface, width, slope, temporary closures, and entrance-to-path
connections during supervised field testing.

Retain OpenStreetMap attribution and comply with the ODbL when distributing
derived data.
