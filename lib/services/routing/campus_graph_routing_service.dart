import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// Offline campus router built from the current QGIS GeoPackage export.
///
/// Topology is derived from shared LineString vertices, because the source
/// from_node/to_node attributes contain legacy aliases and endpoint drift.
/// Node IDs remain authoritative for destination identity and are validated
/// separately. No straight-line GPS-to-path or path-to-destination connector
/// is included in the returned pedestrian route.
class CampusGraphRoutingService implements RoutingService {
  CampusGraphRoutingService({
    this.maximumSnapMeters = 20.0,
    this.maximumDestinationSnapMeters = 12.0,
    this.ambiguousSnapMarginMeters = 1.25,
  })  : assert(maximumSnapMeters > 0),
        assert(maximumDestinationSnapMeters > 0),
        assert(ambiguousSnapMarginMeters >= 0);

  final double maximumSnapMeters;
  final double maximumDestinationSnapMeters;
  final double ambiguousSnapMarginMeters;

  static const String _edgesAsset =
      'docs/campus-mapping/edges_v3.geojson';
  static const String _nodesAsset =
      'docs/campus-mapping/nodes_v3.geojson';
  static const String _aliasesAsset =
      'docs/campus-mapping/node_reference_aliases.json';

  Future<_CampusGraph>? _graphFuture;

