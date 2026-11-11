#!/usr/bin/env python3
"""Export point and pedestrian-line layers from the campus GeoPackage to WGS84 GeoJSON.

Run with the Python environment bundled with QGIS/GDAL:
  python export_campus_geopackage.py

Optional:
  python export_campus_geopackage.py --input assets/campus_map_v3/campus_network.gpkg
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from osgeo import ogr, osr


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "assets" / "campus_map_v3" / "campus_network.gpkg"
DEFAULT_OUTPUT = ROOT / "assets" / "campus_map_v3" / "exported"
EXPECTED_GPKG_BLOB_SHA1 = "a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41"
EXPECTED_PROJECT_BLOB_SHA1 = "ae94aaf49c669bc5e8147ec94b863711a8f3d998"
EXPECTED_POINT_LAYER = "campus_network"
EXPECTED_LINE_LAYER = "edges"
EXPECTED_POINT_FEATURES = 14
EXPECTED_LINE_FEATURES = 7


def json_value(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def normalized_field_name(value: str) -> str:
    return "".join(ch for ch in value.lower() if ch.isalnum())


def find_value(properties: dict[str, Any], candidates: tuple[str, ...]) -> Any:
    normalized = {normalized_field_name(k): v for k, v in properties.items()}
    for candidate in candidates:
        value = normalized.get(normalized_field_name(candidate))
        if value is not None and str(value).strip():
            return value
    return None


def make_feature(geometry: ogr.Geometry, properties: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "Feature",
        "geometry": json.loads(geometry.ExportToJson()),
        "properties": properties,
    }


def flatten_geometries(geometry: ogr.Geometry, wanted: int):
    """Yield individual Point or LineString geometries from simple/multi inputs."""
    flat_type = ogr.GT_Flatten(geometry.GetGeometryType())
    if flat_type == wanted:
        yield geometry.Clone()
        return
    multi_type = ogr.wkbMultiPoint if wanted == ogr.wkbPoint else ogr.wkbMultiLineString
    if flat_type == multi_type:
        for index in range(geometry.GetGeometryCount()):
            child = geometry.GetGeometryRef(index)
            if child is not None and ogr.GT_Flatten(child.GetGeometryType()) == wanted:
                yield child.Clone()


def export_layers(gpkg_path: Path, output_dir: Path) -> None:
    if not gpkg_path.is_file():
        raise FileNotFoundError(f"GeoPackage not found: {gpkg_path}")

    gpkg_bytes = gpkg_path.read_bytes()
    git_blob_payload = b"blob " + str(len(gpkg_bytes)).encode("ascii") + b"\\0" + gpkg_bytes
    actual_blob_sha1 = hashlib.sha1(git_blob_payload).hexdigest()
    if actual_blob_sha1 != EXPECTED_GPKG_BLOB_SHA1:
        raise RuntimeError(
            "The supplied GeoPackage is not the exact campus_network.gpkg "
            "blob copied from main. Expected " + EXPECTED_GPKG_BLOB_SHA1 +
            ", received " + actual_blob_sha1 + "."
        )

    source = ogr.Open(str(gpkg_path), 0)
    if source is None:
        raise RuntimeError(f"GDAL could not open GeoPackage: {gpkg_path}")

    target_srs = osr.SpatialReference()
    target_srs.ImportFromEPSG(4326)
    if hasattr(target_srs, "SetAxisMappingStrategy"):
        target_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)

    point_features: list[dict[str, Any]] = []
    line_features: list[dict[str, Any]] = []
    layer_report: list[dict[str, Any]] = []

    point_layers = []
    line_layers = []
    for layer_index in range(source.GetLayerCount()):
        layer = source.GetLayerByIndex(layer_index)
        if layer is None:
            continue
        geometry_type = ogr.GT_Flatten(layer.GetGeomType())
        if geometry_type in (ogr.wkbPoint, ogr.wkbMultiPoint):
            point_layers.append(layer)
        elif geometry_type in (ogr.wkbLineString, ogr.wkbMultiLineString):
            line_layers.append(layer)

    def find_exact_layer(candidates, expected_name, label):
        matches = [
            layer for layer in candidates
            if normalized_field_name(layer.GetName()) ==
            normalized_field_name(expected_name)
        ]
        if len(matches) != 1:
            raise RuntimeError(
                "Expected exactly one " + label + " layer named '" +
                expected_name + "', found: " +
                str([layer.GetName() for layer in candidates])
            )
        return matches[0]

    point_layer = find_exact_layer(
        point_layers, EXPECTED_POINT_LAYER, "point"
    )
    line_layer = find_exact_layer(
        line_layers, EXPECTED_LINE_LAYER, "pedestrian line"
    )
    if point_layer.GetFeatureCount() != EXPECTED_POINT_FEATURES:
        raise RuntimeError(
            "Unexpected campus_network feature count: " +
            str(point_layer.GetFeatureCount()) + ". Expected " +
            str(EXPECTED_POINT_FEATURES) + "."
        )
    if line_layer.GetFeatureCount() != EXPECTED_LINE_FEATURES:
        raise RuntimeError(
            "Unexpected edges feature count: " +
            str(line_layer.GetFeatureCount()) + ". Expected " +
            str(EXPECTED_LINE_FEATURES) + "."
        )

    selected_layers = [point_layer, line_layer]

    for layer in selected_layers:
        geometry_type = ogr.GT_Flatten(layer.GetGeomType())
        is_point = geometry_type in (ogr.wkbPoint, ogr.wkbMultiPoint)
        is_line = geometry_type in (ogr.wkbLineString, ogr.wkbMultiLineString)

        source_srs = layer.GetSpatialRef()
        if source_srs is None:
            raise RuntimeError(
                f"Layer '{layer.GetName()}' has no CRS. Assign its real CRS in QGIS first."
            )
        source_srs = source_srs.Clone()
        if hasattr(source_srs, "SetAxisMappingStrategy"):
            source_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        transform = osr.CoordinateTransformation(source_srs, target_srs)

        definition = layer.GetLayerDefn()
        exported_count = 0
        layer.ResetReading()
        for feature in layer:
            source_geometry = feature.GetGeometryRef()
            if source_geometry is None:
                continue

            geometry = source_geometry.Clone()
            if geometry.Transform(transform) != 0:
                raise RuntimeError(
                    f"Could not transform geometry in layer '{layer.GetName()}'."
                )

            properties = {
                definition.GetFieldDefn(i).GetNameRef(): json_value(feature.GetField(i))
                for i in range(definition.GetFieldCount())
            }
            properties["_source_layer"] = layer.GetName()
            properties["_source_fid"] = int(feature.GetFID())

            if is_point:
                node_id = find_value(
                    properties, ("node_id", "nodeid", "node", "id", "fid")
                )
                node_name = find_value(
                    properties, ("name", "node_name", "label", "description")
                )
                properties["node_id"] = (
                    str(node_id).strip() if node_id is not None
                    else f"{layer.GetName()}_{feature.GetFID()}"
                )
                properties["name"] = (
                    str(node_name).strip() if node_name is not None
                    else str(properties["node_id"])
                )
                for part_index, part in enumerate(flatten_geometries(geometry, ogr.wkbPoint)):
                    item_properties = dict(properties)
                    if geometry.GetGeometryCount() > 1:
                        item_properties["_part_index"] = part_index
                    point_features.append(make_feature(part, item_properties))
                    exported_count += 1
            else:
                edge_id = find_value(
                    properties, ("edge_id", "edgeid", "path_id", "id", "fid")
                )
                from_node = find_value(
                    properties, ("from_node", "fromnode", "start_node", "startnode", "source_node")
                )
                to_node = find_value(
                    properties, ("to_node", "tonode", "end_node", "endnode", "target_node")
                )
                properties["edge_id"] = (
                    str(edge_id).strip() if edge_id is not None
                    else f"{layer.GetName()}_{feature.GetFID()}"
                )
                if from_node is not None:
                    properties.setdefault("from_node", str(from_node).strip())
                if to_node is not None:
                    properties.setdefault("to_node", str(to_node).strip())

                for part_index, part in enumerate(flatten_geometries(geometry, ogr.wkbLineString)):
                    item_properties = dict(properties)
                    if geometry.GetGeometryCount() > 1:
                        item_properties["_part_index"] = part_index
                    line_features.append(make_feature(part, item_properties))
                    exported_count += 1

        layer_report.append({
            "layer": layer.GetName(),
            "geometry_type": ogr.GeometryTypeToName(layer.GetGeomType()),
            "exported_features": exported_count,
        })

    if not point_features:
        raise RuntimeError("No Point/MultiPoint features were found in the GeoPackage.")
    if not line_features:
        raise RuntimeError("No LineString/MultiLineString features were found in the GeoPackage.")

    output_dir.mkdir(parents=True, exist_ok=True)
    nodes_path = output_dir / "nodes.geojson"
    edges_path = output_dir / "edges.geojson"

    def collection(features, layer_name):
        return {
            "type": "FeatureCollection",
            "metadata": {
                "source_repository": "Salahaldin-tech/droobi-wearable-navigation-belt",
                "source_branch": "main",
                "source_path": "assets/campus_map_v3/campus_network.gpkg",
                "source_git_blob_sha1": EXPECTED_GPKG_BLOB_SHA1,
                "source_project_path": "assets/campus_map_v3/AAUP_Campus_Network.qgz",
                "source_project_git_blob_sha1": EXPECTED_PROJECT_BLOB_SHA1,
                "source_layer": layer_name,
                "crs": "EPSG:4326",
            },
            "features": features,
        }

    nodes_path.write_text(
        json.dumps(collection(point_features, EXPECTED_POINT_LAYER),
                   ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    edges_path.write_text(
        json.dumps(collection(line_features, EXPECTED_LINE_LAYER),
                   ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(json.dumps({
        "source": str(gpkg_path),
        "output_nodes": str(nodes_path),
        "output_edges": str(edges_path),
        "node_feature_count": len(point_features),
        "edge_feature_count": len(line_features),
        "layers": layer_report,
        "crs": "EPSG:4326",
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    export_layers(args.input, args.output_dir)
