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

  /// Ground speed, when known (raw platform value or filter estimate).
  final double? speedMetersPerSecond;

  /// Direction of travel over ground, degrees from true north, when known.
  /// Only meaningful while the user is actually moving.
  final double? courseDegrees;

  /// One-sigma uncertainty of [courseDegrees], when known.
  final double? courseAccuracyDegrees;

  bool get hasGoodAccuracy => accuracyMeters <= 25.0;

  bool get hasHighAccuracy => accuracyMeters <= 10.0;

  @override
  String toString() {
    return 'LocationFix('
        'lat=${position.latitude}, '
        'lon=${position.longitude}, '
        'accuracy=${accuracyMeters.toStringAsFixed(1)}m, '
        'timestamp=$timestamp'
        '${speedMetersPerSecond == null ? '' : ', speed=${speedMetersPerSecond!.toStringAsFixed(2)}m/s'}'
        '${courseDegrees == null ? '' : ', course=${courseDegrees!.toStringAsFixed(0)}°'}'
        ')';
  }
}
