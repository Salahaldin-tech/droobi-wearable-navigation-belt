import 'dart:math' as math;

import '../../core/geo/geo_math.dart';

/// Bounded estimate of the offset between the phone compass and the user's
/// real direction of travel (GPS course over ground).
///
/// The phone is rarely aligned exactly with the body, and local magnetic
/// disturbance (buildings, rebar, the phone case) biases the compass. While
/// the user walks straight with a good GPS course, `course - compass` is a
/// direct measurement of that combined bias. No external IMU is required.
///
/// Call [addSample] only with samples already gated for straight walking and
/// good GPS; this class does not decide whether a sample is safe to use.
class CourseOffsetEstimator {
  CourseOffsetEstimator({
    this.maximumOffsetDegrees = 35,
    this.maximumOutlierDegrees = 45,
    this.minimumGain = 0.04,
    this.initializationSamples = 5,
    this.maximumInitializationSpreadDegrees = 15,
  });

  final double maximumOffsetDegrees;
  final double maximumOutlierDegrees;
  final double minimumGain;

  /// Samples collected before the first estimate is published. A single
  /// sample is never trusted.
  final int initializationSamples;

  /// The initial samples must agree within roughly this spread; otherwise
  /// they are discarded and collection restarts.
  final double maximumInitializationSpreadDegrees;

  double? _offset;
  int _acceptedSamples = 0;
  final List<double> _pending = <double>[];

  /// The current offset (add to the compass heading), or null until enough
  /// consistent samples have been collected.
  double? get offsetDegrees => _offset;
  int get acceptedSamples => _acceptedSamples;
  bool get isCalibrated => _offset != null;

  double? addSample({
    required double courseTrueDegrees,
    required double phoneTrueHeadingDegrees,
  }) {
    if (!courseTrueDegrees.isFinite || !phoneTrueHeadingDegrees.isFinite) {
      return _offset;
    }

    final sample = GeoMath.wrap180(courseTrueDegrees - phoneTrueHeadingDegrees);

    final current = _offset;
    if (current == null) {
      _pending.add(sample);
      _acceptedSamples++;
      if (_pending.length < initializationSamples) return null;

      final mean = GeoMath.circularMean(_pending);
      final resultant = GeoMath.resultantLength(_pending);
      // Mean resultant length for a given angular spread (≈ cos(spread)).
      final required =
          _cosDeg(maximumInitializationSpreadDegrees).clamp(0.0, 1.0);
      if (mean == null || resultant < required) {
        // Inconsistent: drop the oldest sample and keep collecting.
        _pending.removeAt(0);
        return null;
      }
      _pending.clear();
      _offset = _clamp(GeoMath.wrap180(mean));
      return _offset;
    }

    if (GeoMath.wrap180(sample - current).abs() > maximumOutlierDegrees) {
      return _offset;
    }

    _offset = _clamp(
      GeoMath.wrap180(current + minimumGain * GeoMath.wrap180(sample - current)),
    );
    _acceptedSamples++;
    return _offset;
  }

  void reset() {
    _offset = null;
    _acceptedSamples = 0;
    _pending.clear();
  }

  double _clamp(double value) =>
      value.clamp(-maximumOffsetDegrees, maximumOffsetDegrees).toDouble();

  static double _cosDeg(double degrees) => math.cos(degrees * math.pi / 180);
}
