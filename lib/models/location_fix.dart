import 'package:flutter/foundation.dart';

import 'lat_lon.dart';

@immutable
class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyMeters,
    required this.timestamp,
    this.speedMetersPerSecond,
    this.courseDegrees,
    this.courseAccuracyDegrees,
  });

  final LatLon position;
  final double accuracyMeters;
  final DateTime timestamp;

  /// Operating-system GPS ground speed, not a compass-derived value.
  final double? speedMetersPerSecond;

  /// GPS direction of travel clockwise from true north.
  final double? courseDegrees;

  /// OS-reported course accuracy in degrees, where available.
  final double? courseAccuracyDegrees;

  bool get hasGoodAccuracy =>
      accuracyMeters.isFinite && accuracyMeters >= 0 && accuracyMeters <= 25;

  bool get hasHighAccuracy =>
      accuracyMeters.isFinite && accuracyMeters >= 0 && accuracyMeters <= 10;

  bool get hasReliableCourse {
    final speed = speedMetersPerSecond;
    final course = courseDegrees;
    final accuracy = courseAccuracyDegrees;
    return speed != null &&
        speed.isFinite &&
        speed >= 1.2 &&
        course != null &&
        course.isFinite &&
        accuracy != null &&
        accuracy.isFinite &&
        accuracy >= 0 &&
        accuracy <= 20;
  }

  @override
  String toString() => 'LocationFix('
      'lat=${position.latitude}, lon=${position.longitude}, '
      'accuracy=${accuracyMeters.toStringAsFixed(1)}m, '
      'speed=${speedMetersPerSecond?.toStringAsFixed(2) ?? "n/a"}m/s, '
      'course=${courseDegrees?.toStringAsFixed(1) ?? "n/a"}°, '
      'timestamp=$timestamp)';
}
