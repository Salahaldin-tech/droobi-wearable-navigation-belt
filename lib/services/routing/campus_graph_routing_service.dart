import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// Experimental offline campus router built from the QGIS GeoJSON export.
/// Edge LineStrings are the routing graph; shared coordinates define junctions
/// because the pilot from_node/to_node attributes are not yet consistent.
class CampusGraphRoutingService implements RoutingService {
  CampusGraphRoutingService({this.maximumSnapMeters = 45.0});

  final double maximumSnapMeters;
  static const String _edgesAsset = 'docs/campus-mapping/edges.geojson';
  static const String _nodesAsset = 'docs/campus-mapping/nodes.geojson';
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

        final routePoints = <LatLon>[origin];
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
      final edgesJson = jsonDecode(await rootBundle.loadString(_edgesAsset))
          as Map<String, dynamic>;
      final nodesJson = jsonDecode(await rootBundle.loadString(_nodesAsset))
          as Map<String, dynamic>;
      final nodeFeatures = nodesJson['features'] as List<dynamic>? ?? const [];
      final validNodeCount = nodeFeatures.where((feature) {
        if (feature is! Map<String, dynamic>) return false;
        final geometry = feature['geometry'];
        return geometry is Map<String, dynamic> &&
            geometry['type'] == 'Point' &&
            geometry['coordinates'] is List &&
            (geometry['coordinates'] as List).length >= 2;
      }).length;

      final edgeFeatures = edgesJson['features'] as List<dynamic>? ?? const [];
      final adjacency = <String, List<_Arc>>{};
      final points = <String, LatLon>{};
      final segments = <_Segment>[];
      for (final feature in edgeFeatures) {
        if (feature is! Map<String, dynamic>) continue;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};
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
        final bidirectional = properties['bidirectional'] != false;
        for (var i = 0; i < line.length - 1; i++) {
          final from = line[i];
          final to = line[i + 1];
          final length = _distance(from, to);
          if (length < 0.05) continue;
          final fromKey = _key(from);
          final toKey = _key(to);
          points[fromKey] = from;
          points[toKey] = to;
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
          ));
        }
      }
      if (validNodeCount == 0) {
        throw const FormatException('The QGIS nodes GeoJSON contains no valid Point features.');
      }
      return _CampusGraph(adjacency: adjacency, points: points, segments: segments);
    } on Exception catch (error) {
      throw RoutingFailure(RoutingErrorType.apiError,
          'Could not load the QGIS campus map: ' + error.toString());
    }
  }

  List<_Snap> _nearestSegments(
    LatLon position,
    List<_Segment> segments, {
    int maximumCandidates = 8,
  }) {
    final snaps = <_Snap>[];
    for (final segment in segments) {
      final projection = _project(position, segment.from, segment.to);
      snaps.add(_Snap(
        segment: segment,
        point: projection.point,
        fraction: projection.fraction,
        distanceMeters: _distance(position, projection.point),
      ));
    }
    snaps.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
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
    required this.to, required this.lengthMeters,
  });
  final String fromKey;
  final String toKey;
  final LatLon from;
  final LatLon to;
  final double lengthMeters;
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
