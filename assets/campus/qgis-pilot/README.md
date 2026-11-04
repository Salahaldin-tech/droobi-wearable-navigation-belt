# Campus QGIS Pilot Map

This folder contains a temporary QGIS mapping snapshot for field inspection.

## Purpose
- Review the initial campus point locations and drawn pedestrian paths.
- Field-check the Cafeteria, IT, Arts, and Engineering entrance locations.
- Decide whether this incremental QGIS mapping workflow is suitable before adopting it.

## Data status in the supplied GeoPackage
- `campus_network`: 14 point features, CRS EPSG:32636.
- `nodes`: empty point layer, CRS EPSG:4326.
- `edges`: 7 line features, CRS EPSG:32636.
- This is a working draft, not a validated pedestrian routing graph.

## Important checks before using for routing
- Review all point and line geometries in QGIS.
- The point data contains a duplicate `node_id` (`ENT004`) for IT and Arts entrances; resolve IDs before graph conversion.
- Several edge endpoint attributes (`from_node`, `to_node`) are empty or need review.
- Confirm the Engineering entrance location in the field, as requested.
- Do not treat unverified paths or intersections as safe/connected.

## Open
1. Download and extract `campus_network_qgis_pilot.zip`.
2. Open `campus_network.gpkg` in QGIS.
3. Inspect the `campus_network` and `edges` layers.
4. Keep this branch separate; do not merge into main until the field test is complete.
