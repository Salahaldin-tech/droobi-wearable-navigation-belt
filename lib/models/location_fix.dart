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

  /// Ground speed reported by the operating system, in metres per second.
  final double? speedMetersPerSecond;

  /// Direction of travel reported by GPS, clockwise from north.
  /// It is not the phone's compass heading.
  final double? courseDegrees;

  /// Accuracy of [courseDegrees], in degrees, when supplied by the OS.
  final double? courseAccuracyDegrees;

  bool get hasGoodAccuracy => accuracyMeters <= 25.0;

  bool get hasHighAccuracy => accuracyMeters <= 10.0;

  /// GPS course is only a useful heading cross-check while moving steadily.
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
        accuracy <= 20.0;
  }

  @override
  String toString() {
    return 'LocationFix('
        'lat=${position.latitude}, '
        'lon=${position.longitude}, '
        'accuracy=${accuracyMeters.toStringAsFixed(1)}m, '
        'speed=${speedMetersPerSecond?.toStringAsFixed(2) ?? 'n/a'}m/s, '
        'course=${courseDegrees?.toStringAsFixed(1) ?? 'n/a'}°, '
        'timestamp=$timestamp'
        ')';
  }
}
