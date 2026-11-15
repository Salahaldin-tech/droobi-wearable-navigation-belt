import 'dart:math' as math;

import '../../core/geo/geo_math.dart';
import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';

/// Why the most recent fix was rejected.
enum GpsRejectReason {
  invalidCoordinates,
  poorAccuracy,
  outOfOrder,
  implausibleJump,
}

/// Pedestrian GPS filter.
///
/// 1. Rejects malformed, low-accuracy, duplicated and out-of-order fixes.
/// 2. Rejects jumps that would require an implausible walking speed *after*
///    allowing for both fixes' reported uncertainty (a raw speed check rejects
///    honest fixes whenever accuracy is poor).
/// 3. Recovers from a bad anchor: if several consecutive rejected fixes agree
///    with each other, the previous anchor was the outlier, so the filter
///    re-anchors instead of rejecting the user's true position indefinitely.
/// 4. Smooths accepted fixes with a constant-velocity Kalman filter in a local
///    metric frame, and estimates speed and course over ground.
///
/// The reported accuracy remains the receiver's raw accuracy. GPS errors are
/// time-correlated, so the Kalman covariance alone would be over-confident.
class GpsFilterService {
  GpsFilterService({
    this.maxAccuracyMeters = 25.0,
    this.maxWalkingSpeedMetersPerSecond = 3.0,
    this.accelerationNoise = 0.5,
    this.reanchorAfterConsistentRejections = 3,
    this.reanchorAfterGap = const Duration(seconds: 12),
    this.minimumCourseSpeedMetersPerSecond = 0.5,
    this.smoothing = true,
  });

  final double maxAccuracyMeters;
  final double maxWalkingSpeedMetersPerSecond;

  /// Kalman process noise: walking acceleration standard deviation (m/s²).
  final double accelerationNoise;

  /// Consecutive mutually-consistent rejected fixes that prove the anchor
  /// was wrong.
  final int reanchorAfterConsistentRejections;

  /// After a gap this long the motion model is meaningless; restart from the
  /// next valid fix rather than gating it against a stale anchor.
  final Duration reanchorAfterGap;

  final double minimumCourseSpeedMetersPerSecond;

  /// When false, accepted fixes are passed through unsmoothed (gating and
  /// re-anchoring still apply).
  final bool smoothing;

  LocationFix? _lastAcceptedRaw;
  LocationFix? _lastAcceptedFix;
  final List<LocationFix> _rejectedRun = <LocationFix>[];
  GpsRejectReason? _lastRejectReason;
  int _consecutiveRejections = 0;

  LocalFrame? _frame;
  // Per-axis state [position, velocity] and covariance [[p00,p01],[p01,p11]].
  final _Axis _east = _Axis();
  final _Axis _north = _Axis();

  /// Most recent fix returned by [process] (filtered).
  LocationFix? get lastAcceptedFix => _lastAcceptedFix;

  GpsRejectReason? get lastRejectReason => _lastRejectReason;

  int get consecutiveRejections => _consecutiveRejections;

  /// Returns the filtered fix, or null when the fix is rejected.
  LocationFix? process(LocationFix fix) {
    if (!_validCoordinates(fix.position)) {
      return _reject(GpsRejectReason.invalidCoordinates);
    }
    final accuracy = fix.accuracyMeters;
    if (!accuracy.isFinite || accuracy < 0 || accuracy > maxAccuracyMeters) {
      return _reject(GpsRejectReason.poorAccuracy);
    }

    final previous = _lastAcceptedRaw;
    if (previous == null) return _anchor(fix);

    final dtSeconds =
        fix.timestamp.difference(previous.timestamp).inMicroseconds / 1e6;
    if (dtSeconds <= 0) {
      return _reject(GpsRejectReason.outOfOrder);
    }
    if (fix.timestamp.difference(previous.timestamp) > reanchorAfterGap) {
      return _anchor(fix);
    }

    if (!_isPlausible(previous, fix)) {
      // Keep the run of rejected fixes; if they agree with each other the
      // anchor was the outlier.
      if (_rejectedRun.isNotEmpty && !_isPlausible(_rejectedRun.last, fix)) {
        _rejectedRun.clear();
      }
      _rejectedRun.add(fix);
      if (_rejectedRun.length >= reanchorAfterConsistentRejections) {
        return _anchor(fix);
      }
      return _reject(GpsRejectReason.implausibleJump);
    }

    return _accept(fix, dtSeconds);
  }

  void reset() {
    _lastAcceptedRaw = null;
    _lastAcceptedFix = null;
    _rejectedRun.clear();
    _lastRejectReason = null;
    _consecutiveRejections = 0;
    _frame = null;
  }

  // ------------------------------------------------------------------

