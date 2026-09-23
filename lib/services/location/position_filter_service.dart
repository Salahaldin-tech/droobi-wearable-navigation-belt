import 'dart:math' as math;

import '../../models/location_fix.dart';
import '../../models/lat_lon.dart';

class PositionFilterService {
  PositionFilterService({
    this.smoothingFactor = 0.65,
    this.maxJumpMeters = 15.0,
  })  : assert(
          smoothingFactor > 0 && smoothingFactor <= 1,
          'smoothingFactor must be between 0 and 1.',
        ),
        assert(
          maxJumpMeters > 0,
          'maxJumpMeters must be greater than 0.',
        );

  /// Higher value = follows new GPS positions faster.
  ///
  /// 0.65 means:
  /// 65% new position
  /// 35% previous filtered position
  final double smoothingFactor;

  /// Prevents the smoother from blindly following an
  /// extremely large GPS jump.
  final double maxJumpMeters;

  LocationFix? _lastFilteredFix;

  LocationFix? get lastFilteredFix => _lastFilteredFix;

  LocationFix process(LocationFix fix) {
    final previous = _lastFilteredFix;

    if (previous == null) {
      _lastFilteredFix = fix;
      return fix;
    }

    final distance = _distanceBetween(
      previous.position,
      fix.position,
    );

    // A large jump that has already passed the GPS quality filter
    // should still be handled conservatively.
    //
    // We move only part of the way toward the new position.
    final effectiveFactor =
        distance > maxJumpMeters
            ? smoothingFactor * 0.5
            : smoothingFactor;

    final latitude =
        previous.position.latitude +
        (fix.position.latitude -
                previous.position.latitude) *
            effectiveFactor;

    final longitude =
        previous.position.longitude +
        (fix.position.longitude -
                previous.position.longitude) *
            effectiveFactor;

    final filteredFix = LocationFix(
      position: LatLon(
        latitude: latitude,
        longitude: longitude,
      ),
      accuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
    );

    _lastFilteredFix = filteredFix;

    return filteredFix;
  }

  void reset() {
    _lastFilteredFix = null;
  }

  double _distanceBetween(
    LatLon first,
    LatLon second,
  ) {
    const earthRadiusMeters = 6371000.0;

    final latitude1 =
        _degreesToRadians(first.latitude);

    final latitude2 =
        _degreesToRadians(second.latitude);

    final deltaLatitude =
        _degreesToRadians(
      second.latitude - first.latitude,
    );

    final deltaLongitude =
        _degreesToRadians(
      second.longitude - first.longitude,
    );

    final a =
        math.sin(deltaLatitude / 2) *
                math.sin(deltaLatitude / 2) +
            math.cos(latitude1) *
                math.cos(latitude2) *
                math.sin(deltaLongitude / 2) *
                math.sin(deltaLongitude / 2);

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