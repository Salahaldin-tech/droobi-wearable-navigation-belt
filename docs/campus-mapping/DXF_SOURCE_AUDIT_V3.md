# DXF Source Audit — Campus Navigation V3

## File inspected

- File: ماستر بلان2.dxf
- Format: AutoCAD DXF R14 / AC1015
- Size: 11,436,474 bytes
- DXF modelspace entities: 13,702
- No source geometry was modified during inspection.

## Coordinate-system findings

The DXF does not provide enough embedded metadata to declare its CRS conclusively:

- $INSUNITS is absent.
- No GEODATA entity was found.
- The file's $EXTMIN is approximately X=182225.579, Y=201062.231.
- The file's $EXTMAX is approximately X=182921.179, Y=201957.831.
- $MEASUREMENT is 1, but this alone is not proof of a particular coordinate reference system or linear unit.

A diagnostic transformation of the drawing bounds from EPSG:28191 (Palestine Grid) to WGS84 produces an approximate extent:

- southwest: latitude 32.403434, longitude 35.340178;
- northeast: latitude 32.411502, longitude 35.347584;
- drawing center: latitude 32.407468, longitude 35.343881.

This places the transformed extent in the vicinity of the Arab American University Jenin campus. It makes EPSG:28191 a plausible working hypothesis, not a confirmed CRS. The transformation must be checked against several independent control points before any OSM/DXF merge or routing export.

A public OSM-derived listing places the university node at approximately 32.40816, 35.34251 (OSM node 431717960). This is a useful candidate control point, but a campus label point is not necessarily a surveyed point represented in the DXF. It must not be used as the only georeferencing control.

## Entity inventory

Modelspace entity counts:

| Entity type | Count |
|---|---:|
| LWPOLYLINE | 4,111 |
| TEXT | 2,260 |
| LINE | 1,973 |
| INSERT | 1,728 |
| CIRCLE | 1,679 |
| ACAD_PROXY_ENTITY | 1,206 |
| ARC | 328 |
| POLYLINE | 241 |
| MTEXT | 114 |
| HATCH | 43 |
| DIMENSION | 15 |
| SPLINE | 4 |
| **Total** | **13,702** |

Potentially useful layers (these are candidates, not yet approved routing geometry):

| Layer | Entities | Initial interpretation / review need |
|---|---:|---|
| BUILDING | 297 | Building outlines; distinguish closed footprints from construction/detail lines |
| GATE | 5 | Candidate gate geometry; verify which entities define actual passable openings |
| STAIR | 1,439 | Stair detail; not automatically an accessible pedestrian path |
| RAMP | 13 | Candidate ramps; verify continuity, slope, and endpoints |
| PARKING | 409 | Parking geometry; may help identify circulation areas but not all lines are walkable |
| TRAV | 105 | Contains labels such as B1, B2, U-16 and elevation-like values; semantic meaning must be confirmed |
| CWALL | 1,609 | Wall geometry; likely useful for barriers, but entity semantics and continuity need review |
| FENCE | 34 | Candidate barriers/boundaries |
| HOUSE | 198 | Mixed geometry and hatches; inspect before interpreting as buildings |
| CW | 155 | Mixed line/arc/spline geometry; meaning not confirmed |
| CS | 648 | Mixed geometry; meaning not confirmed |
| GRIL | 251 | Candidate grille/fence details; meaning not confirmed |
| ZENK | 140 | Meaning not confirmed |
| LS | 120 | Meaning not confirmed |
| AS | 28 | Meaning not confirmed |

The GATE layer contains one LWPOLYLINE and four LINE entities. It does not yet establish five distinct gates. The layer must be interpreted geometrically and checked against OSM/field evidence.

The HOUSE layer includes a HATCH whose reported bounding extent reaches X≈172467 while the main drawing extent begins at X≈182225. This is a large outlier and should be investigated as a possible malformed hatch boundary or stray geometry. Do not let this entity define the campus AOI.

## OSM-first workflow implications

- Use Overpass to obtain an immutable, timestamped OSM snapshot for the verified campus AOI.
- Use JOSM to inspect OSM objects and tags; do not treat a partial Overpass download as a complete editable OSM dataset.
- Keep DXF-derived candidates in a separate project-owned layer until georeferencing, access, and source rights are confirmed.
- Do not upload imported DXF content to OSM as a bulk import.
- Build the pedestrian graph only from verified walkable paths and actual junctions, gates, and entrances.

## Next required actions

1. Confirm the DXF's intended coordinate system and units from the drawing provider or authoritative metadata.
2. Identify at least three well-distributed control points that can be matched unambiguously between the DXF and trusted geographic data. Prefer more than three and check residuals.
3. Verify the transformation using independent check points not used to fit it.
4. Inspect the BUILDING, GATE, RAMP, STAIR, PARKING, CWALL, and FENCE layers in detail.
5. Only after CRS approval, define the Overpass AOI and extract OSM roads, footways, buildings, entrances, and relevant campus features.

## Audit status

**Preliminary inspection complete; CRS not confirmed; OSM extraction and graph construction intentionally not started.**
