# Droobi Campus Navigation — OSM + Campus OSRM (foot profile)

## Runtime source of campus destinations

The University screen now loads current entrance nodes directly from OpenStreetMap through the Overpass API:

`https://overpass-api.de/api/interpreter`

It queries OSM nodes tagged with `entrance=*` inside the Arab American University campus bounding box. The app reads each node's live latitude/longitude and relevant tags, including `destination_key`, `ref`, `name`, `entrance`, and `access`.

The app does not use Firestore latitude/longitude values as a fallback for University navigation. It also does not use the bundled `aaup-campus-entrances.geojson` snapshot as the runtime destination source. If Overpass cannot provide entrance nodes, the University screen shows an error and allows retry; it does not silently navigate to an old stored coordinate.

The local OSM snapshot and entrance GeoJSON remain in the repository as mapping/reference artifacts only.

## Destination matching

The University screen keeps human-readable destination names and aliases for its cards. These names are labels, not coordinate sources. At selection time, the app matches the selected college/facility to the tags of the current OSM entrance nodes.

Where OSM contains multiple entrance nodes for the same destination key, all matching nodes are passed to campus navigation. Campus routing asks OSRM for a pedestrian route to each candidate and selects the shortest reachable route. The selected entrance becomes the arrival target.

The mapped destination keys currently include:

- `it` — Faculty of Information Technology
- `arts` — Faculty of Arts and Education
- `engineering` — Faculty of Engineering
- `ams_a` — Faculty of Allied Medical Sciences
- `cafeteria` — Cafeteria

Additional college entrances should be mapped in OSM with a consistent `destination_key` (and an `entrance=main` or other suitable `entrance` value) to make them selectable.

## Campus route calculation (corrected in V5)

**Earlier versions of this document were wrong.** They stated that campus navigation used the OSRM `foot` profile on `https://router.project-osrm.org`. That server is OSRM's demo instance and is built with the **car** profile only. OSRM ignores the profile name in the URL: `/foot/`, `/driving/` and even `/xyz/` return byte-identical car routes, with every step reporting `"mode": "driving"`. A V5 audit (2026-11-15) found:

- The tested campus routes used only roads (`unclassified`, `service`, `residential`). None of the 14 campus footways was used.
- The Faculty of IT entrance could not be routed: the nearest car road is 53 m away, while footways pass within 4 m.

Campus routing now works as follows:

- It uses a dedicated OSRM server built from `docs/campus-mapping/osm/aaup-campus.osm` with OSRM's `foot.lua` profile (`scripts/build_campus_osrm.ps1`, `docker-compose.campus-osrm.yml`, port 5001).
- The app gets the server URL at build time: `--dart-define=CAMPUS_OSRM_URL=http://<server>:5001`. If it is missing, campus navigation fails with a clear message; it never falls back to another server.
- Every response must contain steps with `mode: walking`, otherwise it is rejected. A car-profile server can therefore never silently guide a pedestrian along roads.
- The 20 m endpoint snap radius is enforced in the app as well as sent as `radiuses`. The snap distances (`waypoints[].distance`) are kept on the route and shown in debug builds; the route ends that far from the requested entrance.

General (Home) navigation still uses the public demo server. Those routes are car routes.

### Verifying a route

1. Request a route through the API:
   `curl "http://<server>:5001/route/v1/foot/<lon>,<lat>;<lon>,<lat>?overview=full&geometries=geojson&steps=true"`
2. Check the response:
   - every `steps[].mode` is `walking`;
   - the speed (`distance / duration`) is about 4–5 km/h;
   - `waypoints[].distance` is small.
3. To check visually, paste `routes[0].geometry` into geojson.io and compare it with openstreetmap.org (Map Data layer): the line should run along `highway=footway` paths.

### Data freshness

The campus server routes on the bundled OSM snapshot, not live OSM. After editing campus paths in OSM, re-export the snapshot and run `scripts/build_campus_osrm.ps1` again.

## Navigation continuity

A single rejected GPS fix, sudden movement, temporary GPS degradation, compass outlier, or failed reroute must not stop an active navigation session.

Campus GPS filtering is isolated from general navigation. Suspicious fixes are rejected while the last accepted position is retained. If a campus reroute request fails, guidance pauses for that fix and the navigation session remains active so recovery can be retried on a later accepted fix.

## Scope and safety

These changes apply to University/campus navigation. General navigation retains its existing routing provider and separate GPS filter.

An OSM entrance node or successful OSRM route does not prove that a path is physically accessible, unobstructed, or safe for a blind pedestrian. Verify gates, steps, surface, width, slope, temporary closures, and entrance-to-path connections during supervised field testing.

Retain OpenStreetMap attribution and comply with the ODbL when distributing derived data.
