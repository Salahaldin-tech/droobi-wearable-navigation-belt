#!/usr/bin/env python3
"""Export Droobi's QGIS GeoPackage layers to WGS84 GeoJSON.

Usage:
  python tooling/export_campus_gpkg_to_geojson.py \
    --input assets/campus_map_v3/campus_network.gpkg \
    --output-dir docs/campus-mapping

Only Python's standard library is required. Source geometries and feature
attributes are preserved; only coordinate reference conversion is applied.
"""
from __future__ import annotations

import argparse
import json
import math
import sqlite3
import struct
from pathlib import Path
from typing import Any

ALIASES = {"J90-0": "J90_0", "J90_4": "J90-4", "AWS_B": "AMS_B"}
LAYERS = {
    "nodes": ("geom", "nodes_v3.geojson"),
    "edges": ("geometry", "edges_v3.geojson"),
    "buildings": ("geometry", "buildings_v3.geojson"),
    "barriers": ("geometry", "barriers_v3.geojson"),
}


def utm36_to_wgs84(easting: float, northing: float) -> list[float]:
    """Inverse UTM projection for EPSG:32636; return GeoJSON [lon, lat]."""
    a, eccentricity, scale = 6378137.0, 0.08181919084262149, 0.9996
    e2 = eccentricity**2
    e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2))
    x, y = easting - 500000.0, northing / scale
    mu = y / (a * (1 - e2 / 4 - 3 * e2**2 / 64 - 5 * e2**3 / 256))
    fp = (
        mu
        + (3 * e1 / 2 - 27 * e1**3 / 32) * math.sin(2 * mu)
        + (21 * e1**2 / 16 - 55 * e1**4 / 32) * math.sin(4 * mu)
        + (151 * e1**3 / 96) * math.sin(6 * mu)
        + (1097 * e1**4 / 512) * math.sin(8 * mu)
    )
    ep2 = e2 / (1 - e2)
    c1, t1 = ep2 * math.cos(fp) ** 2, math.tan(fp) ** 2
    n1 = a / math.sqrt(1 - e2 * math.sin(fp) ** 2)
    r1 = a * (1 - e2) / (1 - e2 * math.sin(fp) ** 2) ** 1.5
    d = x / (n1 * scale)
    lat = fp - (n1 * math.tan(fp) / r1) * (
        d**2 / 2
        - (5 + 3 * t1 + 10 * c1 - 4 * c1**2 - 9 * ep2) * d**4 / 24
        + (61 + 90 * t1 + 298 * c1 + 45 * t1**2 - 252 * ep2 - 3 * c1**2) * d**6 / 720
    )
    lon = math.radians(33) + (
        d
        - (1 + 2 * t1 + c1) * d**3 / 6
        + (5 - 2 * c1 + 28 * t1 - 3 * c1**2 + 8 * ep2 + 24 * t1**2) * d**5 / 120
    ) / math.cos(fp)
    return [math.degrees(lon), math.degrees(lat)]


def read_geometry(blob: bytes) -> dict[str, Any]:
    if blob[:2] != b"GP" or len(blob) < 13:
        raise ValueError("Invalid GeoPackage geometry blob")
    flags = blob[3]
    envelope_type = (flags >> 1) & 7
    envelope_doubles = {0: 0, 1: 4, 2: 6, 3: 6, 4: 8}.get(envelope_type)
    if envelope_doubles is None:
        raise ValueError(f"Unsupported GeoPackage envelope type: {envelope_type}")
    offset = 8 + envelope_doubles * 8
    endian = "<" if blob[offset] == 1 else ">"
    offset += 1
    geometry_type = struct.unpack_from(endian + "I", blob, offset)[0] & 0xFF
    offset += 4

    def uint32() -> int:
        nonlocal offset
        value = struct.unpack_from(endian + "I", blob, offset)[0]
        offset += 4
        return value

    def xy() -> list[float]:
        nonlocal offset
        value = list(struct.unpack_from(endian + "dd", blob, offset))
        offset += 16
        return value

    if geometry_type == 1:
        return {"type": "Point", "coordinates": xy()}
    if geometry_type == 2:
        return {"type": "LineString", "coordinates": [xy() for _ in range(uint32())]}
    if geometry_type == 3:
        return {
            "type": "Polygon",
            "coordinates": [
                [xy() for _ in range(uint32())] for _ in range(uint32())
            ],
        }
    raise ValueError(f"Unsupported WKB geometry type: {geometry_type}")


def transform_coordinates(geometry: dict[str, Any]) -> dict[str, Any]:
    def transform(value: Any) -> Any:
        if isinstance(value, list) and len(value) == 2 and all(
            isinstance(x, (int, float)) for x in value
        ):
            return utm36_to_wgs84(float(value[0]), float(value[1]))
        return [transform(item) for item in value]
    return {"type": geometry["type"], "coordinates": transform(geometry["coordinates"])}


def feature_collection(connection: sqlite3.Connection, table: str, geometry_column: str):
    cursor = connection.execute(f'SELECT * FROM "{table}" ORDER BY fid')
    columns = [column[0] for column in cursor.description]
    features = []
    for row in cursor:
        values = dict(zip(columns, row))
        geometry = transform_coordinates(read_geometry(values.pop(geometry_column)))
        features.append({
            "type": "Feature",
            "id": values.get("fid"),
            "properties": values,
            "geometry": geometry,
        })
    return {"type": "FeatureCollection", "features": features}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(args.input) as connection:
        srs = connection.execute(
            "SELECT srs_id FROM gpkg_geometry_columns WHERE table_name='nodes'"
        ).fetchone()
        if srs is None or srs[0] != 32636:
            raise SystemExit(f"Expected EPSG:32636 GeoPackage; found {srs!r}")
        for table, (geometry_column, filename) in LAYERS.items():
            collection = feature_collection(connection, table, geometry_column)
            target = args.output_dir / filename
            target.write_text(
                json.dumps(collection, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(f"{table}: {len(collection['features'])} -> {target}")


if __name__ == "__main__":
    main()
