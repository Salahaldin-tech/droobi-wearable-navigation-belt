# Droobi Campus Navigation — Live OSM + Public OSRM

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

## Campus route calculation

Campus navigation uses the public OSRM pedestrian endpoint:

`https://router.project-osrm.org`

The app uses the OSRM `foot` profile and a 20 m endpoint snap radius. No local OSRM server, Docker Desktop, or FOSSGIS endpoint is part of this implementation.

The general navigation provider remains separate and unchanged. Campus navigation receives its own `OsrmRoutingService` instance configured with the same public endpoint.

## Public service freshness and limitations

Overpass reads current OSM database data. OSRM maintains its own imported routing graph, which may not update at the same time as OSM edits. A newly added OSM path can therefore appear in Overpass destination data before it becomes routable through the public OSRM demo service.

A response with `code: Ok` proves that OSRM returned a route, but it does not by itself prove that the route follows the latest campus edits. Inspect route geometry during field testing. The public demo service's availability, request limits, import freshness, and performance are outside this app's control.

The app must not silently switch to a different routing provider or invent a straight-line route when OSRM cannot find a pedestrian route.

## Navigation continuity

A single rejected GPS fix, sudden movement, temporary GPS degradation, compass outlier, or failed reroute must not stop an active navigation session.

Campus GPS filtering is isolated from general navigation. Suspicious fixes are rejected while the last accepted position is retained. If a campus reroute request fails, guidance pauses for that fix and the navigation session remains active so recovery can be retried on a later accepted fix.

## Scope and safety

These changes apply to University/campus navigation. General navigation retains its existing routing provider and separate GPS filter.

An OSM entrance node or successful OSRM route does not prove that a path is physically accessible, unobstructed, or safe for a blind pedestrian. Verify gates, steps, surface, width, slope, temporary closures, and entrance-to-path connections during supervised field testing.

Retain OpenStreetMap attribution and comply with the ODbL when distributing derived data.
