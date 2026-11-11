import 'dart:math' as math;

import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';

class GpsFilterService {
  GpsFilterService({
    this.maxAccuracyMeters = 25.0,
    this.maxWalkingSpeedMetersPerSecond = 3.0,
    this.maximumFixAge = const Duration(seconds: 15),
    this.maximumFutureSkew = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final double maxAccuracyMeters;
  final double maxWalkingSpeedMetersPerSecond;
  final Duration maximumFixAge;
  final Duration maximumFutureSkew;
  final DateTime Function() _clock;

  LocationFix? _lastAcceptedFix;

  LocationFix? get lastAcceptedFix => _lastAcceptedFix;

  LocationFix? process(LocationFix fix) {
    if (!fix.accuracyMeters.isFinite ||
        fix.accuracyMeters < 0 ||
        fix.accuracyMeters > maxAccuracyMeters) {
      return null;
    }

    final age = _clock().difference(fix.timestamp);
    if (age > maximumFixAge || age < -maximumFutureSkew) return null;

    final previous = _lastAcceptedFix;
    if (previous == null) {
      _lastAcceptedFix = fix;
      return fix;
    }

    final elapsed = fix.timestamp.difference(previous.timestamp);
    if (elapsed.inMicroseconds <= 0) return null;

    if (elapsed > const Duration(seconds: 45)) {
      _lastAcceptedFix = fix;
      return fix;
    }

    final seconds = elapsed.inMicroseconds /
        Duration.microsecondsPerSecond;
    final impliedSpeed = _distance(previous.position, fix.position) / seconds;
    if (!impliedSpeed.isFinite ||
        impliedSpeed > maxWalkingSpeedMetersPerSecond) {
      return null;
    }

    final reportedSpeed = fix.speedMetersPerSecond;
    if (reportedSpeed != null &&
        reportedSpeed.isFinite &&
        reportedSpeed > 5.5) {
      return null;
    }

    _lastAcceptedFix = fix;
    return fix;
  }

  void reset() => _lastAcceptedFix = null;

  double _distance(LatLon first, LatLon second) {
    const radius = 6371000.0;
    final lat1 = first.latitude * math.pi / 180;
    final lat2 = second.latitude * math.pi / 180;
    final dLat = (second.latitude - first.latitude) * math.pi / 180;
    final dLon = (second.longitude - first.longitude) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
