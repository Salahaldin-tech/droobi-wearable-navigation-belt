import 'dart:math' as math;

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
    if (!_hasValidAccuracy(fix)) return null;
    if (!_hasValidTimestamp(fix)) return null;

    final previous = _lastAcceptedFix;
    if (previous == null) {
      _lastAcceptedFix = fix;
      return fix;
    }

    final elapsed = fix.timestamp.difference(previous.timestamp);
    if (elapsed.inMilliseconds <= 0) {
      // Duplicate and out-of-order fixes must not move the navigation state.
      return null;
    }

    // After a long GPS interruption, establish a fresh baseline instead of
    // rejecting the first resumed fix based on a stale previous position.
    if (elapsed > const Duration(seconds: 45)) {
      _lastAcceptedFix = fix;
      return fix;
    }

    final elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final distance = _distanceBetween(previous, fix);
    final impliedSpeed = distance / elapsedSeconds;

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

  void reset() {
    _lastAcceptedFix = null;
  }

  bool _hasValidAccuracy(LocationFix fix) {
    return fix.accuracyMeters.isFinite &&
        fix.accuracyMeters >= 0 &&
        fix.accuracyMeters <= maxAccuracyMeters;
  }

  bool _hasValidTimestamp(LocationFix fix) {
    final age = _clock().difference(fix.timestamp);
    return age <= maximumFixAge && age >= -maximumFutureSkew;
  }

  double _distanceBetween(LocationFix first, LocationFix second) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = first.position.latitude * math.pi / 180;
    final lat2 = second.position.latitude * math.pi / 180;
    final deltaLat =
        (second.position.latitude - first.position.latitude) * math.pi / 180;
    final deltaLon =
        (second.position.longitude - first.position.longitude) * math.pi / 180;
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
