import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// Offline campus routing based only on field-recorded GPS Logger traces.
/// It deliberately does not bridge gaps between recorded tracks unless
/// their endpoints are within the small, configurable connection radius.
class CampusRoutingService implements RoutingService {
  CampusRoutingService({
    this.assetPath = 'assets/data/campus_routes.json',
    this.endpointConnectionMeters = 8.0,
    this.maximumOriginSnapMeters = 15.0,
    this.maximumDestinationSnapMeters = 25.0,
  });

  final String assetPath;
  final double endpointConnectionMeters;
  final double maximumOriginSnapMeters;
  final double maximumDestinationSnapMeters;

  Future<_CampusGraph>? _graphFuture;

  Future<_CampusGraph> _loadGraph() {
    return _graphFuture ??= _readGraph();
  }

  Future<_CampusGraph> _readGraph() async {
    final raw = await rootBundle.loadString(assetPath);
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rawSegments = data['segments'] as List<dynamic>;
    final graph = _CampusGraph();

    for (final rawSegment in rawSegments) {
      final coordinates = rawSegment as List<dynamic>;
      final ids = <int>[];
      for (final rawPoint in coordinates) {
        final pair = rawPoint as List<dynamic>;
        ids.add(graph.addNode(LatLon(
          latitude: (pair[0] as num).toDouble(),
          longitude: (pair[1] as num).toDouble(),
        )));
      }
      if (ids.isNotEmpty) {
        graph.segmentEndpoints.add(ids.first);
        graph.segmentEndpoints.add(ids.last);
      }
      for (var i = 0; i + 1 < ids.length; i++) {
        graph.connect(ids[i], ids[i + 1]);
      }
    }

    // Connect only track endpoints that were recorded close together.
    // This avoids inventing walkways across missing GPS Logger sections.
    final endpoints = graph.segmentEndpoints;
    for (var i = 0; i < endpoints.length; i++) {
      for (var j = i + 1; j < endpoints.length; j++) {
        final a = endpoints[i];
        final b = endpoints[j];
        if (a != b &&
            _distance(graph.points[a], graph.points[b]) <=
                endpointConnectionMeters) {
          graph.connect(a, b);
        }
      }
    }
    return graph;
  }

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    final graph = (await _loadGraph()).copy();
    if (graph.points.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The campus GPS track contains no route points.',
      );
    }

    final start = _nearestSegment(graph, origin);
    final end = _nearestSegment(graph, destination);

    if (start.distance > maximumOriginSnapMeters) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'Your current GPS position is ${start.distance.toStringAsFixed(1)} m from the recorded campus paths. Move closer to a recorded path.',
      );
    }
    if (end.distance > maximumDestinationSnapMeters) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The selected destination is ${end.distance.toStringAsFixed(1)} m from the recorded campus paths. Its entrance needs a GPS Logger recording.',
      );
    }

    final distances = List<double>.filled(graph.points.length, double.infinity);
    final previous = List<int?>.filled(graph.points.length, null);
    final visited = List<bool>.filled(graph.points.length, false);
    distances[start.index] = 0;

    while (true) {
      var current = -1;
      var best = double.infinity;
      for (var i = 0; i < distances.length; i++) {
        if (!visited[i] && distances[i] < best) {
          current = i;
          best = distances[i];
        }
      }
      if (current == -1 || current == end.index) break;
      visited[current] = true;
      for (final edge in graph.edges[current]) {
        final candidate = distances[current] + edge.distance;
        if (candidate < distances[edge.to]) {
          distances[edge.to] = candidate;
          previous[edge.to] = current;
        }
      }
    }

    if (!distances[end.index].isFinite) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'No continuous recorded campus path connects your current location to this destination. More GPS Logger path data is required; no route will be invented.',
      );
    }

    final ids = <int>[];
    int? cursor = end.index;
    while (cursor != null) {
      ids.add(cursor);
      if (cursor == start.index) break;
      cursor = previous[cursor];
    }
    if (ids.last != start.index) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'Could not reconstruct a continuous campus route.',
      );
    }

    final path = <LatLon>[
      origin,
      ...ids.reversed.map((id) => graph.points[id]),
      destination,
    ];
    final distance = distances[end.index] + start.distance + end.distance;
    return RouteResult(
      polyline: path,
      distanceMeters: distance,
      durationSeconds: distance / 1.2,
    );
  }

  _SnapResult _nearestSegment(_CampusGraph graph, LatLon point) {
    var bestDistance = double.infinity;
    var bestStart = -1;
    var bestEnd = -1;
    LatLon? bestProjection;

    for (var from = 0; from < graph.edges.length; from++) {
      for (final edge in graph.edges[from]) {
        if (from >= edge.to) continue;
        final projection = _project(point, graph.points[from], graph.points[edge.to]);
        final distance = _distance(point, projection);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestStart = from;
          bestEnd = edge.to;
          bestProjection = projection;
        }
      }
    }

    if (bestStart < 0 || bestProjection == null) {
      return const _SnapResult(-1, double.infinity);
    }

    final projectedId = graph.addNode(bestProjection);
    graph.connect(projectedId, bestStart);
    graph.connect(projectedId, bestEnd);
    return _SnapResult(projectedId, bestDistance);
  }

  static LatLon _project(LatLon point, LatLon start, LatLon end) {
    final latitudeScale = 111320.0;
    final longitudeScale = 111320.0 * math.cos(_radians(point.latitude));
    final px = (point.longitude - start.longitude) * longitudeScale;
    final py = (point.latitude - start.latitude) * latitudeScale;
    final sx = (end.longitude - start.longitude) * longitudeScale;
    final sy = (end.latitude - start.latitude) * latitudeScale;
    final lengthSquared = sx * sx + sy * sy;
    if (lengthSquared <= 0.0001) return start;
    final t = ((px * sx + py * sy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    return LatLon(
      latitude: start.latitude + (end.latitude - start.latitude) * t,
      longitude: start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  static double _distance(LatLon a, LatLon b) {
    const radius = 6371000.0;
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return 2 * radius * math.asin(math.sqrt(h));
  }

  static double _radians(double value) => value * math.pi / 180.0;
}

class _CampusGraph {
  _CampusGraph();

  _CampusGraph.copy(_CampusGraph source) {
    points.addAll(source.points);
    for (final sourceEdges in source.edges) {
      edges.add(sourceEdges.map((edge) => _CampusEdge(edge.to, edge.distance)).toList());
    }
    segmentEndpoints.addAll(source.segmentEndpoints);
  }

  _CampusGraph copy() => _CampusGraph.copy(this);

  final List<LatLon> points = [];
  final List<List<_CampusEdge>> edges = [];
  final List<int> segmentEndpoints = [];

  int addNode(LatLon point) {
    final id = points.length;
    points.add(point);
    edges.add([]);
    return id;
  }

  void connect(int a, int b) {
    final distance = CampusRoutingService._distance(points[a], points[b]);
    if (distance <= 0.01) return;
    edges[a].add(_CampusEdge(b, distance));
    edges[b].add(_CampusEdge(a, distance));
  }
}

class _CampusEdge {
  const _CampusEdge(this.to, this.distance);
  final int to;
  final double distance;
}

class _SnapResult {
  const _SnapResult(this.index, this.distance);
  final int index;
  final double distance;
}
