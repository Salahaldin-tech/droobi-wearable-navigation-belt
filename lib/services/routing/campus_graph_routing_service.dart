import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import '../campus_map/campus_map_source.dart';
import 'routing_service.dart';

/// Experimental offline campus router built from the QGIS GeoJSON export.
/// Edge LineStrings are the routing graph; explicit from_node/to_node IDs define junctions when they match the node layer;
/// shared coordinates remain the fallback for edges without usable endpoint IDs.
class CampusGraphRoutingService implements RoutingService {
  CampusGraphRoutingService({
    this.maximumSnapMeters = 45.0,
    Future<String> Function(String assetPath)? assetLoader,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString;

  final double maximumSnapMeters;
  final Future<String> Function(String assetPath) _assetLoader;
  Future<_CampusGraph>? _graphFuture;

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    final graph = await (_graphFuture ??= _loadGraph());
    if (graph.segments.isEmpty || graph.adjacency.isEmpty) {
      throw const RoutingFailure(RoutingErrorType.noRouteFound,
          'The QGIS campus network contains no usable pedestrian edges.');
    }

    // GPS can fall almost equally close to parallel or intersecting edges.
    // Evaluate several nearby candidates instead of committing to one snap.
    final nearestOriginSnaps = _nearestSegments(origin, graph.segments);
    final nearestDestinationSnaps =
        _nearestSegments(destination, graph.segments);

    final nearestOriginDistance =
        nearestOriginSnaps.first.distanceMeters;
    final nearestDestinationDistance =
        nearestDestinationSnaps.first.distanceMeters;

    if (nearestOriginDistance > maximumSnapMeters) {
      throw RoutingFailure(RoutingErrorType.noRouteFound,
          'GPS_SNAP_ORIGIN: current position is '
          '${nearestOriginDistance.toStringAsFixed(1)} m from the nearest '
          'QGIS path (maximum ${maximumSnapMeters.toStringAsFixed(0)} m).');
    }
    if (nearestDestinationDistance > maximumSnapMeters) {
      throw RoutingFailure(RoutingErrorType.noRouteFound,
          'GPS_SNAP_DESTINATION: destination is '
          '${nearestDestinationDistance.toStringAsFixed(1)} m from the nearest '
          'QGIS path (maximum ${maximumSnapMeters.toStringAsFixed(0)} m). '
          'A real connecting edge may be missing from the campus map.');
    }

    final originSnaps = nearestOriginSnaps
        .where((snap) => snap.distanceMeters <= maximumSnapMeters)
        .toList();
    final destinationSnaps = nearestDestinationSnaps
        .where((snap) => snap.distanceMeters <= maximumSnapMeters)
        .toList();

    RouteResult? bestRoute;

    // Test combinations because the closest origin edge may belong to a
    // disconnected spur while the next-nearest edge is connected to the goal.
    for (final originSnap in originSnaps) {
      for (final destinationSnap in destinationSnaps) {
        final adjacency = <String, List<_Arc>>{
          for (final entry in graph.adjacency.entries)
            entry.key: List<_Arc>.from(entry.value),
        };
        final points = Map<String, LatLon>.from(graph.points);
        const originKey = '__campus_origin__';
        const destinationKey = '__campus_destination__';
        points[originKey] = originSnap.point;
        points[destinationKey] = destinationSnap.point;
        adjacency[originKey] = <_Arc>[];
        adjacency[destinationKey] = <_Arc>[];

        _attachOrigin(adjacency, originKey, originSnap);
        _attachDestination(adjacency, destinationKey, destinationSnap);

        if (identical(originSnap.segment, destinationSnap.segment)) {
          final distance = (destinationSnap.fraction -
                  originSnap.fraction).abs() *
              originSnap.segment.lengthMeters;
          _addArc(adjacency, originKey, destinationKey, distance);
          _addArc(adjacency, destinationKey, originKey, distance);
        }

        final pathKeys = _shortestPath(adjacency, originKey, destinationKey);
        if (pathKeys == null || pathKeys.length < 2) continue;

        // Start at the snapped point on the mapped pedestrian network.
        // Do not treat the straight GPS-to-edge snap connector as a walkable
        // route segment or use it to determine the first vibration cue.
        final routePoints = <LatLon>[originSnap.point];
        for (final key in pathKeys) {
          final point = points[key];
          if (point != null) _appendDistinct(routePoints, point);
        }
        _appendDistinct(routePoints, destination);

        var distanceMeters = 0.0;
        for (var i = 1; i < routePoints.length; i++) {
          distanceMeters += _distance(routePoints[i - 1], routePoints[i]);
        }

        if (bestRoute == null ||
            distanceMeters < bestRoute.distanceMeters) {
          bestRoute = RouteResult(
            polyline: routePoints,
            distanceMeters: distanceMeters,
            durationSeconds: distanceMeters,
          );
        }
      }
    }

    if (bestRoute == null) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'GRAPH_CONNECTIVITY: no route was found after testing '
        '${originSnaps.length} nearby start edges and '
        '${destinationSnaps.length} nearby destination edges within '
        '${maximumSnapMeters.toStringAsFixed(0)} m. All QGIS edges are '
        'treated as bidirectional. Check for a missing connecting edge or '
        'a coordinate gap in edges.geojson.',
      );
    }

