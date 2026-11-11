# Campus Map V3 — Source Audit

## Source

- GitHub branch: `main`
- Source commit: `9787d1801f132eebc7344e75e598f179ade7152a`
- GeoPackage: `assets/campus_map_v3/campus_network.gpkg`
- GeoPackage blob SHA: `a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41`
- Coordinate reference system: EPSG:32636 (WGS 84 / UTM zone 36N)
- GeoPackage `gpkg_contents` timestamps: nodes `2026-11-11T01:17:33.187Z`; edges `2026-11-11T01:18:56.453Z`

## Layers exported for V3

| Layer | Features | Use |
|---|---:|---|
| `nodes` | 29 | Canonical destination and junction points |
| `edges` | 20 | Pedestrian line features |
| `buildings` | 7 | Building footprints |
| `barriers` | 16 | Obstacle/barrier features |
| `campus_network` | 15 | Older duplicate point layer; not used as the canonical layer |

The app must use the `nodes` table, not the older `campus_network` duplicate.

## Identifier reference corrections

The source node IDs are preserved. The following edge references do not match node IDs literally and are resolved through `node_reference_aliases.json`:

| Edge reference | Canonical node ID | Evidence |
|---|---|---|
| `J90-0` | `J90_0` | Endpoint geometry coincides with the `J90_0` point |
| `J90_4` | `J90-4` | Endpoint geometry coincides with the `J90-4` point |
| `AWS_B` | `AMS_B` | Endpoint geometry coincides with the `AMS_B` point |
| leading/trailing whitespace | trimmed comparison only | The source node ID ` J90_5` contains a leading space |

These are reference aliases only. They do not change node IDs or geometries.

## Geometry orientation and endpoint observations

- ED06's LineString is stored opposite to its declared `from_node` → `to_node` order; it must be reversed in memory before building the directed graph.
- ED012's geometry is likewise stored opposite to its declared endpoints.
- ED003's final vertex is approximately 3.40 m from its declared `J3` node, while it coincides with the separate `C3` point. This is a topology ambiguity, not a spelling correction. V3 must report it and must not silently join C3 to J3.
- ED006's endpoint for IT1 is approximately 3.62 m from the IT1 point. This is retained as an endpoint-offset warning; it must not be hidden by a free-space connector.
- The map contains both one-way and bidirectional edges. In particular ED01 and ED03 have `bidirectional=false`; V3 must respect those flags.
- All 29 source nodes and all 20 source edges currently have `verified=false`. The software must not represent this map as field-verified.

## Safety policy

- Preserve all source node IDs and coordinates.
- Preserve source line geometry in the generated export.
- Resolve only the explicit identifier aliases listed above.
- Do not invent missing paths or connect components by proximity alone.
- Do not use long GPS-to-path or destination-to-path straight connectors as pedestrian route geometry.
- An unresolved, ambiguous, off-route, or disconnected request must produce a clear route failure and belt STOP.
- A software test pass does not certify the campus network or substitute for supervised field testing.
