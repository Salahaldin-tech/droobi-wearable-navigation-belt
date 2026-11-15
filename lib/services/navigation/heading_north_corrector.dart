
import 'package:flutter/foundation.dart';

import '../../models/lat_lon.dart';
import 'wmm2025/magnetic_declination.dart';

/// Converts the platform's compass heading to a true-north heading.
///
/// Android's flutter_compass reading is magnetic and needs WMM declination.
/// iOS exposes Core Location trueHeading, so correction is zero there.
class HeadingNorthCorrector {
  HeadingNorthCorrector({
    TargetPlatform? platform,
    double Function(double latitude, double longitude, DateTime when)?
        declinationAt,
    DateTime Function()? clock,
  })  : _platform = platform ?? defaultTargetPlatform,
        _declinationAt = declinationAt ??
            ((latitude, longitude, when) => MagneticDeclination.at(
                  latitude: latitude,
                  longitude: longitude,
                  date: when,
                )),
        _clock = clock ?? DateTime.now;

  final TargetPlatform _platform;
  final double Function(double latitude, double longitude, DateTime when)
      _declinationAt;
  final DateTime Function() _clock;

  double? _cachedLatitude;
  double? _cachedLongitude;
  int? _cachedUtcDateKey;
  double? _cachedCorrection;

  /// East-positive correction in degrees to add to the raw heading.
  double correctionDegrees(LatLon at) {
    if (_platform == TargetPlatform.iOS) return 0;

    final when = _clock().toUtc();

    // Validate the model window before evaluating it.
    if (when.isBefore(MagneticDeclination.validFrom) ||
        !when.isBefore(MagneticDeclination.validUntil)) {
      throw const CompassNorthCorrectionFailure(
        'The magnetic model is outside its validity period.',
      );
    }

    final dateKey = when.year * 10000 + when.month * 100 + when.day;
    if (_cachedLatitude == at.latitude &&
        _cachedLongitude == at.longitude &&
        _cachedUtcDateKey == dateKey &&
        _cachedCorrection != null) {
      return _cachedCorrection!;
    }

    final correction = _declinationAt(
      at.latitude,
      at.longitude,
      when,
    );

    if (!correction.isFinite) {
      throw const CompassNorthCorrectionFailure(
        'Magnetic declination could not be calculated for this location.',
      );
    }

    _cachedLatitude = at.latitude;
    _cachedLongitude = at.longitude;
    _cachedUtcDateKey = dateKey;
    _cachedCorrection = correction;
    return correction;
  }

  static double apply(double heading, double correctionDegrees) {
    if (!heading.isFinite || !correctionDegrees.isFinite) {
      throw ArgumentError('Heading and correction must be finite.');
    }
    var result = (heading + correctionDegrees) % 360;
    if (result < 0) result += 360;
    return result;
  }
}

class CompassNorthCorrectionFailure implements Exception {
  const CompassNorthCorrectionFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
