import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// One compass event, preserving the plugin's accuracy metadata.
///
/// Android headings are magnetic azimuths; iOS headings are trueHeading.
/// Android accuracy codes are 15 (high), 30 (medium), 45 (low), and null
/// when the native sensor reports unreliable or has not reported accuracy.
@immutable
class CompassSample {
  const CompassSample({
    required this.rawHeadingDegrees,
    required this.accuracyDegrees,
    required this.timestamp,
  });

  final double rawHeadingDegrees;
  final double? accuracyDegrees;
  final DateTime timestamp;
}

class CompassService {
  CompassService({
    Stream<double>? headingSource,
    double Function()? declinationProvider,
    Stream<CompassSample>? sampleSource,
    TargetPlatform? platform,
  })  : _headingSource = headingSource,
        _declinationProvider = declinationProvider,
        _sampleSource = sampleSource,
        _platform = platform;

  // Keep the legacy API unchanged for standard navigation.
  final Stream<double>? _headingSource;
  final double Function()? _declinationProvider;
  final Stream<CompassSample>? _sampleSource;
  final TargetPlatform? _platform;

  /// Emits readings with their native accuracy and capture time.
  ///
  /// This stream intentionally does not apply declination. Its consumer must
  /// convert magnetic Android heading to true north exactly once.
  Stream<CompassSample> get sampleStream {
    final source = _sampleSource;
    if (source != null) return source;

    final platform = _platform ?? defaultTargetPlatform;
    final events = FlutterCompass.events;
    if (events == null) return const Stream<CompassSample>.empty();

    return events
        .where((event) =>
            event.heading != null && event.heading!.isFinite)
        .where((event) =>
            !(platform == TargetPlatform.iOS && event.heading! < 0))
        .map((event) => CompassSample(
              rawHeadingDegrees: _normalize(event.heading!),
              accuracyDegrees: event.accuracy,
              timestamp: DateTime.now(),
            ));
  }

  Stream<double> get headingStream {
    final source = _headingSource;
    if (source != null) {
      return source.map(_applyDeclination);
    }

    final events = FlutterCompass.events;
    if (events == null) {
      return const Stream.empty();
    }

    return events
        .map((event) => event.heading)
        .where((heading) => heading != null)
        .map((heading) => _applyDeclination(heading!));
  }

