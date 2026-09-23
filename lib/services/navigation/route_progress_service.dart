import 'dart:math' as math;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';

class RouteProgressService {
  RouteProgressService({
    this.defaultLookAheadMeters = 10.0,
  });

  final double defaultLookAheadMeters;

  LatLon getNextTargetPoint({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
  }) {
    final target = getNextTarget(
      currentPosition: currentPosition,
      route: route,
      lookAheadMeters:
          lookAheadMeters ?? defaultLookAheadMeters,
    );

    return target.point;
  }

  RouteTarget getNextTarget({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
  }) {
    final lookAhead =
        lookAheadMeters ?? defaultLookAheadMeters;

    if (route.polyline.isEmpty) {
      throw const RouteProgressFailure(
        'Route polyline is empty.',
      );
    }

    if (lookAhead < 0) {
      throw const RouteProgressFailure(
        'Look-ahead distance cannot be negative.',
      );
    }

    if (route.polyline.length == 1) {
      return RouteTarget(
        point: route.polyline.first,
        index: 0,
        distanceAheadMeters: 0,
        distanceFromRouteMeters: distanceBetween(
          currentPosition,
          route.polyline.first,
        ),
      );
    }

    final nearest = _findNearestPointOnRoute(
      currentPosition: currentPosition,
      polyline: route.polyline,
    );

    var remainingLookAhead = lookAhead;

    var segmentIndex = nearest.segmentIndex;
    var segmentStart = nearest.projectedPoint;

    while (segmentIndex <
        route.polyline.length - 1) {
      final segmentEnd =
          route.polyline[segmentIndex + 1];

      final segmentDistance =
          distanceBetween(
        segmentStart,
        segmentEnd,
      );

      if (remainingLookAhead <= segmentDistance) {
        final target =
            _interpolatePoint(
          segmentStart,
          segmentEnd,
          segmentDistance == 0
              ? 0
              : remainingLookAhead /
                  segmentDistance,
        );

        return RouteTarget(
          point: target,
          index: segmentIndex + 1,
          distanceAheadMeters: lookAhead -
              remainingLookAhead +
              remainingLookAhead,
          distanceFromRouteMeters:
              nearest.distanceFromRouteMeters,
        );
      }

      remainingLookAhead -= segmentDistance;

      segmentIndex++;
      segmentStart = route.polyline[segmentIndex];
    }

    final lastIndex =
        route.polyline.length - 1;

    return RouteTarget(
      point: route.polyline[lastIndex],
      index: lastIndex,
      distanceAheadMeters:
          lookAhead - remainingLookAhead,
      distanceFromRouteMeters:
          nearest.distanceFromRouteMeters,
    );
  }

  int findNearestPointIndex({
    required LatLon currentPosition,
    required List<LatLon> polyline,
  }) {
    if (polyline.isEmpty) {
      throw const RouteProgressFailure(
        'Route polyline is empty.',
      );
    }

    final nearest =
        _findNearestPointOnRoute(
      currentPosition: currentPosition,
      polyline: polyline,
    );

    return nearest.segmentIndex;
  }

  double distanceBetween(
    LatLon first,
    LatLon second,
  ) {
    const earthRadiusMeters = 6371000.0;

    final latitude1 =
        _degreesToRadians(first.latitude);

    final latitude2 =
        _degreesToRadians(second.latitude);

    final deltaLatitude =
        _degreesToRadians(
      second.latitude - first.latitude,
    );

    final deltaLongitude =
        _degreesToRadians(
      second.longitude - first.longitude,
    );

    final a =
        math.sin(deltaLatitude / 2) *
                math.sin(deltaLatitude / 2) +
            math.cos(latitude1) *
                math.cos(latitude2) *
                math.sin(deltaLongitude / 2) *
                math.sin(deltaLongitude / 2);

    final c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusMeters * c;
  }

  _NearestRoutePoint _findNearestPointOnRoute({
    required LatLon currentPosition,
    required List<LatLon> polyline,
  }) {
    var nearestDistance =
        double.infinity;

    var nearestSegmentIndex = 0;

    LatLon? nearestPoint;

    for (var i = 0;
        i < polyline.length - 1;
        i++) {
      final start = polyline[i];
      final end = polyline[i + 1];

      final projected =
          _projectPointOntoSegment(
        currentPosition,
        start,
        end,
      );

      final distance =
          distanceBetween(
        currentPosition,
        projected,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestSegmentIndex = i;
        nearestPoint = projected;
      }
    }

    return _NearestRoutePoint(
      segmentIndex: nearestSegmentIndex,
      projectedPoint: nearestPoint!,
      distanceFromRouteMeters:
          nearestDistance,
    );
  }

  LatLon _projectPointOntoSegment(
    LatLon point,
    LatLon start,
    LatLon end,
  ) {
    final latitudeScale =
        111320.0;

    final longitudeScale =
        111320.0 *
            math.cos(
              _degreesToRadians(
                point.latitude,
              ),
            );

    final px =
        (point.longitude -
                start.longitude) *
            longitudeScale;

    final py =
        (point.latitude -
                start.latitude) *
            latitudeScale;

    final sx =
        (end.longitude -
                start.longitude) *
            longitudeScale;

    final sy =
        (end.latitude -
                start.latitude) *
            latitudeScale;

    final segmentLengthSquared =
        sx * sx + sy * sy;

    if (segmentLengthSquared == 0) {
      return start;
    }

    var t =
        (px * sx + py * sy) /
            segmentLengthSquared;

    t = t.clamp(0.0, 1.0);

    return _interpolatePoint(
      start,
      end,
      t,
    );
  }

  LatLon _interpolatePoint(
    LatLon start,
    LatLon end,
    double factor,
  ) {
    return LatLon(
      latitude:
          start.latitude +
              (end.latitude -
                      start.latitude) *
                  factor,
      longitude:
          start.longitude +
              (end.longitude -
                      start.longitude) *
                  factor,
    );
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees * math.pi / 180.0;
  }
}

class RouteTarget {
  const RouteTarget({
    required this.point,
    required this.index,
    required this.distanceAheadMeters,
    required this.distanceFromRouteMeters,
  });

  final LatLon point;

  /// Polyline segment/end index around the target.
  final int index;

  /// Requested look-ahead distance.
  final double distanceAheadMeters;

  /// How far the current GPS position is from
  /// the calculated route.
  final double distanceFromRouteMeters;
}

class _NearestRoutePoint {
  const _NearestRoutePoint({
    required this.segmentIndex,
    required this.projectedPoint,
    required this.distanceFromRouteMeters,
  });

  final int segmentIndex;
  final LatLon projectedPoint;
  final double distanceFromRouteMeters;
}

class RouteProgressFailure implements Exception {
  const RouteProgressFailure(this.message);

  final String message;

  @override
  String toString() => message;
}