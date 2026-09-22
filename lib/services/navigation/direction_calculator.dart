import 'dart:math' as math;

import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';

class DirectionCalculator {
  NavigationDirection calculate({
    required LatLon currentPosition,
    required LatLon targetPoint,
    required double heading,
  }) {
    final bearing = calculateBearing(
      from: currentPosition,
      to: targetPoint,
    );

    final relativeAngle = normalizeAngle(
      bearing - heading,
    );

    return directionFromAngle(relativeAngle);
  }

  double calculateBearing({
    required LatLon from,
    required LatLon to,
  }) {
    final lat1 = _degreesToRadians(from.latitude);
    final lat2 = _degreesToRadians(to.latitude);

    final deltaLongitude = _degreesToRadians(
      to.longitude - from.longitude,
    );

    final y = math.sin(deltaLongitude) * math.cos(lat2);

    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) *
            math.cos(lat2) *
            math.cos(deltaLongitude);

    final bearing = math.atan2(y, x);

    return _normalizeBearing(
      _radiansToDegrees(bearing),
    );
  }

  NavigationDirection directionFromAngle(double angle) {
    final normalizedAngle = normalizeAngle(angle);

    if (normalizedAngle >= -22.5 &&
        normalizedAngle < 22.5) {
      return NavigationDirection.forward;
    }

    if (normalizedAngle >= 22.5 &&
        normalizedAngle < 67.5) {
      return NavigationDirection.forwardRight;
    }

    if (normalizedAngle >= 67.5 &&
        normalizedAngle < 112.5) {
      return NavigationDirection.right;
    }

    if (normalizedAngle >= 112.5 &&
        normalizedAngle < 157.5) {
      return NavigationDirection.backRight;
    }

    if (normalizedAngle >= 157.5 ||
        normalizedAngle < -157.5) {
      return NavigationDirection.back;
    }

    if (normalizedAngle >= -157.5 &&
        normalizedAngle < -112.5) {
      return NavigationDirection.backLeft;
    }

    if (normalizedAngle >= -112.5 &&
        normalizedAngle < -67.5) {
      return NavigationDirection.left;
    }

    return NavigationDirection.forwardLeft;
  }

  double normalizeAngle(double angle) {
    var normalized = angle % 360;

    if (normalized > 180) {
      normalized -= 360;
    }

    if (normalized <= -180) {
      normalized += 360;
    }

    return normalized;
  }

  double _normalizeBearing(double bearing) {
    var normalized = bearing % 360;

    if (normalized < 0) {
      normalized += 360;
    }

    return normalized;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }
}