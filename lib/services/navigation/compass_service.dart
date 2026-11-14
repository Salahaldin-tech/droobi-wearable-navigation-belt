import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  CompassService({
    Stream<double>? headingSource,
    double Function()? declinationProvider,
  })  : _headingSource = headingSource,
        _declinationProvider = declinationProvider;

  // Injectable source keeps compass sampling deterministic in unit tests.
  final Stream<double>? _headingSource;
  final double Function()? _declinationProvider;

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
          samples.add(_normalizeHeading(heading));
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
    return _normalizeHeading(mean);
  }

  double _applyDeclination(double magneticHeading) {
    // Android flutter_compass reports magnetic azimuth. iOS reports trueHeading.
    // Do not apply Android declination to iOS a second time.
    final correction = _declinationProvider?.call() ?? 0.0;
    return _normalizeHeading(magneticHeading + correction);
  }

  double _normalizeHeading(double heading) {
    var normalized = heading % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    return normalized;
  }
}

class CompassFailure implements Exception {
  const CompassFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
