import 'dart:math' as math;

import '../../models/lat_lon.dart';

/// Shared geodesy helpers for the navigation engine.
///
/// All bearings are degrees clockwise from true north in [0, 360).
/// Signed angles are degrees in (-180, 180].
class GeoMath {
  GeoMath._();

  static const double earthRadiusMeters = 6371000.0;
  static const double _degToRad = math.pi / 180.0;
  static const double _radToDeg = 180.0 / math.pi;

  /// Great-circle (haversine) distance in meters.
  static double distance(LatLon a, LatLon b) {
    final lat1 = a.latitude * _degToRad;
    final lat2 = b.latitude * _degToRad;
    final dLat = (b.latitude - a.latitude) * _degToRad;
    final dLon = (b.longitude - a.longitude) * _degToRad;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  /// Initial great-circle bearing from [from] to [to].
  static double bearing(LatLon from, LatLon to) {
    final lat1 = from.latitude * _degToRad;
    final lat2 = to.latitude * _degToRad;
    final dLon = (to.longitude - from.longitude) * _degToRad;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return normalize360(math.atan2(y, x) * _radToDeg);
  }

  static double normalize360(double degrees) {
    final value = degrees % 360;
    return value < 0 ? value + 360 : value;
  }

  static double wrap180(double degrees) {
    var value = degrees % 360;
    if (value > 180) value -= 360;
    if (value <= -180) value += 360;
    return value;
  }

  /// Circular mean of bearings in degrees, or null when [values] is empty or
  /// the directions cancel out.
  static double? circularMean(Iterable<double> values) {
    var s = 0.0;
    var c = 0.0;
    var n = 0;
    for (final v in values) {
      s += math.sin(v * _degToRad);
      c += math.cos(v * _degToRad);
      n++;
    }
    if (n == 0) return null;
    if (math.sqrt(s * s + c * c) / n < 1e-6) return null;
    return normalize360(math.atan2(s, c) * _radToDeg);
  }

  /// Mean resultant length in [0, 1]: 1 means all bearings agree.
  static double resultantLength(Iterable<double> values) {
    var s = 0.0;
    var c = 0.0;
    var n = 0;
    for (final v in values) {
      s += math.sin(v * _degToRad);
      c += math.cos(v * _degToRad);
      n++;
    }
    if (n == 0) return 0;
    return math.sqrt(s * s + c * c) / n;
  }

  static LatLon interpolate(LatLon a, LatLon b, double t) => LatLon(
        latitude: a.latitude + (b.latitude - a.latitude) * t,
        longitude: a.longitude + (b.longitude - a.longitude) * t,
      );
}

/// Local east/north tangent plane around an origin. Accurate to centimetres
/// over the few kilometres a walking route spans.
class LocalFrame {
  LocalFrame(this.origin)
      : _metersPerDegLat = 111132.92 -
            559.82 * math.cos(2 * origin.latitude * math.pi / 180) +
            1.175 * math.cos(4 * origin.latitude * math.pi / 180),
        _metersPerDegLon = 111412.84 * math.cos(origin.latitude * math.pi / 180) -
            93.5 * math.cos(3 * origin.latitude * math.pi / 180);

  final LatLon origin;
  final double _metersPerDegLat;
  final double _metersPerDegLon;

  /// Returns (east, north) in meters.
  (double, double) toLocal(LatLon p) => (
        (p.longitude - origin.longitude) * _metersPerDegLon,
        (p.latitude - origin.latitude) * _metersPerDegLat,
      );

  LatLon toLatLon(double east, double north) => LatLon(
        latitude: origin.latitude + north / _metersPerDegLat,
        longitude: origin.longitude + east / _metersPerDegLon,
      );
}
