#!/usr/bin/env python3
"""Audit requested campus node-to-node paths in exported V3 GeoJSON."""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets" / "campus_map_v3" / "exported"
NODES_FILE = DATA / "nodes.geojson"
EDGES_FILE = DATA / "edges.geojson"
ROUTES = (
    ("E1", "J90_4", "J90_2", "AR1"),
    ("E1", "J90_3", "J90_2", "AR1"),
)
ENDPOINT_TOLERANCE_METERS = 5.0


def norm(value: Any) -> str:
    return str(value).strip().upper() if value is not None else ""


def prop(properties: dict[str, Any], *names: str) -> Any:
    lookup = {str(k).lower().replace("_", "").replace("-", ""): v
              for k, v in properties.items()}
    for name in names:
        value = lookup.get(name.lower().replace("_", "").replace("-", ""))
        if value is not None and str(value).strip():
            return value
    return None


def load_features(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        raise FileNotFoundError(
            f"Missing {path}. Run tools/export_campus_geopackage.py first."
        )
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("type") != "FeatureCollection":
        raise ValueError(f"{path} is not a GeoJSON FeatureCollection.")
    return payload.get("features", [])


def distance_m(a: list[float], b: list[float]) -> float:
    radius = 6371000.0
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    dlat = math.radians(b[1] - a[1])
    dlon = math.radians(b[0] - a[0])
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    return radius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h))


def main() -> int:
    node_features = load_features(NODES_FILE)
    edge_features = load_features(EDGES_FILE)

    nodes: dict[str, list[float]] = {}
    for feature in node_features:
        props = feature.get("properties") or {}
        geometry = feature.get("geometry") or {}
        if geometry.get("type") != "Point":
            continue
        coordinates = geometry.get("coordinates") or []
        node_id = norm(prop(props, "node_id", "nodeid", "id", "node"))
        if node_id and len(coordinates) >= 2:
            nodes[node_id] = [float(coordinates[0]), float(coordinates[1])]

    edges: list[dict[str, Any]] = []
    for feature in edge_features:
        props = feature.get("properties") or {}
        geometry = feature.get("geometry") or {}
        if geometry.get("type") != "LineString":
            continue
        coordinates = geometry.get("coordinates") or []
        if len(coordinates) < 2:
            continue
        edges.append({
            "id": prop(props, "edge_id", "edgeid", "id") or props.get("_source_fid"),
            "from": norm(prop(props, "from_node", "fromnode", "start_node", "source_node")),
            "to": norm(prop(props, "to_node", "tonode", "end_node", "target_node")),
            "coordinates": coordinates,
        })

    print(f"Loaded {len(nodes)} point IDs and {len(edges)} line features.")
    failures = 0

    for route in ROUTES:
        print("\nRoute: " + " -> ".join(route))
        route_ok = True
        for node_id in route:
            if node_id not in nodes:
                print(f"  MISSING NODE: {node_id}")
                route_ok = False
                failures += 1

        for start, end in zip(route, route[1:]):
            matches = [
                edge for edge in edges
                if (edge["from"], edge["to"]) in ((start, end), (end, start))
            ]
            if not matches:
                print(f"  MISSING EDGE: {start} <-> {end} (from_node/to_node attributes)")
                route_ok = False
                failures += 1
                continue

            best_gap = float("inf")
            best_edge = None
            for edge in matches:
                coords = edge["coordinates"]
                if (edge["from"], edge["to"]) == (start, end):
                    gap = distance_m(nodes[start], coords[0]) + distance_m(nodes[end], coords[-1])
                else:
                    gap = distance_m(nodes[start], coords[-1]) + distance_m(nodes[end], coords[0])
                if gap < best_gap:
                    best_gap, best_edge = gap, edge

            if best_edge is not None:
                coords = best_edge["coordinates"]
                if (best_edge["from"], best_edge["to"]) == (start, end):
                    start_gap = distance_m(nodes[start], coords[0])
                    end_gap = distance_m(nodes[end], coords[-1])
                else:
                    start_gap = distance_m(nodes[start], coords[-1])
                    end_gap = distance_m(nodes[end], coords[0])
                if max(start_gap, end_gap) > ENDPOINT_TOLERANCE_METERS:
                    print(
                        f"  EDGE {start} <-> {end}: endpoint mismatch "
                        f"(start {start_gap:.2f} m, end {end_gap:.2f} m)"
                    )
                    route_ok = False
                    failures += 1
                else:
                    print(
                        f"  OK: {start} <-> {end} via edge {best_edge['id']} "
                        f"(endpoint gaps {start_gap:.2f} m / {end_gap:.2f} m)"
                    )

        print("  RESULT: " + ("PASS" if route_ok else "FAIL"))

    print("\nOverall: " + ("PASS" if failures == 0 else f"FAIL ({failures} issue(s))"))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"AUDIT ERROR: {exc}", file=sys.stderr)
        sys.exit(2)
