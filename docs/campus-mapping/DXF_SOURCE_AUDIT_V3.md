# DXF Source Audit — Drawing1.dxf — Campus Navigation V3

## Authoritative file

This audit uses only the newly uploaded `Drawing1.dxf`:

- Size: 11,425,872 bytes
- SHA-256: `96cdeca1fd2d7ed0423e1041fd43f3c57afa54b4fc9c536c34281f24df6132ac`
- DXF version: AC1032 (AutoCAD 2018)
- Modelspace entities: 13,702
- `$INSUNITS = 6`: drawing units declared as meters
- `$EXTMIN = (182225.579473, 201062.231054, 0.0)`
- `$EXTMAX = (183013.207051, 201957.831054, 824.369888)`
- No GEODATA entity found; no explicit CRS/datum identified in the header.

The meter declaration does not identify the CRS. EPSG:28191 (Palestine 1923 / Palestine Grid) is being tested as a candidate, not assumed as fact.

## Modelspace inventory

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

## Relevant layers

| Layer | Entities | Review note |
|---|---:|---|
| MANHOLE | 2,649 | Utility infrastructure, not routing edges |
| TREE | 1,711 | Tree symbols; possible obstacles after interpretation |
| CWALL | 1,609 | Candidate walls/barriers; verify continuity |
| STAIR | 1,439 | Stairs; not automatically accessible |
| V-NODE | 1,206 | Proxy entities; inspect proxy semantics |
| CS | 648 | Meaning unconfirmed |
| POLE | 482 | Site furniture/utility candidates |
| PARKING | 409 | Parking geometry; not all lines are walkable |
| CONT-MJR | 385 | Major contours |
| LEVEL | 315 | Elevation annotations |
| BUILDING | 297 | Mixed outlines and drafting geometry |
| GRIL | 251 | Meaning unconfirmed |
| HOUSE | 198 | Mixed geometry/hatches |
| CW | 155 | Meaning unconfirmed |
| ZENK | 140 | Meaning unconfirmed |
| TRAV | 105 | Mixed geometry and labels |
| BORDER | 76 | Candidate boundaries |
| FENCE | 34 | Candidate fences/barriers |
| RAMP | 13 | Candidate ramps; confirm meaning and continuity |
| GATE | 5 | Four LINE and one LWPOLYLINE; five entities do not necessarily mean five gates |

The RAMP layer has eleven LINE and two LWPOLYLINE entities. The BUILDING layer has 143 LWPOLYLINE, 144 LINE, nine ARC and one POLYLINE. Neither entity count should be interpreted as a count of complete ramps/buildings.

## User-provided geographic control points

The user confirmed this is the Arab American University (AAUP), main campus in Jenin, and supplied WGS84 coordinates:

| Control point | Latitude | Longitude |
|---|---:|---:|
| Gate 3 | 32.40740417658937 | 35.341274899549745 |
| Gate 5 | 32.41068251057309 | 35.3439330384187 |
| Main entrance, Faculty of Arts | 32.407989460739536 | 35.34462720764019 |
| Gate 1 | 32.405534019978944 | 35.342153277196914 |

## EPSG:28191 direct-coordinate test

All four WGS84 points were transformed to EPSG:28191 using a standard coordinate transformation, then compared with actual DXF geometry. This is a direct-coordinate diagnostic, not a fitted transformation.

| Control point | EPSG:28191 X | EPSG:28191 Y | Closest relevant DXF evidence |
|---|---:|---:|---|
| Gate 3 | 182328.232 | 201502.663 | HOUSE line handle 810: 1.52 m; nearby text handle 1878: 8.94 m; nearest GATE-layer line: 39.48 m |
| Gate 5 | 182577.822 | 201866.540 | GATE line handle 382B: 0.57 m; GATE line handle 382C: 1.98 m |
| Faculty of Arts main entrance | 182643.514 | 201567.977 | STAIR line handle 1717: 0.30 m; BUILDING line handle 1719: 1.56 m |
| Gate 1 | 182411.132 | 201295.377 | HOUSE polyline handle 896: 2.00 m; nearby text handle 185B: 7.86 m; nearest GATE-layer line: 262.45 m |

The nearby gate-label text strings on DXF layer `1` appear as `f,hfm vrL 3`, `f,hfm vrL 5`, and `f,hfm vrL 1` in the parsed text. This is likely an encoding/font rendering issue; it is not treated as a verified semantic label without decoding/author confirmation.

### Interpretation

- The four user-provided points fall close to plausible local DXF features under EPSG:28191: approximately 0.30–2.00 m for the nearest candidate geometry.
- Gate 5 has a particularly strong correspondence with the GATE layer (0.57 m to handle 382B).
- Gate 3 and Gate 1 do **not** coincide with the remaining entities in the GATE layer. Their closest geometry is on other layers, so the GATE layer must not be treated as a complete authoritative gate inventory.
- The Faculty of Arts entrance is very close to a STAIR feature and a BUILDING line, consistent with an entrance/threshold location.
- These matches make EPSG:28191 a strong provisional CRS candidate. They do not prove the source datum, survey method, or campus-wide accuracy. GPS pin placement itself may also be several metres from the exact surveyed feature.

No arbitrary affine fit has been applied to force the points onto geometry. The four coordinates should be treated as validation observations; independent check points and source metadata are still needed before approving a transformation.

## Campus bounding area for the next OSM extraction

The DXF XY extents, provisionally interpreted in EPSG:28191, transform approximately to this WGS84 bounding box:

- South: 32.40342
- West: 35.34017
- North: 32.41151
- East: 35.34857

This is a preliminary extraction envelope, not a final campus boundary. Clip the eventual OSM extract to the verified campus AOI, not simply to this rectangular envelope.

## OSM discovery notes

Public OSM-derived references identify the university campus as OSM way 888585504 (`amenity=university`). This is a useful seed feature for AOI discovery, not evidence that OSM contains a complete pedestrian network inside the campus. The official university visitor page also identifies the Jenin campus location near Talfit/Zababdeh. OSM raw data must still be fetched from Overpass and inspected before any comparison or routing use.

## Next technical steps

1. Decode/inspect the DXF text and block attributes for survey/CRS clues.
2. Continue identifying exact gate openings and entrance thresholds in the DXF; do not infer them solely from layer names.
3. Obtain and archive a timestamped OSM extract for the envelope above, then determine the actual campus AOI.
4. Reconcile OSM and DXF in separate source layers with provenance and license records.
5. Validate geometry, accessibility, barriers, and pedestrian connectivity before constructing a routing graph.

## Current status

**DXF structural inspection and four-point EPSG:28191 cross-check completed. EPSG:28191 is a strong provisional candidate, not yet formally certified. No approved georeferencing transformation, OSM extract, merged map, or routing graph has been produced.**
