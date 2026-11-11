# DXF Source Audit — Drawing1.dxf — Campus Navigation V3

## Authoritative file for this audit

This audit is based only on the newly uploaded file:

- Filename: Drawing1.dxf
- Size: 11,425,872 bytes
- SHA-256: 96cdeca1fd2d7ed0423e1041fd43f3c57afa54b4fc9c536c34281f24df6132ac
- DXF version: AC1032 (AutoCAD 2018 format)
- Modelspace entities: 13,702

This file is the active DXF candidate for the V3 workflow. Do not substitute an earlier DXF or reuse its audit conclusions.

## Header and units

- $INSUNITS = 6, which declares drawing units as meters.
- $MEASUREMENT = 1.
- $EXTMIN = (182225.579473, 201062.231054, 0.0)
- $EXTMAX = (183013.207051, 201957.831054, 824.369888)
- No GEODATA entity was found.
- The header does not conclusively identify a geographic CRS or datum.

The meter unit declaration is useful, but it does not prove that the XY coordinates are Palestine Grid or any other specific CRS. The coordinate system must be established from authoritative drawing metadata or multiple independent geographic control points. No transformation is approved at this stage.

## Modelspace entity inventory

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

## Relevant layer inventory

| Layer | Entities | Initial interpretation / review need |
|---|---:|---|
| MANHOLE | 2,649 | Utility infrastructure; not pedestrian routing edges |
| TREE | 1,711 | Tree symbols/labels; may inform obstacles only after interpretation |
| CWALL | 1,609 | Candidate walls/barriers; verify continuity and meaning |
| STAIR | 1,439 | Stair details; not automatically accessible paths |
| V-NODE | 1,206 | Proxy entities; inspect source application/proxy meaning |
| CS | 648 | Meaning not yet confirmed |
| POLE | 482 | Utility/site furniture candidates |
| PARKING | 409 | Parking geometry; not all lines are walkable |
| CONT-MJR | 385 | Major contour lines |
| LEVEL | 315 | Elevation/level annotations |
| BUILDING | 297 | Candidate building outlines; distinguish footprints from drafting detail |
| GRIL | 251 | Meaning not yet confirmed |
| HOUSE | 198 | Mixed geometry and hatches; inspect before interpreting |
| CW | 155 | Mixed geometry; meaning not yet confirmed |
| ZENK | 140 | Meaning not yet confirmed |
| TRAV | 105 | Mixed text/circle/polyline entities; semantic meaning not yet confirmed |
| BORDER | 76 | Candidate boundary geometry |
| FENCE | 34 | Candidate fences/barriers |
| RAMP | 13 | Candidate ramps; verify endpoints, continuity, and accessibility |
| GATE | 5 | Five entities, not necessarily five distinct gates |

The GATE layer consists of four LINE entities and one LWPOLYLINE. Its geometry must be interpreted; entity count is not a gate count.

The RAMP layer consists of eleven LINE entities and two LWPOLYLINE entities. Confirm whether these represent ramp centerlines, outlines, or drafting annotations before using them in routing.

The BUILDING layer contains 143 LWPOLYLINE, 144 LINE, nine ARC, and one POLYLINE entities. These are not automatically 297 complete building footprints.

## Required next steps

1. Obtain the intended CRS/datum from the DXF author or university engineering office, if possible.
2. Identify at least three well-distributed, unambiguous control points shared between this drawing and trusted geographic data; use additional points where possible.
3. Fit the transformation and report residual errors. Reserve independent check points that are not used to fit it.
4. Inspect candidate pedestrian geometry and relevant layers, especially access paths, gates, ramps, stairs, walls, and fences.
5. Only after CRS validation, define the campus AOI and obtain a timestamped OSM extract through Overpass.
6. Keep raw OSM data and DXF-derived candidate geometry separate until reconciliation is complete.

## Current audit status

**Structural inspection of Drawing1.dxf completed. Units are declared as meters. Geographic CRS is not confirmed. No OSM extraction, georeferencing transformation, merged map, or routing graph has been created.**
