import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// Offline pedestrian graph loaded from the canonical QGIS edges export.
/// Shared LineString vertices define junctions. Source node IDs are validated
/// separately; endpoint offsets are never bridged with invented geometry.
class CampusGraphRoutingService implements RoutingService {
  CampusGraphRoutingService({
    this.maximumSnapMeters = 30.0,
    this.maximumDestinationSnapMeters = 12.0,
    this.ambiguousSnapMarginMeters = 1.25,
  })  : assert(maximumSnapMeters > 0),
        assert(maximumDestinationSnapMeters > 0),
        assert(ambiguousSnapMarginMeters >= 0);

  final double maximumSnapMeters;
  final double maximumDestinationSnapMeters;
  final double ambiguousSnapMarginMeters;

  static const _edgesAsset = 'docs/campus-mapping/edges_v3.geojson';
  static const _nodesAsset = 'docs/campus-mapping/nodes_v3.geojson';
  static const _aliasesAsset =
      'docs/campus-mapping/node_reference_aliases.json';

  Future<_CampusGraph>? _graphFuture;

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
    if (graph.segments.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The QGIS campus network contains no usable pedestrian edges.',
      );
    }

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
    const start = '__v3_origin_snap__';
    const goal = '__v3_destination_snap__';
    adjacency[start] = <_Arc>[];
    adjacency[goal] = <_Arc>[];
    points[start] = originSnap.point;
    points[goal] = destinationSnap.point;

    _attachOrigin(adjacency, start, originSnap);
    _attachDestination(adjacency, goal, destinationSnap);

    if (identical(originSnap.segment, destinationSnap.segment)) {
      final delta = destinationSnap.fraction - originSnap.fraction;
      if (delta >= 0) {
        _addArc(adjacency, start, goal,
            delta * originSnap.segment.lengthMeters);
      } else if (originSnap.segment.bidirectional) {
        _addArc(adjacency, start, goal,
            -delta * originSnap.segment.lengthMeters);
      }
    }

    final path = _shortestPath(adjacency, start, goal);
    if (path == null || path.length < 2) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'GRAPH_CONNECTIVITY: the nearest mapped path to the current '
        'position is not connected to the selected destination. '
        'No connection was created across an unmapped gap.',
      );
    }

    final polyline = <LatLon>[];
    for (final key in path) {
      final point = points[key];
      if (point != null) _appendDistinct(polyline, point);
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
      final nodesDocument = jsonDecode(
        await rootBundle.loadString(_nodesAsset),
      ) as Map<String, dynamic>;
      final edgesDocument = jsonDecode(
        await rootBundle.loadString(_edgesAsset),
      ) as Map<String, dynamic>;
      final aliasesDocument = jsonDecode(
        await rootBundle.loadString(_aliasesAsset),
      ) as Map<String, dynamic>;

      final rawAliases =
          aliasesDocument['aliases'] as Map<String, dynamic>? ?? const {};
      final aliases = <String, String>{
        for (final entry in rawAliases.entries)
          entry.key.trim(): entry.value.toString().trim(),
      };

      final nodes = <String, LatLon>{};
      final rawNodes = nodesDocument['features'] as List<dynamic>? ?? const [];
      for (final feature in rawNodes) {
        if (feature is! Map<String, dynamic>) continue;
        final properties =
            feature['properties'] as Map<String, dynamic>? ?? const {};
        final id = (properties['node_id'] ?? '').toString().trim();
        if (id.isEmpty || nodes.containsKey(id)) {
          throw FormatException('Empty or duplicate QGIS node_id: "$id".');
        }
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'Point') {
          throw FormatException('QGIS node $id is not a Point geometry.');
        }
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null) {
          throw FormatException('QGIS node $id has invalid coordinates.');
        }
        nodes[id] = _parsePoint(coordinates, 'node $id');
      }

      String canonicalReference(String raw) {
        final value = raw.trim();
        return aliases[value] ?? value;
      }

      final adjacency = <String, List<_Arc>>{};
      final points = <String, LatLon>{};
      final segments = <_Segment>[];
      final edgeIds = <String>{};
      final warnings = <String>[];
      final rawEdges = edgesDocument['features'] as List<dynamic>? ?? const [];
      var allVerified = rawEdges.isNotEmpty;

      for (final feature in rawEdges) {
        if (feature is! Map<String, dynamic>) continue;
        final properties =
            feature['properties'] as Map<String, dynamic>? ?? const {};
        final edgeId = (properties['edge_id'] ?? '').toString().trim();
        if (edgeId.isEmpty || !edgeIds.add(edgeId)) {
          throw FormatException('Blank or duplicate QGIS edge_id: "$edgeId".');
        }

        final fromId =
            canonicalReference((properties['from_node'] ?? '').toString());
        final toId =
            canonicalReference((properties['to_node'] ?? '').toString());
        if (!nodes.containsKey(fromId) || !nodes.containsKey(toId)) {
          throw FormatException(
            'Edge $edgeId references unknown QGIS node: $fromId → $toId.',
          );
        }

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null || geometry['type'] != 'LineString') {
          throw FormatException('QGIS edge $edgeId is not a LineString.');
        }
        final rawCoordinates =
            geometry['coordinates'] as List<dynamic>? ?? const [];
        var line = rawCoordinates
            .whereType<List<dynamic>>()
            .map((coords) => _parsePoint(coords, 'edge $edgeId'))
            .toList();
        if (line.length < 2) {
          throw FormatException('QGIS edge $edgeId has fewer than two vertices.');
        }

        final fromPoint = nodes[fromId]!;
        final toPoint = nodes[toId]!;
        final directError =
            _distance(line.first, fromPoint) + _distance(line.last, toPoint);
        final reverseError =
            _distance(line.last, fromPoint) + _distance(line.first, toPoint);
        if (reverseError + 0.05 < directError) {
          line = line.reversed.toList();
        }

        final startOffset = _distance(line.first, fromPoint);
        final endOffset = _distance(line.last, toPoint);
        const maximumNodeAttachmentMeters = 5.0;
        if (startOffset > maximumNodeAttachmentMeters ||
            endOffset > maximumNodeAttachmentMeters) {
          throw FormatException(
            '$edgeId cannot attach to its declared QGIS nodes: '
            'from offset=${startOffset.toStringAsFixed(2)}m, '
            'to offset=${endOffset.toStringAsFixed(2)}m '
            '(maximum ${maximumNodeAttachmentMeters.toStringAsFixed(1)}m).',
          );
        }

        // Node IDs, not coordinate coincidence, define graph connectivity.
        // Where a surveyed line endpoint is slightly offset from its declared
        // node, retain an explicit short connector in the route geometry.
        if (startOffset > 0.20) {
          line.insert(0, fromPoint);
          warnings.add(
            '$edgeId uses a ${startOffset.toStringAsFixed(2)}m '
            'connector to node $fromId.',
          );
        } else {
          line[0] = fromPoint;
        }
        if (endOffset > 0.20) {
          line.add(toPoint);
          warnings.add(
            '$edgeId uses a ${endOffset.toStringAsFixed(2)}m '
            'connector to node $toId.',
          );
        } else {
          line[line.length - 1] = toPoint;
        }

        final bidirectional = _asBool(properties['bidirectional']);
        final verified = _asBool(properties['verified']);
        allVerified = allVerified && verified;

        for (var i = 0; i < line.length - 1; i++) {
          final first = line[i];
          final second = line[i + 1];
          final length = _distance(first, second);
          if (!length.isFinite || length < 0.05) continue;
          final fromKey =
              i == 0 ? _nodeKey(fromId) : _edgeVertexKey(edgeId, i);
          final toKey = i == line.length - 2
              ? _nodeKey(toId)
              : _edgeVertexKey(edgeId, i + 1);
          points[fromKey] = first;
          points[toKey] = second;
          adjacency.putIfAbsent(fromKey, () => <_Arc>[]);
          adjacency.putIfAbsent(toKey, () => <_Arc>[]);
          _addArc(adjacency, fromKey, toKey, length);
          if (bidirectional) _addArc(adjacency, toKey, fromKey, length);
          segments.add(_Segment(
            fromKey: fromKey,
            toKey: toKey,
            from: first,
            to: second,
            lengthMeters: length,
            edgeId: edgeId,
            bidirectional: bidirectional,
          ));
        }
      }

      if (segments.isEmpty) {
        throw const FormatException('The QGIS map has no usable edge segments.');
      }

      // The current campus pilot must load the complete ED01..ED020 export
      // and all 28 surveyed node features, rather than silently routing on a
      // partial asset bundle.
      final expectedEdgeIds = <String>{
        'ED01', 'ED02', 'ED03', 'ED04', 'ED05',
        'ED06', 'ED07', 'ED08', 'ED09', 'ED010',
        'ED011', 'ED012', 'ED013', 'ED014', 'ED015',
        'ED016', 'ED017', 'ED018', 'ED019', 'ED020',
      };
      final missingEdgeIds = expectedEdgeIds.difference(edgeIds);
      if (missingEdgeIds.isNotEmpty ||
          edgeIds.length != expectedEdgeIds.length) {
        throw FormatException(
          'Incomplete campus edge export: expected 20 edges ED01..ED020; '
          'loaded ${edgeIds.length}, missing ${missingEdgeIds.toList()}.',
        );
      }
      if (nodes.length != 28) {
        throw FormatException(
          'Incomplete campus node export: expected 28 nodes; loaded ${nodes.length}.',
        );
      }

      final referencedNodeIds = <String>{
        for (final feature in rawEdges)
          if (feature is Map<String, dynamic>)
            canonicalReference(
              ((feature['properties'] as Map<String, dynamic>? ?? const {})['from_node']
                  ?? '').toString(),
            ),
        for (final feature in rawEdges)
          if (feature is Map<String, dynamic>)
            canonicalReference(
              ((feature['properties'] as Map<String, dynamic>? ?? const {})['to_node']
                  ?? '').toString(),
            ),
      };
      final unusedNodeIds = nodes.keys
          .where((nodeId) => !referencedNodeIds.contains(nodeId))
          .toList()
        ..sort();
      if (unusedNodeIds.isNotEmpty) {
        warnings.add(
          'QGIS nodes without an attached edge: ${unusedNodeIds.join(', ')}.',
        );
      }

      final weak = _buildWeakAdjacency(adjacency);
      final componentCount = _countComponents(weak);
      if (componentCount > 1) {
        warnings.add(
          'The map has $componentCount disconnected geometry components. '
          'Routes between components are rejected.',
        );
      }
      if (!allVerified) {
        warnings.add(
          'One or more QGIS edges have verified=false; the map is not '
          'field-verified.',
        );
      }

      return _CampusGraph(
        adjacency: adjacency,
        weakAdjacency: weak,
        points: points,
        segments: segments,
        nodeCount: nodes.length,
        edgeCount: edgeIds.length,
        connectedComponents: componentCount,
        allEdgesFieldVerified: allVerified,
        warnings: warnings,
      );
    } on RoutingFailure {
      rethrow;
    } catch (error) {
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
      final candidate = _Snap(
        segment: segment,
        point: projection.point,
        fraction: projection.fraction,
        distanceMeters: _distance(position, projection.point),
      );
      final previous = bestByEdge[segment.edgeId];
      if (previous == null ||
          candidate.distanceMeters < previous.distanceMeters) {
        bestByEdge[segment.edgeId] = candidate;
      }
    }

    final candidates = bestByEdge.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    if (candidates.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'The QGIS map contains no usable pedestrian path.',
      );
    }
    final best = candidates.first;
    if (best.distanceMeters > maximumDistanceMeters) {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'MAP_MATCH_DISTANCE: $label is '
        '${best.distanceMeters.toStringAsFixed(1)} m from the nearest '
        'mapped path (limit ${maximumDistanceMeters.toStringAsFixed(0)} m).',
      );
    }
    if (candidates.length > 1) {
      final second = candidates[1];
      if (second.distanceMeters - best.distanceMeters <=
              ambiguousSnapMarginMeters &&
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
    final visited = <String>{segment.fromKey};
    final queue = <String>[segment.fromKey];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final next in graph.weakAdjacency[current] ?? const <String>{}) {
        if (visited.add(next)) queue.add(next);
      }
    }
    final sorted = visited.toList()..sort();
    return sorted.join('|');
  }

  void _attachOrigin(
    Map<String, List<_Arc>> graph,
    String key,
    _Snap snap,
  ) {
    final segment = snap.segment;
    _addArc(
      graph,
      key,
      segment.toKey,
      (1 - snap.fraction) * segment.lengthMeters,
    );
    if (segment.bidirectional) {
      _addArc(
        graph,
        key,
        segment.fromKey,
        snap.fraction * segment.lengthMeters,
      );
    }
  }

  void _attachDestination(
    Map<String, List<_Arc>> graph,
    String key,
    _Snap snap,
  ) {
    final segment = snap.segment;
    _addArc(
      graph,
      segment.fromKey,
      key,
      snap.fraction * segment.lengthMeters,
    );
    if (segment.bidirectional) {
      _addArc(
        graph,
        segment.toKey,
        key,
        (1 - snap.fraction) * segment.lengthMeters,
      );
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
      var best = double.infinity;
      for (final candidate in unvisited) {
        final value = distances[candidate] ?? double.infinity;
        if (value < best) {
          best = value;
          current = candidate;
        }
      }
      if (current == null || best == double.infinity) break;
      if (current == goal) break;
      unvisited.remove(current);
      for (final arc in graph[current] ?? const <_Arc>[]) {
        if (!unvisited.contains(arc.to)) continue;
        final next = best + arc.weight;
        if (next < (distances[arc.to] ?? double.infinity)) {
          distances[arc.to] = next;
          previous[arc.to] = current;
        }
      }
    }
    if (!distances.containsKey(goal)) return null;
    final result = <String>[goal];
    var cursor = goal;
    while (cursor != start) {
      final parent = previous[cursor];
      if (parent == null) return null;
      result.add(parent);
      cursor = parent;
    }
    return result.reversed.toList();
  }

  static Map<String, Set<String>> _buildWeakAdjacency(
    Map<String, List<_Arc>> adjacency,
  ) {
    final result = <String, Set<String>>{
      for (final key in adjacency.keys) key: <String>{},
    };
    for (final entry in adjacency.entries) {
      for (final arc in entry.value) {
        result.putIfAbsent(entry.key, () => <String>{}).add(arc.to);
        result.putIfAbsent(arc.to, () => <String>{}).add(entry.key);
      }
    }
    return result;
  }

  static int _countComponents(Map<String, Set<String>> adjacency) {
    final visited = <String>{};
    var count = 0;
    for (final start in adjacency.keys) {
      if (!visited.add(start)) continue;
      count++;
      final queue = <String>[start];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        for (final next in adjacency[current] ?? const <String>{}) {
          if (visited.add(next)) queue.add(next);
        }
      }
    }
    return count;
  }

  static LatLon _parsePoint(List<dynamic> coordinates, String label) {
    if (coordinates.length < 2) {
      throw FormatException('$label has incomplete coordinates.');
    }
    final longitude = (coordinates[0] as num?)?.toDouble();
    final latitude = (coordinates[1] as num?)?.toDouble();
    if (longitude == null ||
        latitude == null ||
        !longitude.isFinite ||
        !latitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        latitude < -90 ||
        latitude > 90) {
      throw FormatException('$label has out-of-range coordinates.');
    }
    return LatLon(latitude: latitude, longitude: longitude);
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

  static String _nodeKey(String nodeId) => 'node:$nodeId';

  static String _edgeVertexKey(String edgeId, int vertexIndex) =>
      'edge:$edgeId:vertex:$vertexIndex';

  static _Projection _project(LatLon point, LatLon start, LatLon end) {
    const meters = 111320.0;
    final scale = meters * math.cos(point.latitude * math.pi / 180);
    final px = (point.longitude - start.longitude) * scale;
    final py = (point.latitude - start.latitude) * meters;
    final sx = (end.longitude - start.longitude) * scale;
    final sy = (end.latitude - start.latitude) * meters;
    final lengthSquared = sx * sx + sy * sy;
    final fraction = lengthSquared == 0
        ? 0.0
        : ((px * sx + py * sy) / lengthSquared).clamp(0.0, 1.0).toDouble();
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

  static void _appendDistinct(List<LatLon> points, LatLon point) {
    if (points.isEmpty || _distance(points.last, point) > 0.2) {
      points.add(point);
    }
  }

  static double _distance(LatLon a, LatLon b) {
    const radius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
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
  const _Projection({required this.point, required this.fraction});
  final LatLon point;
  final double fraction;
}
