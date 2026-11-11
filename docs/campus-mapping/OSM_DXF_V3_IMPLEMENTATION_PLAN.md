# Droobi Campus Navigation V3 — OSM + DXF Implementation Plan

## 1. Goal

Build a reliable pedestrian navigation dataset for the university campus using a hybrid source strategy:

- **OpenStreetMap (OSM):** primary geographic source for mapped roads, pedestrian paths, buildings, gates, and verifiable features.
- **University master plan (DXF):** supplementary source for campus-specific geometry and details missing from OSM.
- **OSM-first processing workflow:** Overpass API for selective read-only extraction and JOSM for inspection and carefully verified OSM edits. QGIS is not the central workflow and is not a runtime dependency.

The deliverable is a versioned, validated campus pedestrian graph consumed locally by Droobi.

## 2. Non-negotiable rules

1. A DXF line or polygon is not proof that a path, building, or entrance exists on the ground.
2. Do not upload DXF-derived objects to OSM unless usage rights are confirmed, features are verified, and OSM import guidelines are followed.
3. Keep OSM-derived and project-owned DXF-derived data traceable by source and license. Review DXF permission before distributing merged derived datasets.
4. Never silently fall back to an unrelated campus map, old V2 map, Firestore coordinates, or OSRM for a campus graph route.
5. Do not invent graph connections. Every edge must represent a traversable pedestrian connection supported by source data or explicit field verification.
6. Keep the stable base branch unchanged. All V3 work belongs on this feature branch.
7. Preserve the existing V2 engine as a rollback point; replace campus routing only after the V3 dataset and tests pass.

## 3. Source acquisition

### 3.1 OSM extraction

- Define a small campus area of interest (AOI) from verified campus bounds, not an arbitrary city-wide query.
- Use Overpass QL to extract relevant OSM objects: pedestrian ways, service/access roads where pedestrian access is permitted, building footprints, gates/entrances, and campus POIs.
- Save the exact query, AOI, extraction timestamp, Overpass endpoint, and OSM data timestamp alongside each snapshot.
- Preserve OSM element type and ID (node, way, relation) and relevant tags.
- Treat Overpass output as source data; do not edit the raw snapshot.

### 3.2 DXF inspection and conversion

- Inspect DXF layer names, entity types, units, extents, block references, and embedded coordinate-system clues before conversion.
- Determine whether the drawing uses real-world projected coordinates, local CAD coordinates, or an unknown local origin.
- If coordinates are local or unknown, obtain reliable control points and georeference the drawing using multiple well-distributed, independently identifiable points. Record the transformation and residual error.
- Convert candidate geometry into a project-owned intermediate format (GeoJSON or GeoPackage), preserving original layer/entity identifiers and attributes.
- Keep the untouched DXF as the source artifact. Never modify it in place.
- Do not merge DXF geometry with OSM until both are in a common CRS and positional accuracy has been checked.

## 4. Hybrid reconciliation

For each feature, record at minimum:

- stable project feature ID;
- source (osm, dxf, or field_verified);
- source element/layer/entity ID;
- feature class and access status;
- geometry and CRS;
- verification status and notes;
- source timestamp/version where available.

Reconciliation rules:

- Prefer OSM geometry for existing, correctly positioned, verified pedestrian infrastructure.
- Use DXF to propose missing campus paths, building footprints, and entrance locations.
- Where OSM and DXF disagree, retain both candidates in a review layer; do not average or snap them blindly.
- Resolve differences using field observations, suitably licensed imagery, or authoritative university information.
- Preserve separate provenance for every feature in the final dataset.

## 5. Pedestrian graph model

The final graph must be explicit and topologically validated.

### Nodes

- junctions and true intersections;
- path endpoints;
- entrances and gates;
- destination access points;
- safe transfer points between OSM and DXF-derived paths.

Each node has a stable ID, WGS84 coordinate, node type, name/aliases where applicable, source provenance, and verification status.

### Edges

Each edge is a traversable pedestrian segment with:

- stable edge ID;
- from_node and to_node;
- LineString geometry in WGS84;
- length in meters (computed geodesically or in a suitable projected CRS);
- access/direction restrictions;
- surface, steps, width, and accessibility attributes when known;
- source provenance and verification status.

Split edges at every true junction and access point. Coincident-looking crossings must not be connected unless they are physically connected and walkable. Keep barriers and inaccessible segments explicit.

### Destinations

Destinations reference one or more real access nodes/entrances. A building centroid must never be used as a walkable destination when the user needs an entrance. Multiple entrances remain separate candidates until a safe accessible entrance is selected.

## 6. Output artifacts

