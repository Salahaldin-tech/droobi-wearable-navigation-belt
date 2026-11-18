import 'dart:math' as math;

/// Converts noisy phone compass readings into a stable circular heading.
///
/// The estimator accepts degrees in [0, 360), tolerates wraparound, and
/// temporarily holds its last trusted value when the source is unreliable.
///
/// Smoothing is adaptive. Small differences between the reading and the
/// estimate (sensor jitter) are smoothed with [timeConstantSeconds], slowed
/// further for low sensor accuracy. A large, persistent difference (the user
/// deliberately rotating the phone) is tracked with the much shorter
/// [fastTimeConstantSeconds]. Persistence is measured on a short-term average
/// of the difference, so a single-sample spike does not trigger fast tracking.
class HeadingEstimator {
  HeadingEstimator({
    this.timeConstantSeconds = 0.4,
    this.fastTimeConstantSeconds = 0.1,
    this.adaptiveStartDegrees = 8,
    this.adaptiveFullDegrees = 25,
    this.innovationTimeConstantSeconds = 0.08,
    this.minimumAccuracyDegrees = 15,
    this.maximumAccuracyDegrees = 45,
    this.minimumAccuracyWeight = 0.5,
    this.minimumFastAccuracyWeight = 0.5,
    this.unreliableHold = const Duration(seconds: 3),
  }) {
    if (timeConstantSeconds <= 0) {
      throw ArgumentError.value(timeConstantSeconds, 'timeConstantSeconds');
    }
    if (fastTimeConstantSeconds <= 0) {
      throw ArgumentError.value(
        fastTimeConstantSeconds,
        'fastTimeConstantSeconds',
      );
    }
    if (adaptiveFullDegrees <= adaptiveStartDegrees) {
      throw ArgumentError.value(adaptiveFullDegrees, 'adaptiveFullDegrees');
    }
    if (innovationTimeConstantSeconds <= 0) {
      throw ArgumentError.value(
        innovationTimeConstantSeconds,
        'innovationTimeConstantSeconds',
      );
    }
  }

  /// Smoothing for sensor jitter while the phone is held still.
  final double timeConstantSeconds;

  /// Smoothing while the phone is clearly being rotated.
  final double fastTimeConstantSeconds;

  /// Below this persistent difference the reading is treated as jitter.
  final double adaptiveStartDegrees;

  /// At or above this persistent difference fast tracking is fully applied.
  final double adaptiveFullDegrees;

  /// Averaging of the reading-to-estimate difference used to tell a real
  /// rotation from a one-sample spike.
  final double innovationTimeConstantSeconds;

  final double minimumAccuracyDegrees;
  final double maximumAccuracyDegrees;

  /// Low accuracy may slow jitter smoothing by at most 1 / this factor.
  /// Accuracy describes calibration (a bias), which extra smoothing cannot
  /// remove; unbounded slowing only adds lag.
  final double minimumAccuracyWeight;

  /// Low accuracy may slow fast tracking by at most 1 / this factor.
  final double minimumFastAccuracyWeight;

  final Duration unreliableHold;

  double? _heading;
  double _innovation = 0;
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
      _innovation = 0;
      _lastAcceptedAt = now;
      _lastReliableAt = now;
      return sample;
    }

    final elapsed = now.difference(_lastAcceptedAt!).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (elapsed <= 0) return _heading;

    final weight = accuracy == null
        ? 1.0
        : (1.0 - ((accuracy - minimumAccuracyDegrees) /
                (maximumAccuracyDegrees - minimumAccuracyDegrees)))
            .clamp(minimumAccuracyWeight, 1.0)
            .toDouble();

    final delta = _wrap180(sample - _heading!);

    // The tracking speed is chosen from the averaged difference of the
    // samples BEFORE this one, so a single outlier is always smoothed slowly.
    // 0 = jitter (slow, accuracy-weighted), 1 = deliberate rotation (fast).
    final rotation = ((_innovation.abs() - adaptiveStartDegrees) /
            (adaptiveFullDegrees - adaptiveStartDegrees))
        .clamp(0.0, 1.0)
        .toDouble();
    final slowTau = timeConstantSeconds / weight;
    final fastTau = math.min(
      slowTau,
      fastTimeConstantSeconds / math.max(weight, minimumFastAccuracyWeight),
    );
    final tau = slowTau + (fastTau - slowTau) * rotation;

    final gain =
        (1 - math.exp(-elapsed / tau)).clamp(0.01, 1.0).toDouble();
    final next = _normalize(_heading! + gain * delta);

    // Short-term average of the difference, kept relative to the new
    // estimate: a real rotation keeps it large, a lone spike decays.
    final innovationAlpha =
        1 - math.exp(-elapsed / innovationTimeConstantSeconds);
    _innovation += innovationAlpha * (delta - _innovation);
    _innovation -= gain * delta;

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
    _innovation = 0;
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
