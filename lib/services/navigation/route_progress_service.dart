
import 'dart:math' as math;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';

class RouteProgressService {
  RouteProgressService({
    this.defaultLookAheadMeters = 8.0,
    this.minimumLookAheadMeters = 4.0,
    this.maximumLookAheadMeters = 10.0,
    this.turnDetectionAngleDegrees = 35.0,
  });

  /// Normal look-ahead on reasonably straight sections.
  final double defaultLookAheadMeters;

  /// Minimum look-ahead used when a meaningful turn is close.
  final double minimumLookAheadMeters;

  /// Maximum look-ahead on long straight sections.
  final double maximumLookAheadMeters;

  /// A route heading change larger than this is treated
  /// as a meaningful turn.
  final double turnDetectionAngleDegrees;

  // ================================================================
  // SIMPLE TARGET API
  // ================================================================

  LatLon getNextTargetPoint({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
  }) {
    final target = getNextTarget(
      currentPosition: currentPosition,
      route: route,
      lookAheadMeters: lookAheadMeters,
    );

    return target.point;
  }

  // ================================================================
  // MAIN TARGET CALCULATION
  // ================================================================

  RouteTarget getNextTarget({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
  }) {
    if (route.polyline.isEmpty) {
      throw const RouteProgressFailure(
        'Route polyline is empty.',
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
        routeBearing: null,
        isNearTurn: false,
      );
    }

    final nearest = _findNearestPointOnRoute(
      currentPosition: currentPosition,
      polyline: route.polyline,
    );

    final adaptiveLookAhead =
        lookAheadMeters ??
        _calculateAdaptiveLookAhead(
          route: route,
          nearestSegmentIndex:
              nearest.segmentIndex,
          projectedPoint:
              nearest.projectedPoint,
        );

    var remainingLookAhead =
        adaptiveLookAhead;

    var segmentIndex =
        nearest.segmentIndex;

    var segmentStart =
        nearest.projectedPoint;

    while (
        segmentIndex <
            route.polyline.length - 1) {
      final segmentEnd =
          route.polyline[segmentIndex + 1];

      final segmentDistance =
          distanceBetween(
        segmentStart,
        segmentEnd,
      );

      if (segmentDistance <= 0.01) {
        segmentIndex++;
        segmentStart =
            route.polyline[segmentIndex];
        continue;
      }

      if (remainingLookAhead <=
          segmentDistance) {
        final factor =
            remainingLookAhead /
                segmentDistance;

        final target =
            _interpolatePoint(
          segmentStart,
          segmentEnd,
          factor,
        );

        final routeBearing =
            calculateBearing(
          from: segmentStart,
          to: segmentEnd,
        );

        return RouteTarget(
          point: target,
          index: segmentIndex + 1,
          distanceAheadMeters:
              adaptiveLookAhead -
                  remainingLookAhead +
                  remainingLookAhead,
          distanceFromRouteMeters:
              nearest.distanceFromRouteMeters,
          routeBearing: routeBearing,
          isNearTurn:
              _isTurnNear(
            route: route,
            segmentIndex:
                segmentIndex,
          ),
        );
      }

      remainingLookAhead -=
          segmentDistance;

      segmentIndex++;

      segmentStart =
          route.polyline[segmentIndex];
    }

    final lastIndex =
        route.polyline.length - 1;

    double? finalBearing;

    if (lastIndex > 0) {
      finalBearing =
          calculateBearing(
        from: route.polyline[lastIndex - 1],
        to: route.polyline[lastIndex],
      );
    }

    return RouteTarget(
      point: route.polyline[lastIndex],
      index: lastIndex,
      distanceAheadMeters:
          adaptiveLookAhead -
              remainingLookAhead,
      distanceFromRouteMeters:
          nearest.distanceFromRouteMeters,
      routeBearing: finalBearing,
      isNearTurn: false,
    );
  }

