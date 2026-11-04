# Campus Mapping Pilot — Field Test

This branch contains a QGIS-exported snapshot of the current campus pilot map for field inspection.

## Files
- `nodes.geojson`: current point features exported from the GeoPackage layer `campus_network`.
- `edges.geojson`: current pedestrian line features exported from the GeoPackage layer `edges`.

Both files use WGS 84 (EPSG:4326), so they can be opened directly in QGIS and inspected alongside the satellite basemap.

## Important
- This is a test snapshot, not an approved production routing network.
- No Flutter routing code or app assets were changed.
- The source GeoPackage had 14 point features in `campus_network`, 7 line features in `edges`, and an empty `nodes` layer.
- Point/line attributes are preserved as exported. In particular, review edge `from_node` and `to_node` values during the field test; do not assume connectivity is correct merely because geometries touch.
- Keep the original GeoPackage as the editable QGIS source. These GeoJSON files are portable review/export copies.
