import 'dart:math' as math;

/// Optional, bounded estimate of the phone-to-travel heading offset.
///
/// Call only with samples already gated for straight walking and good GPS.
/// This class deliberately does not decide whether a sample is safe to use.
class CourseOffsetEstimator {
  CourseOffsetEstimator({
    this.maximumOffsetDegrees = 35,
    this.maximumOutlierDegrees = 45,
    this.minimumGain = 0.04,
  });

  final double maximumOffsetDegrees;
  final double maximumOutlierDegrees;
  final double minimumGain;

  double? _offset;
  int _acceptedSamples = 0;

  double? get offsetDegrees => _offset;
  int get acceptedSamples => _acceptedSamples;

  double? addSample({
    required double courseTrueDegrees,
    required double phoneTrueHeadingDegrees,
  }) {
    if (!courseTrueDegrees.isFinite || !phoneTrueHeadingDegrees.isFinite) {
      return _offset;
    }

    final sample = _wrap180(courseTrueDegrees - phoneTrueHeadingDegrees);
    if (_offset != null &&
        _wrap180(sample - _offset!).abs() > maximumOutlierDegrees) {
      return _offset;
    }

    final gain = _offset == null ? 1.0 : minimumGain;
    final next = _wrap180((_offset ?? sample) + gain * _wrap180(sample - (_offset ?? sample)));
    _offset = next.clamp(-maximumOffsetDegrees, maximumOffsetDegrees).toDouble();
    _acceptedSamples++;
    return _offset;
  }

  void reset() {
    _offset = null;
    _acceptedSamples = 0;
  }

  double _wrap180(double value) {
    var result = value % 360;
    if (result > 180) result -= 360;
    if (result <= -180) result += 360;
    return result;
  }
}