  Future<double> getCurrentHeading() async {
    try {
      return await headingStream.first.timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException {
      throw const CompassFailure(
        'Timed out while waiting for a phone compass reading.',
      );
    } on StateError {
      throw const CompassFailure(
        'Compass sensor is not available on this device.',
      );
    }
  }

  /// Collects stable readings while preserving and validating sensor accuracy.
  ///
  /// The returned accuracy is the worst (largest) uncertainty among accepted
  /// samples, so the startup estimate never claims better accuracy than the
  /// readings that contributed to it.
  Future<CompassSample> getStableCompassSample({
    int sampleCount = 8,
    Duration minimumSamplingWindow = const Duration(milliseconds: 400),
    Duration timeout = const Duration(seconds: 5),
    double minimumResultantVector = 0.80,
    double maximumAccuracyDegrees = 45,
    bool allowUnknownAccuracyFallback = false,
    double unknownAccuracyMinimumResultantVector = 0.90,
  }) async {
    if (sampleCount < 3) {
      throw ArgumentError.value(
        sampleCount,
        'sampleCount',
        'At least three compass samples are required.',
      );
    }

    final startedAt = DateTime.now();
    final samples = <CompassSample>[];
    // Android reports no accuracy until the sensor's first accuracy callback;
    // some devices never send one. Keep those readings for a strict fallback.
    final unknownAccuracySamples = <CompassSample>[];
    final completed = Completer<void>();
    StreamSubscription<CompassSample>? subscription;
    final timeoutTimer = Timer(timeout, () {
      if (!completed.isCompleted) {
        completed.completeError(TimeoutException(
          'Compass sampling timed out.',
          timeout,
        ));
      }
    });

    try {
      subscription = sampleStream.listen(
        (sample) {
          final accuracy = sample.accuracyDegrees;
          if (accuracy == null && sample.rawHeadingDegrees.isFinite) {
            unknownAccuracySamples.add(sample);
            return;
          }
          if (accuracy == null ||
              !accuracy.isFinite ||
              accuracy < 0 ||
              accuracy > maximumAccuracyDegrees ||
              !sample.rawHeadingDegrees.isFinite) {
            return;
          }

          samples.add(sample);
          final windowElapsed =
              DateTime.now().difference(startedAt) >= minimumSamplingWindow;
          if (samples.length >= sampleCount &&
              windowElapsed &&
              !completed.isCompleted) {
            completed.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
        onDone: () {
          if (!completed.isCompleted) {
            completed.completeError(
              StateError('Compass stream ended before sampling completed.'),
            );
          }
        },
      );

      await completed.future;
    } on TimeoutException {
      if (allowUnknownAccuracyFallback &&
          samples.length + unknownAccuracySamples.length >= sampleCount) {
        final pool = <CompassSample>[...samples, ...unknownAccuracySamples];
        final fallback = _circularSummary(pool);
        if (fallback != null &&
            fallback.$2 >= unknownAccuracyMinimumResultantVector) {
          return CompassSample(
            rawHeadingDegrees: fallback.$1,
            // Unknown: the consumer must treat this as degraded.
            accuracyDegrees: null,
            timestamp: pool
                .map((sample) => sample.timestamp)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
        }
      }
      throw const CompassFailure(
        'Could not collect enough accurate compass readings. Check the phone '
        'compass and keep the phone steady before starting campus navigation.',
      );
    } on StateError {
      throw const CompassFailure(
        'Compass sensor is not available on this device.',
      );
    } finally {
      timeoutTimer.cancel();
      await subscription?.cancel();
    }

    final sinSum = samples.fold<double>(
      0,
      (sum, sample) =>
          sum + math.sin(sample.rawHeadingDegrees * math.pi / 180.0),
    );
    final cosSum = samples.fold<double>(
      0,
      (sum, sample) =>
          sum + math.cos(sample.rawHeadingDegrees * math.pi / 180.0),
    );
    final resultantVector =
        math.sqrt(sinSum * sinSum + cosSum * cosSum) / samples.length;

    if (!resultantVector.isFinite ||
        resultantVector < minimumResultantVector) {
      throw const CompassFailure(
        'The phone compass is unstable. Hold the phone steady and try again.',
      );
    }

    var mean = math.atan2(sinSum, cosSum) * 180.0 / math.pi;
    if (mean < 0) mean += 360.0;

    final worstAccuracy = samples
        .map((sample) => sample.accuracyDegrees!)
        .reduce((a, b) => a > b ? a : b);
    final latestTimestamp = samples
        .map((sample) => sample.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return CompassSample(
      rawHeadingDegrees: _normalize(mean),
      accuracyDegrees: worstAccuracy,
      timestamp: latestTimestamp,
    );
  }

  /// Collects multiple readings before navigation publishes its first cue.
  ///
  /// Circular averaging handles the 359°/0° boundary correctly. The minimum
  /// sampling window avoids treating a burst of immediately emitted events as
  /// a meaningful stability check.
  Future<double> getStableHeading({
    int sampleCount = 8,
    Duration minimumSamplingWindow = const Duration(milliseconds: 400),
    Duration timeout = const Duration(seconds: 5),
    double minimumResultantVector = 0.80,
  }) async {
    if (sampleCount < 3) {
      throw ArgumentError.value(
        sampleCount,
        'sampleCount',
        'At least three compass samples are required.',
      );
    }

    final startedAt = DateTime.now();
    final samples = <double>[];
    final completed = Completer<void>();
    StreamSubscription<double>? subscription;
    final timeoutTimer = Timer(timeout, () {
      if (!completed.isCompleted) {
        completed.completeError(TimeoutException(
          'Compass sampling timed out.',
          timeout,
        ));
      }
    });

    try {
      subscription = headingStream.listen(
        (heading) {
          samples.add(_normalize(heading));
          final windowElapsed =
              DateTime.now().difference(startedAt) >= minimumSamplingWindow;
          if (samples.length >= sampleCount &&
              windowElapsed &&
              !completed.isCompleted) {
            completed.complete();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completed.isCompleted) {
            completed.completeError(error, stackTrace);
          }
        },
        onDone: () {
          if (!completed.isCompleted) {
            completed.completeError(
              StateError('Compass stream ended before sampling completed.'),
            );
          }
        },
      );

      await completed.future;
    } on TimeoutException {
      throw const CompassFailure(
        'Could not collect enough compass readings to establish a stable '
        'initial direction. Keep the phone steady and try again.',
      );
    } on StateError {
      throw const CompassFailure(
        'Compass sensor is not available on this device.',
      );
    } finally {
      timeoutTimer.cancel();
      await subscription?.cancel();
    }

    final sinSum = samples.fold<double>(
      0,
      (sum, value) => sum + math.sin(value * math.pi / 180.0),
    );
    final cosSum = samples.fold<double>(
      0,
      (sum, value) => sum + math.cos(value * math.pi / 180.0),
    );
    final resultantVector =
        math.sqrt(sinSum * sinSum + cosSum * cosSum) / samples.length;

    if (!resultantVector.isFinite ||
        resultantVector < minimumResultantVector) {
      throw const CompassFailure(
        'The phone compass is unstable. Hold the phone steady and wait for '
        'the direction to stabilize before starting navigation.',
      );
    }

    var mean = math.atan2(sinSum, cosSum) * 180.0 / math.pi;
    if (mean < 0) mean += 360.0;
    return _normalize(mean);
  }

  /// (circular mean, mean resultant length) or null when empty.
  static (double, double)? _circularSummary(List<CompassSample> samples) {
    if (samples.isEmpty) return null;
    var sinSum = 0.0;
    var cosSum = 0.0;
    for (final sample in samples) {
      sinSum += math.sin(sample.rawHeadingDegrees * math.pi / 180.0);
      cosSum += math.cos(sample.rawHeadingDegrees * math.pi / 180.0);
    }
    final resultant =
        math.sqrt(sinSum * sinSum + cosSum * cosSum) / samples.length;
    var mean = math.atan2(sinSum, cosSum) * 180.0 / math.pi;
    if (mean < 0) mean += 360.0;
    return (_normalize(mean), resultant);
  }

  double _applyDeclination(double magneticHeading) {
    // The legacy path remains unchanged; the injected provider is responsible
    // for being platform-aware. The new sample path corrects explicitly.
    final correction = _declinationProvider?.call() ?? 0.0;
    return _normalize(magneticHeading + correction);
  }

  static double _normalize(double heading) {
    var normalized = heading % 360;
    if (normalized < 0) normalized += 360;
    return normalized;
  }
}

class CompassFailure implements Exception {
  const CompassFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
