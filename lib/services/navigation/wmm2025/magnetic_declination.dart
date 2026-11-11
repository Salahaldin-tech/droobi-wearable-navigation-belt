import 'dart:math' as math;

import 'wmm2025_coefficients.dart';

/// The result of evaluating the World Magnetic Model at one place and time.
class MagneticField {
  /// Creates a field sample.
  const MagneticField({
    required this.declination,
    required this.inclination,
    required this.horizontalIntensity,
    required this.totalIntensity,
    required this.isWithinValidity,
  });

  /// Angle from true north to magnetic north in degrees, positive east.
  final double declination;

  /// Dip angle of the field in degrees, positive downwards.
  final double inclination;

  /// Horizontal field intensity in nanotesla.
  final double horizontalIntensity;

  /// Total field intensity in nanotesla.
  final double totalIntensity;

  /// Whether the date was inside the model's five-year validity window.
  ///
  /// Outside the window the model is extrapolated and gets less accurate.
  final bool isWithinValidity;

  @override
  String toString() =>
      'MagneticField(declination: ${declination.toStringAsFixed(2)}, '
      'inclination: ${inclination.toStringAsFixed(2)})';
}

/// Magnetic declination from the NOAA World Magnetic Model 2025 (WMM2025),
/// computed in pure Dart. No network, no location plugin, no assets.
///
/// The model epoch is 2025.0 and it is valid until 2030.0. Accuracy is about
/// 0.5 degrees in declination for most of the world; it is poor close to the
/// magnetic poles where a compass is unreliable anyway.
abstract final class MagneticDeclination {
  /// First instant the bundled model is valid for (2025-01-01 UTC).
  static final DateTime validFrom = DateTime.utc(2025);

  /// Instant the bundled model stops being valid (2030-01-01 UTC).
  static final DateTime validUntil = DateTime.utc(2030);

  static const int _maxDegree = 12;
  static const double _a = 6378.137; // WGS84 semi-major axis, km
  static const double _e2 = 0.0066943799901413165; // WGS84 eccentricity^2
  static const double _refRadius = 6371.2; // geomagnetic reference radius, km

  /// Magnetic declination in degrees (positive east, in `(-180, 180]`) at
  /// [latitude]/[longitude] degrees, [altitudeMeters] above the WGS84
  /// ellipsoid, at [date] (defaults to now).
  ///
  /// True heading = magnetic heading + declination.
  static double at({
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    DateTime? date,
  }) =>
      field(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        date: date,
      ).declination;

  /// Evaluates the full field. See [at] for the parameters.
  static MagneticField field({
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    DateTime? date,
  }) {
    if (!latitude.isFinite || !longitude.isFinite) {
      throw ArgumentError('latitude and longitude must be finite');
    }
    final when = (date ?? DateTime.now()).toUtc();
    final year = decimalYear(when);
    // Keep clear of the geographic poles where longitude is undefined.
    final lat = latitude.clamp(-89.9999, 89.9999);
    final phi = lat * math.pi / 180.0;
    final lambda = longitude * math.pi / 180.0;
    final altKm = altitudeMeters / 1000.0;

    // Geodetic -> geocentric spherical coordinates.
    final sinPhi = math.sin(phi);
    final cosPhi = math.cos(phi);
    final rc = _a / math.sqrt(1 - _e2 * sinPhi * sinPhi);
    final p = (rc + altKm) * cosPhi;
    final z = (rc * (1 - _e2) + altKm) * sinPhi;
    final r = math.sqrt(p * p + z * z);
    final phiG = math.asin(z / r); // geocentric latitude
    final ct = math.sin(phiG); // cos(colatitude)
    final st = math.cos(phiG); // sin(colatitude)

    // Legendre functions P[n][m] and d/dtheta, Schmidt semi-normalized.
    const size = _maxDegree + 1;
    final pnm = List.generate(size, (_) => List<double>.filled(size, 0));
    final dpnm = List.generate(size, (_) => List<double>.filled(size, 0));
    pnm[0][0] = 1;
    for (var n = 1; n <= _maxDegree; n++) {
      for (var m = 0; m <= n; m++) {
        if (n == m) {
          pnm[n][n] = st * pnm[n - 1][n - 1];
          dpnm[n][n] = st * dpnm[n - 1][n - 1] + ct * pnm[n - 1][n - 1];
        } else if (n == 1 && m == 0) {
          pnm[1][0] = ct * pnm[0][0];
          dpnm[1][0] = ct * dpnm[0][0] - st * pnm[0][0];
        } else {
          final k = n == 1
              ? 0.0
              : ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
          final prev2 = n >= 2 ? pnm[n - 2][m] : 0.0;
          final dprev2 = n >= 2 ? dpnm[n - 2][m] : 0.0;
          pnm[n][m] = ct * pnm[n - 1][m] - k * prev2;
          dpnm[n][m] = ct * dpnm[n - 1][m] - st * pnm[n - 1][m] - k * dprev2;
        }
      }
    }
    // Schmidt quasi-normalization factors.
    final snorm = List.generate(size, (_) => List<double>.filled(size, 0));
    snorm[0][0] = 1;
    for (var n = 1; n <= _maxDegree; n++) {
      snorm[n][0] = snorm[n - 1][0] * (2 * n - 1) / n;
      for (var m = 1; m <= n; m++) {
        final delta = m == 1 ? 2.0 : 1.0;
        snorm[n][m] =
            snorm[n][m - 1] * math.sqrt((n - m + 1) * delta / (n + m));
      }
    }

    // Sum the spherical harmonic series.
    final dt = year - 2025.0;
    var north = 0.0; // X' (geocentric)
    var east = 0.0; // Y'
    var down = 0.0; // Z'
    final ratio = _refRadius / r;
    final c = wmm2025Coefficients;
    for (var i = 0; i < c.length; i += 6) {
      final n = c[i].toInt();
      final m = c[i + 1].toInt();
      final g = c[i + 2] + dt * c[i + 4];
      final h = c[i + 3] + dt * c[i + 5];
      final rn = math.pow(ratio, n + 2).toDouble();
      final cosM = math.cos(m * lambda);
      final sinM = math.sin(m * lambda);
      final pn = pnm[n][m] * snorm[n][m];
      final dpn = dpnm[n][m] * snorm[n][m];
      north += rn * (g * cosM + h * sinM) * dpn;
      east += rn * m * (g * sinM - h * cosM) * pn / st;
      down -= rn * (n + 1) * (g * cosM + h * sinM) * pn;
    }

    // Rotate to the geodetic frame.
    final psi = phi - phiG;
    final x = north * math.cos(psi) + down * math.sin(psi);
    final y = east;
    final zz = down * math.cos(psi) - north * math.sin(psi);
    final horizontal = math.sqrt(x * x + y * y);
    return MagneticField(
      declination: math.atan2(y, x) * 180.0 / math.pi,
      inclination: math.atan2(zz, horizontal) * 180.0 / math.pi,
      horizontalIntensity: horizontal,
      totalIntensity: math.sqrt(horizontal * horizontal + zz * zz),
      isWithinValidity: !when.isBefore(validFrom) && when.isBefore(validUntil),
    );
  }

  /// Converts [date] to a decimal year (for example mid-2026 is about 2026.5).
  static double decimalYear(DateTime date) {
    final utc = date.toUtc();
    final start = DateTime.utc(utc.year);
    final end = DateTime.utc(utc.year + 1);
    final fraction = utc.difference(start).inMicroseconds /
        end.difference(start).inMicroseconds;
    return utc.year + fraction;
  }
}
