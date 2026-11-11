# V3 Campus Map Export

The current V3 QGIS source files are kept in `assets/campus_map_v3/`:
- `AAUP_Campus_Network.qgz` — editable QGIS project.
- `campus_network.gpkg` — source GeoPackage.

The Flutter graph router consumes WGS84 GeoJSON, not a QGIS project or a raw
GeoPackage. Export the point and pedestrian-line feature layers before enabling
V3 routing:

1. Open a terminal using the Python environment bundled with QGIS/GDAL.
2. Run:
   ```bash
python tools/export_campus_geopackage.py
```
3. The exporter discovers point and line feature layers, converts geometries to
   EPSG:4326, preserves their attributes, and writes:
   - `assets/campus_map_v3/exported/nodes.geojson`
   - `assets/campus_map_v3/exported/edges.geojson`
4. Commit both generated GeoJSON files to this branch. The app prefers the V3
   exports when both exist and otherwise falls back to the V2 pilot exports.
5. Run `flutter pub get` from the project root so the new WMM2025 dependency is
   resolved and `pubspec.lock` is refreshed.

The exporter deliberately does not create connections between separated lines.
A route is valid only when the QGIS edge geometries actually connect. The
`from_node`/`to_node` attributes are preserved for the topology
audit; they must not be treated as proof of connectivity until checked against
the node layer and line endpoints.

## Required route audit

After export, verify these two requested node sequences independently:

- `E1 -> J90_4 -> J90_2 -> AR1`
- `E1 -> J90_3 -> J90_2 -> AR1`

For each sequence, verify that all four node IDs exist, each consecutive pair
has a connecting pedestrian edge, and the edge geometry endpoints agree with
the referenced node coordinates. Also test that the graph router can calculate
a path between the E1 and AR1 coordinates. Do not mark either route as passed
until these checks run against the exported V3 data.
