#!/usr/bin/env python3
"""Validate the source QGIS GeoPackage, V3 runtime exports and QGIS project.

Standard-library only. Run from the repository root:
  python tooling/validate_campus_map.py \
    --gpkg assets/campus_map_v3/campus_network.gpkg \
    --project assets/campus_map_v3/AAUP_Campus_Network.qgz \
    --export-dir docs/campus-mapping
"""
from __future__ import annotations

import argparse
import json
import math
import sqlite3
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from export_campus_gpkg_to_geojson import read_geometry, transform_coordinates


GEOMETRY_COLUMNS = {
    "nodes": "geom",
    "edges": "geometry",
    "buildings": "geometry",
    "barriers": "geometry",
}
RUNTIME_EXPORTS = {
    "nodes": "nodes_v3.geojson",
    "edges": "edges_v3.geojson",
    "buildings": "buildings_v3.geojson",
    "barriers": "barriers_v3.geojson",
}


def haversine(a: list[float], b: list[float]) -> float:
    radius = 6_371_000.0
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    dlat = math.radians(b[1] - a[1])
    dlon = math.radians(b[0] - a[0])
    value = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    return 2 * radius * math.atan2(math.sqrt(value), math.sqrt(1 - value))


def bool_value(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value or "").strip().lower() in {"true", "1", "yes"}


def point_key(point: list[float]) -> str:
    return f"{point[1]:.6f},{point[0]:.6f}"


def load_rows(connection: sqlite3.Connection, table: str) -> list[dict[str, Any]]:
    rows = connection.execute(f'SELECT * FROM "{table}" ORDER BY fid')
    columns = [item[0] for item in rows.description]
    return [dict(zip(columns, row)) for row in rows.fetchall()]