  /// Load and inspect the bundled network without requesting a route.
  Future<CampusGraphDiagnostics> diagnostics() async {
    final graph = await (_graphFuture ??= _loadGraph());
    return CampusGraphDiagnostics(
      nodeCount: graph.nodeCount,
      edgeCount: graph.edgeCount,
      segmentCount: graph.segments.length,
      connectedComponents: graph.connectedComponents,
      allEdgesFieldVerified: graph.allEdgesFieldVerified,
      warnings: List.unmodifiable(graph.warnings),
    );
  }

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    final graph = await (_graphFuture ??= _loadGraph());
    if (graph.segments.isEmpty || graph.adjacency.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The QGIS campus network contains no usable pedestrian edges.',
      );
    }

    // Select the geometrically closest path. Do not choose a farther edge
    // simply because it happens to produce a shorter graph route.
    final originSnap = _nearestSegment(
      origin,
      graph,
      maximumDistanceMeters: maximumSnapMeters,
      label: 'GPS position',
    );
    final destinationSnap = _nearestSegment(
      destination,
      graph,
      maximumDistanceMeters: maximumDestinationSnapMeters,
      label: 'destination entrance',
    );

    final adjacency = <String, List<_Arc>>{
      for (final entry in graph.adjacency.entries)
        entry.key: List<_Arc>.from(entry.value),
    };
    final points = Map<String, LatLon>.from(graph.points);
    const originKey = '__v3_origin_snap__';
    const destinationKey = '__v3_destination_snap__';

    points[originKey] = originSnap.point;
    points[destinationKey] = destinationSnap.point;
    adjacency[originKey] = <_Arc>[];
    adjacency[destinationKey] = <_Arc>[];

    _attachOrigin(adjacency, originKey, originSnap);
    _attachDestination(adjacency, destinationKey, destinationSnap);

    if (identical(originSnap.segment, destinationSnap.segment)) {
      final delta =
          destinationSnap.fraction - originSnap.fraction;
      if (delta >= 0) {
        _addArc(
          adjacency,
          originKey,
          destinationKey,
          delta * originSnap.segment.lengthMeters,
        );
      } else if (originSnap.segment.bidirectional) {
        _addArc(
          adjacency,
          originKey,
          destinationKey,
          -delta * originSnap.segment.lengthMeters,
        );
      }
    }

    final path = _shortestPath(
      adjacency,
      originKey,
      destinationKey,
    );
    if (path == null || path.length < 2) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'GRAPH_CONNECTIVITY: the nearest mapped path to the current '
        'position is not connected to the selected destination. '
        'The route was not joined across an unmapped gap.',
      );
    }

    final polyline = <LatLon>[];
    for (final key in path) {
      final point = points[key];
      if (point != null) {
        _appendDistinct(polyline, point);
      }
    }

    if (polyline.length < 2) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The calculated campus route has no usable geometry.',
      );
    }

    var distanceMeters = 0.0;
    for (var i = 1; i < polyline.length; i++) {
      distanceMeters += _distance(polyline[i - 1], polyline[i]);
    }

    return RouteResult(
      polyline: polyline,
      distanceMeters: distanceMeters,
      durationSeconds: distanceMeters,
    );
  }

  Future<_CampusGraph> _loadGraph() async {
    try {
      final edgesCollection = jsonDecode(
        await rootBundle.loadString(_edgesAsset),
      ) as Map<String, dynamic>;
      final nodesCollection = jsonDecode(
        await rootBundle.loadString(_nodesAsset),
      ) as Map<String, dynamic>;
      final aliasDocument = jsonDecode(
        await rootBundle.loadString(_aliasesAsset),
      ) as Map<String, dynamic>;

      final rawAliases =
          aliasDocument['aliases'] as Map<String, dynamic>? ?? const {};
      final aliases = <String, String>{
        for (final entry in rawAliases.entries)
          entry.key.trim(): entry.value.toString().trim(),
      };

      final nodeFeatures =
          nodesCollection['features'] as List<dynamic>? ?? const [];
      final nodeCoordinates = <String, LatLon>{};
      final originalIds = <String>{};

      for (final feature in nodeFeatures) {
        if (feature is! Map<String, dynamic>) continue;
        final properties =
            feature['properties'] as Map<String, dynamic>? ?? const {};
        final id = (properties['node_id'] ?? '').toString().trim();
        if (id.isEmpty) {
          throw const FormatException(
            'The QGIS nodes layer contains a feature without node_id.',
          );
        }
        if (!originalIds.add(id)) {
          throw FormatException('Duplicate QGIS node_id after trim: $id');
        }
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'Point') {
          throw FormatException('QGIS node $id is not a Point geometry.');
        }
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) {
          throw FormatException('QGIS node $id has invalid coordinates.');
        }
        final longitude = (coordinates[0] as num?)?.toDouble();
        final latitude = (coordinates[1] as num?)?.toDouble();
        if (longitude == null ||
            latitude == null ||
            !longitude.isFinite ||
            !latitude.isFinite ||
            latitude < -90 ||
            latitude > 90 ||
            longitude < -180 ||
            longitude > 180) {
          throw FormatException('QGIS node $id has out-of-range coordinates.');
        }
        nodeCoordinates[id] = LatLon(
          latitude: latitude,
          longitude: longitude,
        );
      }

      String canonicalNodeReference(String value) {
        final trimmed = value.trim();
        return aliases[trimmed] ?? trimmed;
      }

      final edgeFeatures =
          edgesCollection['features'] as List<dynamic>? ?? const [];
      final adjacency = <String, List<_Arc>>{};
      final points = <String, LatLon>{};
      final segments = <_Segment>[];
      final edgeIds = <String>{};
      final warnings = <String>[];
      var fieldVerified = edgeFeatures.isNotEmpty;

      for (final feature in edgeFeatures) {
        if (feature is! Map<String, dynamic>) continue;
        final properties =
            feature['properties'] as Map<String, dynamic>? ?? const {};
        final edgeId = (properties['edge_id'] ?? '').toString().trim();
        if (edgeId.isEmpty || !edgeIds.add(edgeId)) {
          throw FormatException(
            'The QGIS edges layer contains a blank or duplicate edge_id: '
            '${properties['edge_id']}',
          );
        }

        final fromNode = canonicalNodeReference(
          (properties['from_node'] ?? '').toString(),
        );
        final toNode = canonicalNodeReference(
          (properties['to_node'] ?? '').toString(),
        );
        if (!nodeCoordinates.containsKey(fromNode) ||
            !nodeCoordinates.containsKey(toNode)) {
          throw FormatException(
            'Edge $edgeId references an unknown node: '
            '$fromNode → $toNode.',
          );
        }

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'LineString') {
          throw FormatException('QGIS edge $edgeId is not a LineString.');
        }
        final rawCoordinates =
            geometry['coordinates'] as List<dynamic>? ?? const [];
        var line = <LatLon>[];
        for (final raw in rawCoordinates) {
          if (raw is! List || raw.length < 2) continue;
          final longitude = (raw[0] as num?)?.toDouble();
          final latitude = (raw[1] as num?)?.toDouble();
          if (longitude == null ||
              latitude == null ||
              !longitude.isFinite ||
              !latitude.isFinite ||
              latitude < -90 ||
              latitude > 90 ||
              longitude < -180 ||
              longitude > 180) {
            throw FormatException(
              'QGIS edge $edgeId contains invalid coordinates.',
            );
          }
          line.add(LatLon(
            latitude: latitude,
            longitude: longitude,
          ));
        }
        if (line.length < 2) {
          throw FormatException(
            'QGIS edge $edgeId contains fewer than two vertices.',
          );
        }

        final bidirectional = _asBool(properties['bidirectional']);
        final verified = _asBool(properties['verified']);
        fieldVerified = fieldVerified && verified;

        // Some source LineStrings are digitized opposite to from_node/to_node.
        // Reverse only when the endpoint-to-node distances prove that ordering.
        final fromPoint = nodeCoordinates[fromNode]!;
        final toPoint = nodeCoordinates[toNode]!;
        final directError = _distance(line.first, fromPoint) +
            _distance(line.last, toPoint);
        final reverseError = _distance(line.last, fromPoint) +
            _distance(line.first, toPoint);
        if (reverseError < directError) {
          line = line.reversed.toList();
        }

        final fromOffset = _distance(line.first, fromPoint);
        final toOffset = _distance(line.last, toPoint);
        if (fromOffset > 1.0 || toOffset > 1.0) {
          warnings.add(
            '$edgeId endpoint offset: from=${fromOffset.toStringAsFixed(2)}m, '
            'to=${toOffset.toStringAsFixed(2)}m.',
          );
        }

        for (var i = 0; i < line.length - 1; i++) {
          final from = line[i];
          final to = line[i + 1];
          final length = _distance(from, to);
          if (!length.isFinite || length < 0.05) continue;

          final fromKey = _key(from);
          final toKey = _key(to);
          points[fromKey] = from;
          points[toKey] = to;
          adjacency.putIfAbsent(fromKey, () => <_Arc>[]);
          adjacency.putIfAbsent(toKey, () => <_Arc>[]);
          _addArc(adjacency, fromKey, toKey, length);
          if (bidirectional) {
            _addArc(adjacency, toKey, fromKey, length);
          }

          segments.add(_Segment(
            fromKey: fromKey,
            toKey: toKey,
            from: from,
            to: to,
            lengthMeters: length,
            edgeId: edgeId,
            bidirectional: bidirectional,
          ));
        }
      }

      if (nodeCoordinates.isEmpty || segments.isEmpty) {
        throw const FormatException(
          'The QGIS map must contain at least one valid node and edge.',
        );
      }

      final weakAdjacency = _buildWeakAdjacency(adjacency);
      final components = _countComponents(weakAdjacency);
      if (components > 1) {
        warnings.add(
          'The QGIS edge geometry contains $components disconnected '
          'components. Routing between components is rejected.',
        );
      }
      if (!fieldVerified) {
        warnings.add(
          'One or more QGIS edges have verified=false. '
          'The map has not been field-verified.',
        );
      }

      return _CampusGraph(
        adjacency: adjacency,
        weakAdjacency: weakAdjacency,
        points: points,
        segments: segments,
        nodeCount: nodeCoordinates.length,
        edgeCount: edgeIds.length,
        connectedComponents: components,
        allEdgesFieldVerified: fieldVerified,
        warnings: warnings,
      );
    } on RoutingFailure {
      rethrow;
    } on Exception catch (error) {
      throw RoutingFailure(
        RoutingErrorType.apiError,
        'Could not load the V3 QGIS campus map: $error',
      );
    }
  }

  _Snap _nearestSegment(
    LatLon position,
    _CampusGraph graph, {
    required double maximumDistanceMeters,
    required String label,
  }) {
    final bestByEdge = <String, _Snap>{};
    for (final segment in graph.segments) {
      final projection = _project(position, segment.from, segment.to);
      final snap = _Snap(
        segment: segment,
        point: projection.point,
        fraction: projection.fraction,
        distanceMeters: _distance(position, projection.point),
      );
      final previous = bestByEdge[segment.edgeId];
      if (previous == null ||
          snap.distanceMeters < previous.distanceMeters) {
        bestByEdge[segment.edgeId] = snap;
      }
    }

    final candidates = bestByEdge.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    if (candidates.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The QGIS campus map has no usable path segments.',
      );
    }

    final best = candidates.first;
    if (best.distanceMeters > maximumDistanceMeters) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'MAP_MATCH_DISTANCE: $label is '
        '${best.distanceMeters.toStringAsFixed(1)} m from the nearest '
        'mapped path (limit ${maximumDistanceMeters.toStringAsFixed(0)} m). '
        'No straight-line route connector was added.',
      );
    }

    if (candidates.length > 1) {
      final second = candidates[1];
      final margin = second.distanceMeters - best.distanceMeters;
      if (margin <= ambiguousSnapMarginMeters &&
          _componentFor(graph, best.segment) !=
              _componentFor(graph, second.segment)) {
        throw RoutingFailure(
          RoutingErrorType.noRouteFound,
          'AMBIGUOUS_MAP_MATCH: $label is similarly close to paths in '
          'different disconnected network components.',
        );
      }
    }

    return best;
  }

  String _componentFor(_CampusGraph graph, _Segment segment) {
    final visited = <String>{};
    final queue = <String>[segment.fromKey];
    visited.add(segment.fromKey);
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final neighbour
          in graph.weakAdjacency[current] ?? const <String>{}) {
        if (visited.add(neighbour)) queue.add(neighbour);
      }
    }
    final keys = visited.toList()..sort();
    return keys.join('|');
  }

  void _attachOrigin(
    Map<String, List<_Arc>> graph,
    String key,
    _Snap snap,
  ) {
    final segment = snap.segment;
    final toEnd = (1 - snap.fraction) * segment.lengthMeters;

    // The source LineString's forward direction is always available.
    _addArc(graph, key, segment.toKey, toEnd);

    // Travel toward the segment start only when the source edge is two-way.
    if (segment.bidirectional) {
      final toStart = snap.fraction * segment.lengthMeters;
      _addArc(graph, key, segment.fromKey, toStart);
    }
  }

  void _attachDestination(
    Map<String, List<_Arc>> graph,
    String key,
    _Snap snap,
  ) {
    final segment = snap.segment;
    final fromStart = snap.fraction * segment.lengthMeters;

    // Arrival along the source LineString's forward direction.
    _addArc(graph, segment.fromKey, key, fromStart);

    if (segment.bidirectional) {
      final fromEnd = (1 - snap.fraction) * segment.lengthMeters;
      _addArc(graph, segment.toKey, key, fromEnd);
    }
  }

  List<String>? _shortestPath(
    Map<String, List<_Arc>> graph,
    String start,
    String goal,
  ) {
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

  static Map<String, Set<String>> _buildWeakAdjacency(
    Map<String, List<_Arc>> adjacency,
  ) {
    final weak = <String, Set<String>>{
      for (final key in adjacency.keys) key: <String>{},
    };
    for (final entry in adjacency.entries) {
      for (final arc in entry.value) {
        weak.putIfAbsent(entry.key, () => <String>{}).add(arc.to);
        weak.putIfAbsent(arc.to, () => <String>{}).add(entry.key);
      }
    }
    return weak;
  }

  static int _countComponents(
    Map<String, Set<String>> adjacency,
  ) {
    final visited = <String>{};
    var count = 0;
    for (final start in adjacency.keys) {
      if (!visited.add(start)) continue;
      count++;
      final queue = <String>[start];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        for (final neighbour in adjacency[current] ?? const <String>{}) {
          if (visited.add(neighbour)) queue.add(neighbour);
        }
      }
    }
    return count;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static void _addArc(
    Map<String, List<_Arc>> graph,
    String from,
    String to,
    double weight,
  ) {
    graph.putIfAbsent(from, () => <_Arc>[]).add(_Arc(to, weight));
  }

  static void _appendDistinct(List<LatLon> points, LatLon point) {
    if (points.isEmpty || _distance(points.last, point) > 0.2) {
      points.add(point);
    }
  }

  static String _key(LatLon point) =>
      '${point.latitude.toStringAsFixed(6)},'
      '${point.longitude.toStringAsFixed(6)}';

  static _Projection _project(
    LatLon point,
    LatLon start,
    LatLon end,
  ) {
    const metersPerDegree = 111320.0;
    final longitudeScale =
        metersPerDegree * math.cos(point.latitude * math.pi / 180);
    final px = (point.longitude - start.longitude) * longitudeScale;
    final py = (point.latitude - start.latitude) * metersPerDegree;
    final sx = (end.longitude - start.longitude) * longitudeScale;
    final sy = (end.latitude - start.latitude) * metersPerDegree;
    final lengthSquared = sx * sx + sy * sy;
    final fraction = lengthSquared == 0
        ? 0.0
        : ((px * sx + py * sy) / lengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    return _Projection(
      point: LatLon(
        latitude: start.latitude +
            (end.latitude - start.latitude) * fraction,
        longitude: start.longitude +
            (end.longitude - start.longitude) * fraction,
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
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

class CampusGraphDiagnostics {
  const CampusGraphDiagnostics({
    required this.nodeCount,
    required this.edgeCount,
    required this.segmentCount,
    required this.connectedComponents,
    required this.allEdgesFieldVerified,
    required this.warnings,
  });

  final int nodeCount;
  final int edgeCount;
  final int segmentCount;
  final int connectedComponents;
  final bool allEdgesFieldVerified;
  final List<String> warnings;
}

class _CampusGraph {
  const _CampusGraph({
    required this.adjacency,
    required this.weakAdjacency,
    required this.points,
    required this.segments,
    required this.nodeCount,
    required this.edgeCount,
    required this.connectedComponents,
    required this.allEdgesFieldVerified,
    required this.warnings,
  });

  final Map<String, List<_Arc>> adjacency;
  final Map<String, Set<String>> weakAdjacency;
  final Map<String, LatLon> points;
  final List<_Segment> segments;
  final int nodeCount;
  final int edgeCount;
  final int connectedComponents;
  final bool allEdgesFieldVerified;
  final List<String> warnings;
}

class _Arc {
  const _Arc(this.to, this.weight);
  final String to;
  final double weight;
}

class _Segment {
  const _Segment({
    required this.fromKey,
    required this.toKey,
    required this.from,
    required this.to,
    required this.lengthMeters,
    required this.edgeId,
    required this.bidirectional,
  });

  final String fromKey;
  final String toKey;
  final LatLon from;
  final LatLon to;
  final double lengthMeters;
  final String edgeId;
  final bool bidirectional;
}

class _Snap {
  const _Snap({
    required this.segment,
    required this.point,
    required this.fraction,
    required this.distanceMeters,
  });

  final _Segment segment;
  final LatLon point;
  final double fraction;
  final double distanceMeters;
}

class _Projection {
  const _Projection({
    required this.point,
    required this.fraction,
  });

  final LatLon point;
  final double fraction;
}
