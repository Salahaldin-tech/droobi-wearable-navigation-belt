# OSM Source Audit — AAUP Jenin — 2026-11-11

## Source and provenance

- Source: user-supplied raw Overpass API JSON export.
- Generator: Overpass API 0.7.62.11.
- OSM snapshot timestamp: 2026-11-11T20:13:33Z.
- Query envelope (south, west, north, east): 32.4034, 35.3401, 32.4116, 35.3487.
- License notice in source: © OpenStreetMap contributors, data available under ODbL.
- The original raw export is retained in the conversation attachment. This report records an analysis summary; it is not a substitute for the original OSM data.

## Dataset inventory

- Total returned elements: 196.
- Nodes: 7.
- Ways: 189.
- Relations: 0.
- Elements with tags: 196.

### Main tag inventory

- Highway ways: 77.
  - service: 28 (18 tagged service=parking_aisle)
  - residential: 18
  - unclassified: 12
  - secondary: 6
  - footway: 5
  - tertiary: 4
  - construction: 3
  - track: 1
- Building-tagged elements: 89 (88 ways and 1 node).
  - building=yes: 72
  - building=school: 16
  - building=apartments: 1 node
- Amenity-tagged elements: 22.
- Parking-tagged elements: 17 (amenity=parking, parking=surface).
- Barrier-tagged elements: 2 nodes, both barrier=gate.
- Entrance-tagged elements: 0.
- Explicit highway=steps / stairs-tagged elements: 0.
- No route relations were returned.

## Gate control-point comparison

Two OSM gate nodes are present:

| OSM node | OSM coordinates | Distance from user Gate 3 GPS point |
|---|---|---:|
| 431746995 | 32.4074469, 35.3412570 | ~5.0 m |
| 10003173817 | 32.4073224, 35.3412680 | ~9.1 m |

This is a useful spatial correspondence for the user's Gate 3 area. It does not establish which OSM gate node is the exact physical gate opening; that requires interpretation of the surrounding geometry.

No OSM barrier=gate node was returned close to the user-supplied Gate 5, Gate 1, or Faculty of Arts entrance coordinates. This means those points are not represented as nearby tagged gate nodes in this extract; it does not mean the physical gates/entrance do not exist.

## Pedestrian-network observations

- Only five ways are explicitly tagged highway=footway.
- One way is tagged highway=track.
- 28 service ways are present, including 18 parking aisles; these must not be automatically treated as unrestricted pedestrian paths.
- 3 highway=construction ways are present and must be excluded from normal routing unless their current status is verified.
- The 77 highway ways form one connected component when connected by shared OSM node IDs without access/type filtering. This is only a raw topological observation. It does not prove that a safe, accessible pedestrian route exists between every pair of places.
- The extract contains no explicit entrance=* elements and no explicit steps/stairs features.

## Coverage and query limitations

The query used a bounding-box filter, but Overpass returns full geometry for ways intersecting that box. Some returned way geometries extend outside the requested envelope. Do not treat all returned geometry as belonging to the campus.

The output contains no relations. Campus boundary, building access, pedestrian permissions, crossing safety, and internal path semantics remain incomplete or unverified.

## Recommended reconciliation actions

1. Preserve the raw OSM snapshot unchanged and retain its timestamp and ODbL attribution.
2. Clip a working copy to a verified campus area of interest; do not clip the source archive.
3. Compare the five explicit footways and all candidate service paths with the DXF candidate pedestrian geometry.
4. Review the two OSM gate nodes against the DXF and the user's Gate 3 coordinate.
5. Treat Gate 1, Gate 5, and Faculty of Arts entrance as user-confirmed control points, not as OSM-mapped entrances.
6. Do not automatically route over construction, parking aisles, residential roads, or service roads without access and field validation.
7. Build a pedestrian graph only from verified walkable centerlines and explicit junction connectivity. Do not infer connections from proximity alone.

## Current status

**The user-supplied OSM snapshot has been parsed and audited. It provides useful campus context but sparse explicit pedestrian mapping: five footway ways, two gate nodes, and no entrance-tagged elements. OSM/DXF reconciliation and a routing graph have not yet been completed.**