  // ================================================================
  // ADAPTIVE LOOK-AHEAD
  // ================================================================

  double _calculateAdaptiveLookAhead({
    required RouteResult route,
    required int nearestSegmentIndex,
    required LatLon projectedPoint,
  }) {
    final turnDistance =
        _distanceToNextMeaningfulTurn(
      route: route,
      startSegmentIndex:
          nearestSegmentIndex,
      projectedPoint:
          projectedPoint,
    );

    if (turnDistance == null) {
      return defaultLookAheadMeters
          .clamp(
            minimumLookAheadMeters,
            maximumLookAheadMeters,
          )
          .toDouble();
    }

    // Very close to a turn.
    if (turnDistance <= 7.0) {
      return minimumLookAheadMeters;
    }

    // Turn is approaching.
    if (turnDistance <= 15.0) {
      return 5.0;
    }

    // Turn exists but is still far enough away.
    if (turnDistance <= 25.0) {
      return 7.0;
    }

    return maximumLookAheadMeters;
  }

  // ================================================================
  // NEXT TURN
  // ================================================================

  double? _distanceToNextMeaningfulTurn({
    required RouteResult route,
    required int startSegmentIndex,
    required LatLon projectedPoint,
  }) {
    final polyline = route.polyline;

    if (polyline.length < 3) {
      return null;
    }

    var accumulatedDistance = 0.0;

    // Distance from the current projected point
    // to the end of the current segment.
    if (startSegmentIndex <
        polyline.length - 1) {
      accumulatedDistance +=
          distanceBetween(
        projectedPoint,
        polyline[startSegmentIndex + 1],
      );
    }

    for (
      var i = startSegmentIndex + 1;
      i < polyline.length - 1;
      i++
    ) {
      if (i + 1 >= polyline.length) {
        break;
      }

      final incomingBearing =
          calculateBearing(
        from: polyline[i - 1],
        to: polyline[i],
      );

      final outgoingBearing =
          calculateBearing(
        from: polyline[i],
        to: polyline[i + 1],
      );

      final turnAngle =
          _angularDifference(
        incomingBearing,
        outgoingBearing,
      );

      if (turnAngle >=
          turnDetectionAngleDegrees) {
        return accumulatedDistance;
      }

      accumulatedDistance +=
          distanceBetween(
        polyline[i],
        polyline[i + 1],
      );
    }

    return null;
  }

  bool _isTurnNear({
    required RouteResult route,
    required int segmentIndex,
  }) {
    if (route.polyline.length < 3) {
      return false;
    }

    if (segmentIndex <= 0 ||
        segmentIndex >=
            route.polyline.length - 1) {
      return false;
    }

    final incomingBearing =
        calculateBearing(
      from:
          route.polyline[segmentIndex - 1],
      to:
          route.polyline[segmentIndex],
    );

    final outgoingBearing =
        calculateBearing(
      from:
          route.polyline[segmentIndex],
      to:
          route.polyline[segmentIndex + 1],
    );

    return _angularDifference(
          incomingBearing,
          outgoingBearing,
        ) >=
        turnDetectionAngleDegrees;
  }

  // ================================================================
  // NEAREST ROUTE POINT
  // ================================================================

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

  // ================================================================
  // DISTANCE
  // ================================================================

  double distanceBetween(
    LatLon first,
    LatLon second,
  ) {
    const earthRadiusMeters =
        6371000.0;

    final latitude1 =
        _degreesToRadians(
      first.latitude,
    );

    final latitude2 =
        _degreesToRadians(
      second.latitude,
    );

    final deltaLatitude =
        _degreesToRadians(
      second.latitude -
          first.latitude,
    );

    final deltaLongitude =
        _degreesToRadians(
      second.longitude -
          first.longitude,
    );

    final a =
        math.sin(
                  deltaLatitude / 2,
                ) *
                math.sin(
                  deltaLatitude / 2,
                ) +
            math.cos(latitude1) *
                math.cos(latitude2) *
                math.sin(
                  deltaLongitude / 2,
                ) *
                math.sin(
                  deltaLongitude / 2,
                );

    final c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusMeters * c;
  }

