import 'package:flutter/foundation.dart';

import 'lat_lon.dart';

@immutable
class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final LatLon position;
  final double accuracyMeters;
  final DateTime timestamp;

  bool get hasGoodAccuracy => accuracyMeters <= 25.0;

  bool get hasHighAccuracy => accuracyMeters <= 10.0;

  @override
  String toString() {
    return 'LocationFix('
        'lat=${position.latitude}, '
        'lon=${position.longitude}, '
        'accuracy=${accuracyMeters.toStringAsFixed(1)}m, '
        'timestamp=$timestamp'
        ')';
  }
}