  bool _isPlausible(LocationFix from, LocationFix to) {
    final dt = to.timestamp.difference(from.timestamp).inMicroseconds / 1e6;
    if (dt <= 0) return false;
    final distance = GeoMath.distance(from.position, to.position);
    final uncertainty = math.sqrt(
      from.accuracyMeters * from.accuracyMeters +
          to.accuracyMeters * to.accuracyMeters,
    );
    final unexplained = math.max(0.0, distance - uncertainty);
    return unexplained / dt <= maxWalkingSpeedMetersPerSecond;
  }

  /// Invalid, inaccurate and out-of-order fixes neither prove nor disprove
  /// the anchor, so they leave the run of rejected jumps untouched.
  LocationFix? _reject(GpsRejectReason reason) {
    _lastRejectReason = reason;
    _consecutiveRejections++;
    return null;
  }

  LocationFix _anchor(LocationFix fix) {
    _frame = LocalFrame(fix.position);
    final variance = math.max(1.0, fix.accuracyMeters * fix.accuracyMeters);
    _east.init(0, variance);
    _north.init(0, variance);
    _rejectedRun.clear();
    _consecutiveRejections = 0;
    _lastRejectReason = null;
    _lastAcceptedRaw = fix;
    final out = LocationFix(
      position: fix.position,
      accuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
      speedMetersPerSecond: fix.speedMetersPerSecond,
      courseDegrees: _platformCourse(fix),
      courseAccuracyDegrees:
          _platformCourse(fix) == null ? null : fix.courseAccuracyDegrees,
    );
    _lastAcceptedFix = out;
    return out;
  }

  LocationFix _accept(LocationFix fix, double dt) {
    _rejectedRun.clear();
    _consecutiveRejections = 0;
    _lastRejectReason = null;
    _lastAcceptedRaw = fix;

    final frame = _frame!;
    final (zEast, zNorth) = frame.toLocal(fix.position);
    final r = math.max(1.0, fix.accuracyMeters * fix.accuracyMeters);
    final q = accelerationNoise * accelerationNoise;
    _east.predict(dt, q);
    _north.predict(dt, q);
    _east.update(zEast, r);
    _north.update(zNorth, r);

    final position = smoothing ? frame.toLatLon(_east.x, _north.x) : fix.position;

    final speed = math.sqrt(_east.v * _east.v + _north.v * _north.v);
    final speedSigma = math.sqrt(math.max(0.0, (_east.p11 + _north.p11) / 2));

    double? course;
    double? courseSigma;
    final platformCourse = _platformCourse(fix);
    if (platformCourse != null) {
      course = platformCourse;
      courseSigma = fix.courseAccuracyDegrees;
    } else if (speed >= minimumCourseSpeedMetersPerSecond &&
        speedSigma < speed) {
      course = GeoMath.normalize360(
        math.atan2(_east.v, _north.v) * 180 / math.pi,
      );
      courseSigma = math.atan2(speedSigma, speed) * 180 / math.pi;
    }

    final out = LocationFix(
      position: position,
      accuracyMeters: fix.accuracyMeters,
      timestamp: fix.timestamp,
      speedMetersPerSecond: fix.speedMetersPerSecond ?? speed,
      courseDegrees: course,
      courseAccuracyDegrees: courseSigma,
    );
    _lastAcceptedFix = out;
    return out;
  }

  double? _platformCourse(LocationFix fix) {
    final course = fix.courseDegrees;
    final speed = fix.speedMetersPerSecond;
    if (course == null || speed == null || !course.isFinite) return null;
    if (speed < minimumCourseSpeedMetersPerSecond) return null;
    return GeoMath.normalize360(course);
  }

  static bool _validCoordinates(LatLon p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      !(p.latitude == 0 && p.longitude == 0);
}

/// One axis of a constant-velocity Kalman filter.
class _Axis {
  double x = 0;
  double v = 0;
  double p00 = 1;
  double p01 = 0;
  double p11 = 1;

  void init(double position, double positionVariance) {
    x = position;
    v = 0;
    p00 = positionVariance;
    p01 = 0;
    // Unknown initial walking velocity: ~2 m/s standard deviation.
    p11 = 4.0;
  }

  void predict(double dt, double q) {
    x += v * dt;
    // P = F P F^T + Q, with white-acceleration Q.
    final dt2 = dt * dt;
    final n00 = p00 + 2 * dt * p01 + dt2 * p11 + q * dt2 * dt2 / 4;
    final n01 = p01 + dt * p11 + q * dt2 * dt / 2;
    final n11 = p11 + q * dt2;
    p00 = n00;
    p01 = n01;
    p11 = n11;
  }

  void update(double z, double r) {
    final s = p00 + r;
    final k0 = p00 / s;
    final k1 = p01 / s;
    final innovation = z - x;
    x += k0 * innovation;
    v += k1 * innovation;
    final n00 = (1 - k0) * p00;
    final n01 = (1 - k0) * p01;
    final n11 = p11 - k1 * p01;
    p00 = n00;
    p01 = n01;
    p11 = n11;
  }
}
