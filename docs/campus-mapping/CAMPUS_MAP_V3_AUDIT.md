# Campus Map V3 — Source Audit

## Source of truth

- Source branch: `main`
- Source commit: `9787d1801f132eebc7344e75e598f179ade7152a`
- Source GeoPackage: `assets/campus_map_v3/campus_network.gpkg`
- GeoPackage Git blob SHA: `a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41`
- CRS: EPSG:32636 (WGS 84 / UTM zone 36N)
- Latest layer timestamps: nodes `2026-11-11T01:17:33.187Z`; edges `2026-11-11T01:18:56.453Z`

The native `.gpkg` and `.qgz` files were copied into V3 without changing their contents. V3's runtime GeoJSON exports were generated from the GeoPackage's canonical layers using `tooling/export_campus_gpkg_to_geojson.py`.

## Layers

| Layer | Features | V3 role |
|---|---:|---|
| `nodes` | 28 | Canonical node identities and destination entrance points |
| `edges` | 20 | Pedestrian path geometries and direction flags |
| `buildings` | 7 | Building footprint context |
| `barriers` | 16 | Obstacle/barrier context |
| `campus_network` | 15 | Older duplicate point layer; deliberately not used |

**Important:** use `nodes`, not the older duplicate `campus_network` layer, as the canonical point table.

## Identifier reference normalization

Node IDs and geometries are preserved. Only edge-reference strings use the explicit aliases below:

| Edge reference | Canonical node ID | Evidence |
|---|---|---|
| `J90-0` | `J90_0` | Endpoint geometry coincides with the `J90_0` point |
| `J90_4` | `J90-4` | Endpoint geometry coincides with the `J90-4` point |
| `AWS_B` | `AMS_B` | Endpoint geometry coincides with the `AMS_B` point |
| leading/trailing whitespace | trim for comparison only | Source node ` J90_5` contains a leading space |

The aliases are in `node_reference_aliases.json`. They do not rename source features, alter node IDs in the GeoPackage, or move any geometry.

## Geometry and connectivity findings

- ED06 and ED012 are digitized opposite to their declared `from_node` → `to_node` order. V3 reverses their vertex order in memory only when endpoint distances prove the reverse orientation.
- ED003's final vertex coincides with the separate C3 point but is approximately 3.40 m from its declared J3 node. V3 does not silently merge C3 and J3.
- ED006's endpoint is approximately 3.62 m from IT1. This remains a warning; V3 does not bridge the gap with a straight connector.
- ED01 and ED03 are one-way (`bidirectional=false`). The remaining source edges are marked bidirectional. The router respects these source flags rather than globally treating every edge as two-way.
- Exact shared LineString vertices produce **3 weakly connected geometry components**: one main component containing 18 edges, plus isolated ED011 and ED012. These isolated lines are not connected to the main network by proximity guesses. They remain unroutable from the main component until the source map explicitly connects them.
- All 28 nodes and all 20 edges are currently `verified=false`. The map is not field-verified.

## V3 safety behavior

- Preserve source IDs and geometries.
- Use node IDs for destinations and map identity.
- Use shared path geometry for graph junction connectivity, while validating the semantic node references separately.
- No fabricated GPS-to-path or route-to-destination walking connectors.
- Select the nearest geometric edge; do not choose a more distant edge just because it produces a shorter route.
- Reject ambiguous, distant, disconnected or unverified map matches instead of issuing a confident direction.
- An unresolved, ambiguous, off-route, stale or disconnected request must cause the belt to receive STOP.
- Software tests do not certify the map or replace supervised field trials.
