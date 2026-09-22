import 'dart:math' as math;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';

class RouteProgressService {
  /// Finds the nearest point on the route and then selects
  /// a point ahead of the user by [lookAheadPoints].
  LatLon getNextTargetPoint({
    required LatLon currentPosition,
    required RouteResult route,
    int lookAheadPoints = 5,
  }) {
    if (route.polyline.isEmpty) {
      throw const RouteProgressFailure(
        'Route polyline is empty.',
      );
    }

    if (lookAheadPoints < 0) {
      throw const RouteProgressFailure(
        'Look-ahead points cannot be negative.',
      );
    }

    final nearestIndex = findNearestPointIndex(
      currentPosition: currentPosition,
      polyline: route.polyline,
    );

    final targetIndex = math.min(
      nearestIndex + lookAheadPoints,
      route.polyline.length - 1,
    );

    return route.polyline[targetIndex];
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

    var nearestIndex = 0;
    var nearestDistance = double.infinity;

    for (var i = 0; i < polyline.length; i++) {
      final distance = _distanceSquared(
        currentPosition,
        polyline[i],
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  double _distanceSquared(
    LatLon first,
    LatLon second,
  ) {
    final latitudeDifference =
        first.latitude - second.latitude;

    final longitudeDifference =
        first.longitude - second.longitude;

    return (latitudeDifference * latitudeDifference) +
        (longitudeDifference * longitudeDifference);
  }
}

class RouteProgressFailure implements Exception {
  const RouteProgressFailure(this.message);

  final String message;

  @override
  String toString() => message;
}