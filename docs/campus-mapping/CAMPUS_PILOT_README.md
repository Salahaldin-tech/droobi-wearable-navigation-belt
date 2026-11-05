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


## Flutter campus-routing integration

The Flutter pilot now has two explicit routing modes:

- Destinations selected from UniversityLocationsScreen pass campusNavigation: true to LiveNavigationScreen and use CampusGraphRoutingService.
- Destinations opened through the ordinary navigation flow continue using OsrmRoutingService.
- Campus graph routing loads the bundled nodes.geojson and edges.geojson assets and computes a shortest path over the exported pedestrian LineStrings.
- The current GPS fix and selected university destination are projected onto the nearest usable edge (maximum snap distance: 45 m). The generated route includes the GPS-to-network and network-to-destination connectors.
- During campus navigation, two consecutive accepted GPS samples more than max(12 m, 1.5 × GPS accuracy) from the current route trigger a new QGIS route calculation. A 5-second cooldown limits repeated recalculations.

## Important field-test limitations

This is experimental routing, not a safety-certified navigation network. The supplied pilot export still has unverified edges, invalid/missing node references, duplicate node IDs, and incomplete campus coverage. The router therefore derives graph junctions from shared edge coordinates rather than trusting the from_node/to_node attributes. It does not invent connections between separated lines.

The straight-line connector from a GPS fix to the nearest mapped edge is a geometric approximation, not proof that the space between them is walkable or obstacle-free. Test this only in a supervised, controlled field trial; verify the edges, intersections, directionality, destination entrance points, and off-route thresholds in QGIS before relying on it with a visually impaired pedestrian.

If the closest edge is farther than 45 m, or no connected graph path exists, campus routing reports an error. It deliberately does not silently fall back to OSRM inside the campus mode.
