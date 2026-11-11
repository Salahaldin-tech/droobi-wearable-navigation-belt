# Campus Map V3 Source Audit

Source of truth: `main` commit `9787d1801f132eebc7344e75e598f179ade7152a`, GeoPackage blob `a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41`, EPSG:32636.

| Layer | Features | Runtime role |
|---|---:|---|
| nodes | 28 | canonical points and destinations |
| edges | 20 | pedestrian edge geometry |
| buildings | 7 | building context |
| barriers | 16 | obstacle context |
| campus_network | 15 | legacy duplicate; not used |

Runtime exports are WGS84 EPSG:4326. All source nodes/edges are currently unverified.

Reference-only aliases:
- `J90-0` → `J90_0`
- `J90_4` → `J90-4`
- `AWS_B` → `AMS_B`
- trim surrounding whitespace for reference comparison

No source node IDs or geometry are renamed or moved.

Geometry connectivity: 3 weak components based on shared LineString vertices. The main component contains 18 edges. ED011 and ED012 remain isolated. The engine must reject routes across these components, never join them by proximity.

Geometry warnings:
- ED06 and ED012 are reversed relative to declared from/to order; reverse vertices only when endpoint distances prove direction.
- ED003 ends at C3 but its from/to attributes declare J3, with approximately 3.4 m offset. Do not silently join.
- ED006 is approximately 3.6 m from IT1. Do not bridge the gap.

One-way edges ED01 and ED03 must respect their direction flags. No map is field verified yet.