def validate_project(project: Path) -> list[str]:
    missing: list[str] = []
    if not project.exists():
        raise FileNotFoundError(f"QGIS project not found: {project}")

    with zipfile.ZipFile(project) as archive:
        qgs_names = [name for name in archive.namelist() if name.lower().endswith(".qgs")]
        if not qgs_names:
            raise ValueError("QGZ archive contains no .qgs project XML")

        for qgs_name in qgs_names:
            root = ET.fromstring(archive.read(qgs_name))
            for layer in root.findall(".//projectlayers/maplayer"):
                provider = (layer.findtext("provider") or "").strip().lower()
                datasource = (layer.findtext("datasource") or "").strip()
                if not datasource or provider not in {"ogr", "spatialite", "delimitedtext"}:
                    continue

                source = datasource.split("|", 1)[0].strip().strip("'").strip('"')
                # Skip remote services and database connection strings.
                if "://" in source or source.lower().startswith(("dbname=", "host=")):
                    continue

                candidate = Path(source)
                if not candidate.is_absolute():
                    candidate = project.parent / candidate
                if not candidate.exists():
                    layer_name = layer.findtext("layername") or "unnamed layer"
                    missing.append(
                        f"{layer_name}: {source} (resolved as {candidate})"
                    )
    return missing


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gpkg", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    parser.add_argument("--export-dir", required=True, type=Path)
    args = parser.parse_args()

    if not args.gpkg.exists():
        raise SystemExit(f"GeoPackage not found: {args.gpkg}")

    aliases_path = args.export_dir / "node_reference_aliases.json"
    aliases_doc = json.loads(aliases_path.read_text(encoding="utf-8"))
    aliases = {
        str(key).strip(): str(value).strip()
        for key, value in aliases_doc.get("aliases", {}).items()
    }

    with sqlite3.connect(args.gpkg) as connection:
        srs = connection.execute(
            "SELECT srs_id FROM gpkg_geometry_columns WHERE table_name='nodes'"
        ).fetchone()
        if srs is None or srs[0] != 32636:
            raise SystemExit(f"Expected nodes EPSG:32636, found {srs!r}")

        source_counts: dict[str, int] = {}
        source_rows: dict[str, list[dict[str, Any]]] = {}
        for table in GEOMETRY_COLUMNS:
            source_rows[table] = load_rows(connection, table)
            source_counts[table] = len(source_rows[table])

        node_ids: set[str] = set()
        nodes_by_id: dict[str, list[float]] = {}
        for row in source_rows["nodes"]:
            node_id = str(row["node_id"] or "").strip()
            if not node_id:
                raise SystemExit("A source node has an empty node_id")
            if node_id in node_ids:
                raise SystemExit(f"Duplicate source node_id after trim: {node_id}")
            node_ids.add(node_id)
            geometry = transform_coordinates(read_geometry(row["geom"]))
            if geometry["type"] != "Point":
                raise SystemExit(f"Node {node_id} is not a Point")
            nodes_by_id[node_id] = geometry["coordinates"]

        edge_ids: set[str] = set()
        unresolved: list[str] = []
        endpoint_warnings: list[str] = []
        adjacency: dict[str, set[str]] = {}
        edge_keys: dict[str, set[str]] = {}
        one_way_edges: list[str] = []
        unverified_edges: list[str] = []

        for row in source_rows["edges"]:
            edge_id = str(row["edge_id"] or "").strip()
            if not edge_id or edge_id in edge_ids:
                raise SystemExit(f"Blank or duplicate edge_id: {edge_id!r}")
            edge_ids.add(edge_id)

            from_ref = str(row["from_node"] or "").strip()
            to_ref = str(row["to_node"] or "").strip()
            from_node = aliases.get(from_ref, from_ref)
            to_node = aliases.get(to_ref, to_ref)
            if from_node not in node_ids or to_node not in node_ids:
                unresolved.append(
                    f"{edge_id}: {from_ref!r} -> {to_ref!r} "
                    f"(normalized {from_node!r} -> {to_node!r})"
                )
                continue

            geometry = transform_coordinates(read_geometry(row["geometry"]))
            if geometry["type"] != "LineString" or len(geometry["coordinates"]) < 2:
                raise SystemExit(f"Edge {edge_id} is not a usable LineString")

            line = geometry["coordinates"]
            direct = (
                haversine(line[0], nodes_by_id[from_node])
                + haversine(line[-1], nodes_by_id[to_node])
            )
            reverse = (
                haversine(line[-1], nodes_by_id[from_node])
                + haversine(line[0], nodes_by_id[to_node])
            )
            if reverse < direct:
                line = list(reversed(line))

            start_offset = haversine(line[0], nodes_by_id[from_node])
            end_offset = haversine(line[-1], nodes_by_id[to_node])
            if max(start_offset, end_offset) > 1.0:
                endpoint_warnings.append(
                    f"{edge_id}: from={start_offset:.2f}m, to={end_offset:.2f}m"
                )

            if not bool_value(row["bidirectional"]):
                one_way_edges.append(edge_id)
            if not bool_value(row["verified"]):
                unverified_edges.append(edge_id)

            keys: set[str] = set()
            for first, second in zip(line, line[1:]):
                a, b = point_key(first), point_key(second)
                keys.update((a, b))
                adjacency.setdefault(a, set()).add(b)
                adjacency.setdefault(b, set()).add(a)
            edge_keys[edge_id] = keys

        if unresolved:
            raise SystemExit(
                "Unresolved QGIS edge node references after alias normalization:\n"
                + "\n".join(unresolved)
            )

    # Count weak geometry components from shared LineString vertices. This is
    # deliberately independent of one-way traversal direction.
    component_by_vertex: dict[str, int] = {}
    component_sizes: list[dict[str, Any]] = []
    for start in adjacency:
        if start in component_by_vertex:
            continue
        index = len(component_sizes)
        stack = [start]
        component_by_vertex[start] = index
        vertices: set[str] = set()
        while stack:
            current = stack.pop()
            vertices.add(current)
            for neighbour in adjacency[current]:
                if neighbour not in component_by_vertex:
                    component_by_vertex[neighbour] = index
                    stack.append(neighbour)
        component_sizes.append({"vertices": len(vertices), "edges": 0})

    for edge_id, keys in edge_keys.items():
        if not keys:
            continue
        component = component_by_vertex[next(iter(keys))]
        component_sizes[component]["edges"] += 1

    export_counts: dict[str, int] = {}
    for layer, filename in RUNTIME_EXPORTS.items():
        path = args.export_dir / filename
        collection = json.loads(path.read_text(encoding="utf-8"))
        features = collection.get("features", [])
        export_counts[layer] = len(features)
        expected = source_counts[layer]
        if len(features) != expected:
            raise SystemExit(
                f"{filename} has {len(features)} features; GeoPackage has {expected}"
            )

        if layer == "nodes":
            export_ids = {
                str(feature.get("properties", {}).get("node_id", "")).strip()
                for feature in features
            }
            if export_ids != node_ids:
                raise SystemExit("nodes_v3.geojson IDs do not match GeoPackage nodes")
        if layer == "edges":
            export_ids = {
                str(feature.get("properties", {}).get("edge_id", "")).strip()
                for feature in features
            }
            if export_ids != edge_ids:
                raise SystemExit("edges_v3.geojson IDs do not match GeoPackage edges")

    missing_project_sources = validate_project(args.project)
    if missing_project_sources:
        raise SystemExit(
            "QGIS project references missing local data sources:\n"
            + "\n".join(missing_project_sources)
        )

    report = {
        "source_layers": source_counts,
        "runtime_exports": export_counts,
        "crs": "EPSG:32636",
        "runtime_crs": "EPSG:4326",
        "node_count": len(node_ids),
        "edge_count": len(edge_ids),
        "one_way_edges": sorted(one_way_edges),
        "weak_geometry_components": component_sizes,
        "endpoint_offset_warnings_over_1m": endpoint_warnings,
        "unverified_edges": sorted(unverified_edges),
        "qgis_project": str(args.project),
        "qgis_project_local_sources": "all resolved",
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