    return bestRoute;
  }

  Future<_CampusGraph> _loadGraph() async {
    try {
      // Load only the two named layers exported from the exact main-branch
      // GeoPackage blob. There is deliberately no V2, Firestore, OSRM, or
      // alternate-asset fallback for campus navigation.
      final nodesJson = CampusMapSource.decodeAndValidate(
        await _assetLoader(CampusMapSource.nodesAsset),
        expectedLayer: CampusMapSource.nodesLayer,
      );
      final edgesJson = CampusMapSource.decodeAndValidate(
        await _assetLoader(CampusMapSource.edgesAsset),
        expectedLayer: CampusMapSource.edgesLayer,
      );
      final nodeFeatures = nodesJson['features'] as List<dynamic>? ?? const [];
      final nodeCoordinates = <String, LatLon>{};
      var validNodeCount = 0;
      for (final feature in nodeFeatures) {
        if (feature is! Map<String, dynamic>) continue;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'Point') continue;
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;
        final longitude = (coordinates[0] as num?)?.toDouble();
        final latitude = (coordinates[1] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;
        validNodeCount++;
        final nodeId = _readProperty(
          properties,
          const ['node_id', 'nodeid', 'id', 'node'],
        );
        if (nodeId != null) {
          final normalizedId = _normalizeNodeId(nodeId);
          final coordinate = LatLon(latitude: latitude, longitude: longitude);
          final previous = nodeCoordinates[normalizedId];
          if (previous != null && _distance(previous, coordinate) > 5.0) {
            throw FormatException(
              'Duplicate QGIS node ID $normalizedId has conflicting coordinates.',
            );
          }
          nodeCoordinates[normalizedId] = coordinate;
        }
      }

      final edgeFeatures = edgesJson['features'] as List<dynamic>? ?? const [];
      final adjacency = <String, List<_Arc>>{};
      final points = <String, LatLon>{};
      final segments = <_Segment>[];
      var edgeFeatureIndex = 0;
      for (final feature in edgeFeatures) {
        if (feature is! Map<String, dynamic>) {
          edgeFeatureIndex++;
          continue;
        }
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
        final edgeId = (properties['edge_id']?.toString().trim().isNotEmpty ?? false)
            ? properties['edge_id'].toString().trim()
            : 'edge_$edgeFeatureIndex';
        edgeFeatureIndex++;
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'LineString') continue;
        final rawCoordinates = geometry['coordinates'] as List<dynamic>?;
        if (rawCoordinates == null || rawCoordinates.length < 2) continue;
        final line = <LatLon>[];
        for (final raw in rawCoordinates) {
          if (raw is! List || raw.length < 2) continue;
          final lon = (raw[0] as num?)?.toDouble();
          final lat = (raw[1] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          line.add(LatLon(latitude: lat, longitude: lon));
        }
        if (line.length < 2) continue;

        // Use explicit QGIS endpoint IDs when they resolve to the node layer.
        // This joins edges by logical node identity, not coordinate equality alone.
        final declaredFromNodeId = _readProperty(
          properties,
          const ['from_node', 'fromnode', 'start_node', 'source_node'],
        );
        final declaredToNodeId = _readProperty(
          properties,
          const ['to_node', 'tonode', 'end_node', 'target_node'],
        );
        final declaredFromNode = declaredFromNodeId == null
            ? null
            : nodeCoordinates[_normalizeNodeId(declaredFromNodeId)];
        final declaredToNode = declaredToNodeId == null
            ? null
            : nodeCoordinates[_normalizeNodeId(declaredToNodeId)];

        // Trust a declared endpoint ID only if it resolves to a real point
        // in the verified campus_network layer and is spatially consistent.
        // Otherwise infer a node only within 3 m; if none exists, the graph
        // falls back to shared line coordinates rather than an unknown ID.
        final fromNodeId = declaredFromNode != null &&
                _distance(declaredFromNode, line.first) <= 5.0
            ? declaredFromNodeId
            : _nearestNodeId(line.first, nodeCoordinates);
        final toNodeId = declaredToNode != null &&
                _distance(declaredToNode, line.last) <= 5.0
            ? declaredToNodeId
            : _nearestNodeId(line.last, nodeCoordinates);
        final fromNode = fromNodeId == null
            ? null
            : nodeCoordinates[_normalizeNodeId(fromNodeId)];
        final toNode = toNodeId == null
            ? null
            : nodeCoordinates[_normalizeNodeId(toNodeId)];
        final useFromNode = fromNodeId != null &&
            fromNode != null && _distance(fromNode, line.first) <= 5.0;
        final useToNode = toNodeId != null &&
            toNode != null && _distance(toNode, line.last) <= 5.0;

        final effectiveLine = List<LatLon>.from(line);
        if (useFromNode && fromNode != null) {
          effectiveLine[0] = fromNode;
        }
        if (useToNode && toNode != null) {
          effectiveLine[effectiveLine.length - 1] = toNode;
        }

        final vertexKeys = <String>[];
        for (var i = 0; i < effectiveLine.length; i++) {
          final point = effectiveLine[i];
          final key = i == 0 && useFromNode
              ? 'node:${_normalizeNodeId(fromNodeId!)}'
              : i == effectiveLine.length - 1 && useToNode
                  ? 'node:${_normalizeNodeId(toNodeId!)}'
                  : _key(point);
          vertexKeys.add(key);
          points.putIfAbsent(key, () => point);
        }

        for (var i = 0; i < effectiveLine.length - 1; i++) {
          final from = effectiveLine[i];
          final to = effectiveLine[i + 1];
          final length = _distance(from, to);
          if (length < 0.05) continue;
          final fromKey = vertexKeys[i];
          final toKey = vertexKeys[i + 1];
          adjacency.putIfAbsent(fromKey, () => <_Arc>[]);
          adjacency.putIfAbsent(toKey, () => <_Arc>[]);
          _addArc(adjacency, fromKey, toKey, length);
          _addArc(adjacency, toKey, fromKey, length);
          segments.add(_Segment(
            fromKey: fromKey,
            toKey: toKey,
            from: from,
            to: to,
            lengthMeters: length,
            edgeId: edgeId,
          ));
        }
      }
      if (validNodeCount == 0) {
        throw const FormatException('The QGIS nodes GeoJSON contains no valid Point features.');
      }
      return _CampusGraph(adjacency: adjacency, points: points, segments: segments);
    } catch (error) {
      throw RoutingFailure(
        RoutingErrorType.apiError,
        'Could not load the verified main-branch campus map: ' +
            error.toString(),
      );
    }
  }

  static String? _readProperty(
    Map<String, dynamic> properties,
    List<String> candidates,
  ) {
    final normalized = <String, dynamic>{
      for (final entry in properties.entries)
        entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''):
            entry.value,
    };
    for (final candidate in candidates) {
      final value = normalized[
          candidate.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static String _normalizeNodeId(String value) =>
      value.trim().toUpperCase();

  static String? _nearestNodeId(
    LatLon endpoint,
    Map<String, LatLon> nodes, {
    double maximumDistanceMeters = 3.0,
  }) {
    String? nearestId;
    var nearestDistance = maximumDistanceMeters;
    for (final entry in nodes.entries) {
      final distance = _distance(endpoint, entry.value);
      if (distance <= nearestDistance) {
        nearestDistance = distance;
        nearestId = entry.key;
      }
    }
    return nearestId;
  }

  List<_Snap> _nearestSegments(
    LatLon position,
    List<_Segment> segments, {
    int maximumCandidates = 8,
  }) {
    // Keep one best geometric snap per QGIS Edge feature. Without this,
    // eight adjacent LineString sub-segments from one road can crowd out
    // nearby alternative roads at a junction.
    final bestByEdge = <String, _Snap>{};
    for (final segment in segments) {
      final projection = _project(position, segment.from, segment.to);
      final snap = _Snap(
        segment: segment,
        point: projection.point,
        fraction: projection.fraction,
        distanceMeters: _distance(position, projection.point),
      );
      final previous = bestByEdge[segment.edgeId];
      if (previous == null || snap.distanceMeters < previous.distanceMeters) {
        bestByEdge[segment.edgeId] = snap;
      }
    }
    final snaps = bestByEdge.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return snaps.take(maximumCandidates).toList();
  }

  void _attachOrigin(Map<String, List<_Arc>> graph, String key, _Snap snap) {
    final segment = snap.segment;
    final toStart = snap.fraction * segment.lengthMeters;
    final toEnd = (1 - snap.fraction) * segment.lengthMeters;
    _addArc(graph, key, segment.fromKey, toStart);
    _addArc(graph, segment.fromKey, key, toStart);
    _addArc(graph, key, segment.toKey, toEnd);
    _addArc(graph, segment.toKey, key, toEnd);
  }

  void _attachDestination(
    Map<String, List<_Arc>> graph,
    String key,
    _Snap snap,
  ) {
    final segment = snap.segment;
    final toStart = snap.fraction * segment.lengthMeters;
    final toEnd = (1 - snap.fraction) * segment.lengthMeters;
    _addArc(graph, segment.fromKey, key, toStart);
    _addArc(graph, key, segment.fromKey, toStart);
    _addArc(graph, segment.toKey, key, toEnd);
    _addArc(graph, key, segment.toKey, toEnd);
  }

  List<String>? _shortestPath(Map<String, List<_Arc>> graph, String start, String goal) {
    final distances = <String, double>{start: 0};
    final previous = <String, String>{};
    final unvisited = <String>{...graph.keys, start, goal};
    while (unvisited.isNotEmpty) {
      String? current;
      var bestDistance = double.infinity;
      for (final candidate in unvisited) {
        final distance = distances[candidate] ?? double.infinity;
        if (distance < bestDistance) {
          bestDistance = distance;
          current = candidate;
        }
      }
      if (current == null || bestDistance == double.infinity) break;
      if (current == goal) break;
      unvisited.remove(current);
      for (final arc in graph[current] ?? const <_Arc>[]) {
        if (!unvisited.contains(arc.to)) continue;
        final candidateDistance = bestDistance + arc.weight;
        if (candidateDistance < (distances[arc.to] ?? double.infinity)) {
          distances[arc.to] = candidateDistance;
          previous[arc.to] = current;
        }
      }
    }
    if (!distances.containsKey(goal)) return null;
    final path = <String>[goal];
    var cursor = goal;
    while (cursor != start) {
      final parent = previous[cursor];
      if (parent == null) return null;
      path.add(parent);
      cursor = parent;
    }
    return path.reversed.toList();
  }

  static void _addArc(Map<String, List<_Arc>> graph, String from, String to, double weight) {
    graph.putIfAbsent(from, () => <_Arc>[]).add(_Arc(to, weight));
  }

  static void _appendDistinct(List<LatLon> points, LatLon point) {
    if (points.isEmpty || _distance(points.last, point) > 0.2) points.add(point);
  }

  static String _key(LatLon point) =>
      point.latitude.toStringAsFixed(6) + ',' + point.longitude.toStringAsFixed(6);

  static _Projection _project(LatLon point, LatLon start, LatLon end) {
    const metersPerDegree = 111320.0;
    final longitudeScale = metersPerDegree * math.cos(point.latitude * math.pi / 180);
    final px = (point.longitude - start.longitude) * longitudeScale;
    final py = (point.latitude - start.latitude) * metersPerDegree;
    final sx = (end.longitude - start.longitude) * longitudeScale;
    final sy = (end.latitude - start.latitude) * metersPerDegree;
    final lengthSquared = sx * sx + sy * sy;
    final fraction = lengthSquared == 0 ? 0.0 :
        ((px * sx + py * sy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    return _Projection(
      point: LatLon(
        latitude: start.latitude + (end.latitude - start.latitude) * fraction,
        longitude: start.longitude + (end.longitude - start.longitude) * fraction,
      ),
      fraction: fraction,
    );
  }

  static double _distance(LatLon a, LatLon b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

class _CampusGraph {
  const _CampusGraph({required this.adjacency, required this.points, required this.segments});
  final Map<String, List<_Arc>> adjacency;
  final Map<String, LatLon> points;
  final List<_Segment> segments;
}
class _Arc {
  const _Arc(this.to, this.weight);
  final String to;
  final double weight;
}
class _Segment {
  const _Segment({
    required this.fromKey, required this.toKey, required this.from,
    required this.to, required this.lengthMeters, required this.edgeId,
  });
  final String fromKey;
  final String toKey;
  final LatLon from;
  final LatLon to;
  final double lengthMeters;
  final String edgeId;
}
class _Snap {
  const _Snap({
    required this.segment, required this.point, required this.fraction,
    required this.distanceMeters,
  });
  final _Segment segment;
  final LatLon point;
  final double fraction;
  final double distanceMeters;
}
class _Projection {
  const _Projection({required this.point, required this.fraction});
  final LatLon point;
  final double fraction;
}