Proposed versioned dataset under assets/campus_map_v3/:

- osm_raw/ — immutable OSM extracts and query metadata;
- dxf_source/ — source metadata and conversion notes (the original DXF may remain outside the repository if licensing or file size requires it);
- review/ — candidate and conflict layers not yet approved for routing;
- exported/nodes.geojson;
- exported/edges.geojson;
- exported/destinations.geojson;
- exported/barriers.geojson;
- manifest.json — schema version, sources, timestamps, checksums, CRS, attribution, and transformation details.

The runtime should consume only the approved exported dataset and reject missing, stale, malformed, or incompatible manifests.

## 7. Implementation phases and gates

### Gate 0 — Baseline and branch isolation

- Confirm the feature branch starts exactly from merge/engine-v2-with-brand-theme.
- Record the base commit and current V2 routing behavior.
- Do not modify the base branch.

**Exit:** branch ancestry and baseline are recorded.

### Gate 1 — Source audit

- Inspect DXF layers, entities, units, extents, and georeferencing.
- Define the campus AOI and extract OSM data with Overpass.
- Inventory feature counts, tags, geometry types, and source IDs.
- Check DXF usage/distribution permission.

**Exit:** both sources are understood, georeferencing is defensible, and source/license metadata is recorded. No routing graph is generated yet.

### Gate 2 — Reconciliation

- Compare OSM and DXF geometry.
- Classify features as OSM-confirmed, DXF-candidate, conflicting, or field-verified.
- Resolve only evidence-backed conflicts.
- Produce a reviewable change report.

**Exit:** every candidate used for routing has documented provenance and verification status.

### Gate 3 — Graph construction

- Generate stable nodes and edges.
- Connect endpoints only under explicit topology rules.
- Preserve direction/access restrictions and barriers.
- Attach destinations to entrance nodes.

**Exit:** graph passes schema, geometry, topology, and connectivity checks.

### Gate 4 — Routing engine integration

- Add a V3 data loader and graph validator.
- Keep graph routing deterministic and offline.
- Implement snapping to multiple nearby candidate edges, then choose a connected valid route.
- Return a clear no-route result rather than routing through barriers or falling back to unrelated services.
- Keep campus destination selection data-driven; no hard-coded university location lists or coordinates.

**Exit:** automated routing tests pass for agreed origin/destination pairs and negative cases.

### Gate 5 — Device validation

- Test GPS snapping at entrances and along paths.
- Test off-route detection and safe rejoin behavior.
- Test arrival detection and prevent guidance from reversing after arrival.
- Verify turn cues against actual route geometry.
- Test with the phone held forward as specified; do not add an IMU dependency.
- Validate vibration events and accessibility behavior.

**Exit:** repeatable field tests pass; only then make V3 the default campus routing source.

## 8. Required automated checks

- GeoJSON schema and CRS checks.
- Unique, non-empty node and edge IDs.
- Every edge endpoint references an existing node.
- Edge geometry endpoints agree with referenced node coordinates within a documented tolerance.
- No zero-length or invalid geometries.
- Junctions are split and connected correctly.
- No unintended disconnected components within the expected walkable network.
- Barriers and access restrictions are respected.
- Destination entrances connect to the graph.
- Deterministic route tests, including positive and negative cases.
- Source manifest and checksum validation.
- No silent fallback to V2, Firestore, or OSRM for campus routes.

## 9. Initial route acceptance cases

Use these as named acceptance cases only after confirming the exact node IDs and paths exist in the new source data:

- E1 -> J90_4 -> J90_2 -> AR1
- E1 -> J90_3 -> J90_2 -> AR1

Do not fabricate missing nodes or edges to make these tests pass. If a route fails, report the first missing or disconnected segment and fix the source data or topology.

## 10. Licensing and attribution

OSM data is available under the Open Database License (ODbL) and requires appropriate attribution. Review ODbL obligations before redistributing a database or derivative database that combines OSM data with other sources. DXF source rights must be checked separately. Keep source provenance and attribution in the exported manifest and app documentation.

## 11. Current status

- Feature branch created from merge/engine-v2-with-brand-theme.
- The implementation strategy and gates are recorded in this document.
- The uploaded DXF has received a preliminary structural audit; see DXF_SOURCE_AUDIT_V3.md.
- EPSG:28191 is a plausible coordinate-system hypothesis based on the drawing bounds, but it is not confirmed. No georeferencing transform is approved yet.
- No OSM extract has been acquired yet; the AOI will be fixed only after the DXF CRS and control points are validated.
- No V3 graph has been generated and no routing-engine code has been changed yet.
