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
- The header does not explicitly identify a geographic CRS or datum.

The meter unit declaration is useful, but it does not prove the CRS. The drawing coordinate ranges are consistent with a Palestine Grid coordinate space, so EPSG:28191 (Palestine 1923 / Palestine Grid) is a candidate to test, not yet an approved CRS.

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

## User-provided geographic control points

The user confirmed that the drawing is the Arab American University (AAUP), main campus in Jenin, and supplied these WGS84 coordinates:

| Control point | Latitude | Longitude |
|---|---:|---:|
| Gate 3 | 32.40740417658937 | 35.341274899549745 |
| Gate 5 | 32.41068251057309 | 35.3439330384187 |
| Main entrance, Faculty of Arts | 32.407989460739536 | 35.34462720764019 |
| Gate 1 | 32.405534019978944 | 35.342153277196914 |

## Preliminary CRS and geometry cross-check

The four GPS points were transformed from WGS84 to EPSG:28191 for a preliminary comparison. This is a diagnostic test only; it does not by itself certify the drawing CRS or a final georeferencing transformation.

- Gate 5 transforms to approximately (182577.822, 201866.540) in EPSG:28191.
- The DXF GATE layer contains two nearby line features: handle 382B centered at approximately (182576.193, 201865.988), and handle 382C centered at approximately (182582.716, 201865.912).
- The Gate 5 coordinate is about 1.7 m from the center of feature 382B and about 4.9 m from feature 382C. This is a strong preliminary indication that EPSG:28191 may be the intended coordinate system, and that these line features may depict the Gate 5 opening/structure. It is not yet proof.
- The other supplied points do not match the remaining GATE-layer features closely under this direct CRS test. Their corresponding geometry may be represented on other layers, the point descriptions may refer to a different part of each entrance, or the candidate CRS/datum may require a documented transformation.

**Do not force the remaining GPS points onto the nearest GATE-layer entities.** Identify their actual corresponding features using geometry and labels, then test residuals. The Gate 5 match is one strong check, not enough on its own to approve the CRS or a campus-wide transformation.

## Required next steps

1. Search the DXF's text, block attributes, and drawing metadata for an explicit CRS/datum or survey reference.
2. Identify the actual corresponding geometry for Gate 3, Gate 1, and the Faculty of Arts main entrance. Do not assume every entrance is represented in the GATE layer.
3. Verify EPSG:28191 against multiple independent points distributed across the campus. Report residuals in meters and keep at least one independent check point out of any fitted transformation.
4. If the EPSG:28191 direct-coordinate test is not sufficiently accurate, obtain the survey datum/CRS or transformation parameters from the university engineering office / drawing author. Do not hide systematic offsets with an arbitrary fit.
5. Only after CRS validation, define the campus AOI and obtain a timestamped OSM extract through Overpass.
6. Keep raw OSM data and DXF-derived candidate geometry separate until reconciliation is complete.

## Current audit status

**Drawing1.dxf structural inspection completed. Four user-supplied GPS control points recorded. EPSG:28191 is a promising provisional CRS candidate based on a close Gate 5 geometry correspondence, but it is not yet certified. No OSM extraction, approved georeferencing transformation, merged map, or routing graph has been created.**
