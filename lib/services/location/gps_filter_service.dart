import 'dart:math' as math;

import '../../models/location_fix.dart';

class GpsFilterService {
  GpsFilterService({
    this.maxAccuracyMeters = 25.0,
    this.maxWalkingSpeedMetersPerSecond = 3.0,
  });

  final double maxAccuracyMeters;

  final double maxWalkingSpeedMetersPerSecond;

  LocationFix? _lastAcceptedFix;

  LocationFix? get lastAcceptedFix =>
      _lastAcceptedFix;

  LocationFix? process(LocationFix fix) {
    // ----------------------------------------------------------
    // 1. Accuracy check
    // ----------------------------------------------------------

    if (!_hasValidAccuracy(fix)) {
      return null;
    }

    final previous = _lastAcceptedFix;

    // First valid GPS fix.
    if (previous == null) {
      _lastAcceptedFix = fix;
      return fix;
    }

    // ----------------------------------------------------------
    // 2. Time check
    // ----------------------------------------------------------

    final timeDifferenceSeconds =
        fix.timestamp
                .difference(previous.timestamp)
                .inMilliseconds /
            1000.0;

    // Ignore duplicated or invalid timestamps.
    if (timeDifferenceSeconds <= 0) {
      return null;
    }

    // ----------------------------------------------------------
    // 3. Distance check
    // ----------------------------------------------------------

    final distanceMeters =
        _distanceBetween(
      previous.position.latitude,
      previous.position.longitude,
      fix.position.latitude,
      fix.position.longitude,
    );

    // ----------------------------------------------------------
    // 4. Plausible walking speed check
    // ----------------------------------------------------------

    final impliedSpeed =
        distanceMeters /
            timeDifferenceSeconds;

    if (impliedSpeed >
        maxWalkingSpeedMetersPerSecond) {
      // GPS probably jumped.
      return null;
    }

    // ----------------------------------------------------------
    // 5. Accept fix
    // ----------------------------------------------------------

    _lastAcceptedFix = fix;

    return fix;
  }

  void reset() {
    _lastAcceptedFix = null;
  }

  bool _hasValidAccuracy(
    LocationFix fix,
  ) {
    if (!fix.accuracyMeters.isFinite) {
      return false;
    }

    if (fix.accuracyMeters < 0) {
      return false;
    }

    return fix.accuracyMeters <=
        maxAccuracyMeters;
  }

  double _distanceBetween(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;

    final lat1 =
        _degreesToRadians(latitude1);

    final lat2 =
        _degreesToRadians(latitude2);

    final deltaLat =
        _degreesToRadians(
      latitude2 - latitude1,
    );

    final deltaLon =
        _degreesToRadians(
      longitude2 - longitude1,
    );

    final a =
        math.sin(deltaLat / 2) *
                math.sin(deltaLat / 2) +
            math.cos(lat1) *
                math.cos(lat2) *
                math.sin(deltaLon / 2) *
                math.sin(deltaLon / 2);

    final c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees * math.pi / 180.0;
  }
}