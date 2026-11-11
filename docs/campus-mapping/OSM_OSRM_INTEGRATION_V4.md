# Droobi Campus Navigation — Public OSM + OSRM

## Current decision

Campus Navigation uses the public OpenStreetMap pedestrian data through the public OSRM demo service:

`https://router.project-osrm.org`

The campus route request uses the OSRM `foot` profile and a 20 m endpoint snap radius. No local OSRM server, Docker Desktop, or FOSSGIS endpoint is part of this implementation.

The general navigation provider remains separate and unchanged. Campus navigation receives its own `OsrmRoutingService` instance configured with the same public endpoint.

## Campus map source

The campus entrance anchors are loaded from:

- `docs/campus-mapping/osm/aaup-campus-entrances.geojson`

The OSM snapshot is retained at:

- `docs/campus-mapping/osm/aaup-campus.osm`

The app uses the entrance GeoJSON to locate mapped main doors. OSRM calculates the pedestrian route from the public routing graph; the app does not locally route over the OSM XML snapshot.

The currently mapped main-door anchors include IT, Arts, Engineering, AMS_A, and Cafeteria.

## Public OSRM limitations

The public demo service maintains its own imported OSM dataset. A newly edited way appearing on openstreetmap.org does not prove that it has already been imported by the OSRM demo backend.

Therefore, route geometry must be inspected during the user's field tests. A response with `code: Ok` proves that OSRM returned a route, but it does not by itself prove that the returned route follows the latest campus edits.

The public demo service is operated for demonstration use. Availability, request limits, import freshness, and service performance are outside this app's control. The app must display a clear route/network error when a request cannot be completed; it must not silently switch to a different routing provider.

## Routing behavior

- Use the `foot` profile.
- Send coordinates in OSRM order: longitude,latitude.
- Request full GeoJSON geometry.
- Apply the campus-specific 20 m snap radius.
- Reject empty or malformed route geometry.
- Keep campus routing in its own service instance.
- Keep the existing general routing provider unchanged.
- Do not create a straight-line route when OSRM cannot find a pedestrian route.
- When multiple entrance candidates are supplied, calculate each reachable route and select the shortest valid one.

## Navigation continuity

A single rejected GPS fix, sudden movement, temporary GPS degradation, compass outlier, or failed reroute must not stop an active navigation session.

Campus GPS filtering is isolated from general navigation. Suspicious fixes are rejected while the last accepted position is retained. If a campus reroute request fails, guidance pauses for that fix and the navigation session remains active so recovery can be retried on a later accepted fix.

## Scope

This integration changes campus routing configuration only. GPS filtering and route recovery changes are campus-specific. General navigation behavior and its routing provider must remain unchanged.

No route, sensor, accessibility, or field-safety test is claimed by this document. The user will perform device and campus field testing manually.

## Safety and attribution

A successful OSRM route does not establish that a path is physically accessible, unobstructed, or safe for a blind pedestrian. Verify gates, steps, surface, width, slope, temporary closures, and entrance-to-path connections during supervised field testing.

Retain OpenStreetMap attribution and comply with the ODbL when distributing derived data.