  // ================================================================
  // BEARING
  // ================================================================

  double calculateBearing({
    required LatLon from,
    required LatLon to,
  }) {
    final latitude1 =
        _degreesToRadians(
      from.latitude,
    );

    final latitude2 =
        _degreesToRadians(
      to.latitude,
    );

    final deltaLongitude =
        _degreesToRadians(
      to.longitude -
          from.longitude,
    );

    final y =
        math.sin(deltaLongitude) *
            math.cos(latitude2);

    final x =
        math.cos(latitude1) *
                math.sin(latitude2) -
            math.sin(latitude1) *
                math.cos(latitude2) *
                math.cos(deltaLongitude);

    final bearing =
        math.atan2(y, x);

    return _normalizeBearing(
      _radiansToDegrees(bearing),
    );
  }

  // ================================================================
  // NEAREST POINT
  // ================================================================

  _NearestRoutePoint _findNearestPointOnRoute({
    required LatLon currentPosition,
    required List<LatLon> polyline,
  }) {
    var nearestDistance =
        double.infinity;

    var nearestSegmentIndex = 0;

    LatLon? nearestPoint;

    for (
      var i = 0;
      i < polyline.length - 1;
      i++
    ) {
      final start =
          polyline[i];

      final end =
          polyline[i + 1];

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

      if (distance <
          nearestDistance) {
        nearestDistance =
            distance;

        nearestSegmentIndex =
            i;

        nearestPoint =
            projected;
      }
    }

    return _NearestRoutePoint(
      segmentIndex:
          nearestSegmentIndex,
      projectedPoint:
          nearestPoint!,
      distanceFromRouteMeters:
          nearestDistance,
    );
  }

  // ================================================================
  // PROJECT GPS ONTO ROUTE SEGMENT
  // ================================================================

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

    t = t.clamp(
      0.0,
      1.0,
    );

    return _interpolatePoint(
      start,
      end,
      t,
    );
  }

  // ================================================================
  // INTERPOLATION
  // ================================================================

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

  // ================================================================
  // ANGLES
  // ================================================================

  double _angularDifference(
    double first,
    double second,
  ) {
    var difference =
        (first - second) % 360;

    if (difference > 180) {
      difference -= 360;
    }

    if (difference < -180) {
      difference += 360;
    }

    return difference.abs();
  }

  double _normalizeBearing(
    double bearing,
  ) {
    var normalized =
        bearing % 360;

    if (normalized < 0) {
      normalized += 360;
    }

    return normalized;
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees *
        math.pi /
        180.0;
  }

  double _radiansToDegrees(
    double radians,
  ) {
    return radians *
        180.0 /
        math.pi;
  }
}

// ================================================================
// ROUTE TARGET
// ================================================================

class RouteTarget {
  const RouteTarget({
    required this.point,
    required this.index,
    required this.distanceAheadMeters,
    required this.distanceFromRouteMeters,
    required this.routeBearing,
    required this.isNearTurn,
  });

  final LatLon point;

  /// Polyline segment/end index around the target.
  final int index;

  /// Actual distance travelled ahead along the route.
  final double distanceAheadMeters;

  /// Distance between GPS position and route.
  final double distanceFromRouteMeters;

  /// Direction of travel along the route.
  ///
  /// This is deliberately different from the bearing
  /// from the user's GPS position to the target.
  final double? routeBearing;

  /// Whether the target is close to a meaningful route turn.
  final bool isNearTurn;
}

// ================================================================
// INTERNAL NEAREST POINT
// ================================================================

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

// ================================================================
// FAILURE
// ================================================================

class RouteProgressFailure implements Exception {
  const RouteProgressFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

