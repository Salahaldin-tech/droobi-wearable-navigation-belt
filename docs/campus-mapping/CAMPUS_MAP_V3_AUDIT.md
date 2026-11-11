# Campus Map V3 — Source Data Record

## Source of truth

- Source branch: `main`
- Source commit: `9787d1801f132eebc7344e75e598f179ade7152a`
- GeoPackage: `assets/campus_map_v3/campus_network.gpkg`
- GeoPackage blob SHA: `a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41`
- Coordinate reference system: EPSG:32636 (WGS 84 / UTM zone 36N)
- QGIS project: `assets/campus_map_v3/AAUP_Campus_Network.qgz`

The original GeoPackage and QGIS project were copied without changing their source contents. A second copy of the same GeoPackage blob is present at `assets/campus_map_v3/data/campus_network.gpkg` to satisfy the relative datasource path used by the QGIS project.

## Canonical layers

| Layer | Features | Role |
|---|---:|---|
| `nodes` | 28 | Canonical node IDs, junctions and destination entrances |
| `edges` | 20 | Pedestrian path geometry and direction flags |
| `buildings` | 7 | Building context |
| `barriers` | 16 | Barrier / obstacle context |
| `campus_network` | 15 | Older duplicate point layer; not used as destination source |

Runtime exports are WGS84 / EPSG:4326:
- `docs/campus-mapping/nodes_v3.geojson`
- `docs/campus-mapping/edges_v3.geojson`
- `docs/campus-mapping/buildings_v3.geojson`
- `docs/campus-mapping/barriers_v3.geojson`

The reproducible exporter is `tooling/export_campus_gpkg_to_geojson.py`.

## Reference normalization

The GeoPackage's node IDs are preserved. Only edge reference strings are normalized using `node_reference_aliases.json`:

| Edge reference | Canonical node ID |
|---|---|
| `J90-0` | `J90_0` |
| `J90_4` | `J90-4` |
| `AWS_B` | `AMS_B` |
| Surrounding whitespace | Trim for reference lookup only |

No source node ID or geometry is renamed or moved by this branch.

## Gate 1 source verification

- Gate 1 is present in the current `main` GeoPackage as node `G1` (`GATE1`).
- Edge `ED08` explicitly connects `J90_3` → `G1` and is bidirectional.
- The ED08 first vertex exactly matches the `J90_3` node coordinate, and its final vertex exactly matches the `G1` node coordinate in the exported WGS84 data.
- Therefore the earlier claim that Gate 1 is approximately 144.4m from the nearest mapped path is not supported by this current source snapshot. The Gate 1 path is present; investigate runtime data packaging, GPS fix quality, and map-matching if `GPS_SNAP_ORIGIN` still occurs.
- Source edge `ED08` is `verified=false`; its presence is confirmed in the dataset, but its walkability has not been field-verified.

## Connectivity and source limitations

- Graph connectivity is now keyed by canonical `from_node` / `to_node` IDs. Shared coordinates remain the mechanism for connecting interior vertices within each LineString, not the authority for joining declared edge endpoints.
- A declared edge endpoint may be attached to its QGIS node only when the endpoint offset is at most 5m. Offsets above 5m fail graph loading; offsets above 0.2m are represented as explicit short connector geometry and logged as warnings.
- Shared LineString vertices identify three weak geometry components: one principal component containing 18 edges, plus isolated ED011 and ED012.
- ED011 is associated with the MED fragment; ED012 is associated with AMS_B. They remain disconnected from the principal pedestrian network and are not connected by software.
- ED06 and ED012 are stored opposite to their declared `from_node` → `to_node` order. The router reverses the in-memory vertex order only when endpoint distances establish that reversal.
- ED003's final geometry vertex is associated spatially with C3 while its source endpoint attributes declare J3. This is not silently reconciled by changing IDs or geometry.
- ED006 has an endpoint offset to IT1. The router does not bridge that offset with an artificial connector.
- ED01 and ED03 are marked one-way; the router respects their `bidirectional` fields.
- All 28 node and 20 edge source `verified` flags are false. The map is not field-verified.

## Routing rules

- Graph topology is derived from shared path geometry.
- Semantic node references are validated separately.
- Origin and destination are snapped to actual edge segments with conservative maximum distances.
- Ambiguous snaps across disconnected components are rejected.
- No straight-line GPS-to-path or path-to-destination walking connectors are fabricated.
- Disconnected components stay disconnected until the QGIS source map is explicitly updated.
- Source feature attributes and coordinates remain the spatial authority.
