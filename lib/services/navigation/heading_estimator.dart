import 'dart:math' as math;

/// Converts noisy phone compass readings into a stable circular heading.
///
/// The estimator accepts degrees in [0, 360), tolerates wraparound, and
/// temporarily holds its last trusted value when the source is unreliable.
class HeadingEstimator {
  HeadingEstimator({
    this.timeConstantSeconds = 0.4,
    this.minimumAccuracyDegrees = 15,
    this.maximumAccuracyDegrees = 45,
    this.unreliableHold = const Duration(seconds: 3),
  }) {
    if (timeConstantSeconds <= 0) {
      throw ArgumentError.value(timeConstantSeconds, 'timeConstantSeconds');
    }
  }

  final double timeConstantSeconds;
  final double minimumAccuracyDegrees;
  final double maximumAccuracyDegrees;
  final Duration unreliableHold;

  double? _heading;
  DateTime? _lastAcceptedAt;
  DateTime? _lastReliableAt;

  double? get heading => _heading;
  bool get isReliable => _heading != null && _lastReliableAt != null;

  /// Processes a heading sample. [accuracyDegrees] is an optional sensor
  /// uncertainty estimate; null means the source did not provide one.
  double? update(
    double rawHeading, {
    double? accuracyDegrees,
    DateTime? timestamp,
  }) {
    if (!rawHeading.isFinite) return _hold(timestamp ?? DateTime.now());
    final now = timestamp ?? DateTime.now();
    final accuracy = accuracyDegrees;

    if (accuracy != null &&
        (!accuracy.isFinite ||
            accuracy < 0 ||
            accuracy > maximumAccuracyDegrees)) {
      return _hold(now);
    }

    final sample = _normalize(rawHeading);
    if (_heading == null || _lastAcceptedAt == null) {
      _heading = sample;
      _lastAcceptedAt = now;
      _lastReliableAt = now;
      return sample;
    }

    final elapsed = now.difference(_lastAcceptedAt!).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsed <= 0) return _heading;

    final alpha = 1 - math.exp(-elapsed / timeConstantSeconds);
    final weight = accuracy == null
        ? 1.0
        : (1.0 - ((accuracy - minimumAccuracyDegrees) /
                (maximumAccuracyDegrees - minimumAccuracyDegrees)))
            .clamp(0.15, 1.0)
            .toDouble();
    final gain = (alpha * weight).clamp(0.01, 1.0).toDouble();

    final delta = _wrap180(sample - _heading!);
    final next = _normalize(_heading! + gain * delta);

    _heading = next;
    _lastAcceptedAt = now;
    _lastReliableAt = now;
    return next;
  }

  double? _hold(DateTime now) {
    final last = _lastReliableAt;
    if (_heading == null || last == null) return null;
    if (now.difference(last) <= unreliableHold) return _heading;
    return null;
  }

  void reset() {
    _heading = null;
    _lastAcceptedAt = null;
    _lastReliableAt = null;
  }

  static double normalize(double angle) => _normalize(angle);

  static double wrap180(double angle) => _wrap180(angle);

  static double _normalize(double angle) {
    final value = angle % 360;
    return value < 0 ? value + 360 : value;
  }

  static double _wrap180(double angle) {
    var value = angle % 360;
    if (value > 180) value -= 360;
    if (value <= -180) value += 360;
    return value;
  }
}
