import 'dart:math' as math;

import 'package:droobi/models/navigation_direction.dart';
import 'package:droobi/services/navigation/heading_estimator.dart';
import 'package:droobi/services/navigation/relative_direction_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end compass pipeline simulation: phone heading samples at 50 Hz
/// with Gaussian sensor noise go through [HeadingEstimator] and
/// [RelativeDirectionEngine] exactly as NavigationService chains them
/// (relative angle = route bearing - smoothed heading; route bearing 0).
class _Run {
  _Run({this.accuracy = 30, this.noiseDegrees = 3, int seed = 7})
      : _random = math.Random(seed);

  final double? accuracy;
  final double noiseDegrees;
  final math.Random _random;
  final estimator = HeadingEstimator();
  final engine = RelativeDirectionEngine();
  final t0 = DateTime.utc(2026, 1, 1);
  final changes = <(int, NavigationDirection)>[];
  final headings = <double>[];
  NavigationDirection? direction;
  int ms = 0;

  double _gaussian() {
    final u1 = 1 - _random.nextDouble();
    final u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// Feeds samples until [untilMs]; [phone] gives the true phone heading.
  void run(int untilMs, double Function(int ms) phone) {
    for (; ms <= untilMs; ms += 20) {
      final now = t0.add(Duration(milliseconds: ms));
      final raw = HeadingEstimator.normalize(phone(ms) + noiseDegrees * _gaussian());
      final heading = estimator.update(raw, accuracyDegrees: accuracy, timestamp: now);
      if (heading == null) continue;
      headings.add(heading);
      final cue = engine.update(-heading, timestamp: now);
      if (cue != direction) {
        if (direction != null) changes.add((ms, cue));
        direction = cue;
      }
    }
  }

  /// Milliseconds from [fromMs] until the cue first became [cue].
  int? latency(int fromMs, NavigationDirection cue) {
    for (final (at, value) in changes) {
      if (at >= fromMs && value == cue) return at - fromMs;
    }
    return null;
  }
}

/// Phone held at [from] until [startMs], then rotated to [to] in [durationMs].
double Function(int) _rotate(double from, double to, int startMs, int durationMs) =>
    (ms) {
      if (ms <= startMs) return from;
      final t = math.min(1.0, (ms - startMs) / durationMs);
      return from + (to - from) * t;
    };

void main() {
  group('compass responsiveness', () {
    for (final accuracy in <double?>[15, 30, 45]) {
      test('90 degree phone rotation updates the cue quickly (accuracy $accuracy)',
          () {
        final run = _Run(accuracy: accuracy)
          ..run(6000, _rotate(0, 90, 2000, 300));
        final latency = run.latency(2000, NavigationDirection.left);
        // ignore: avoid_print
        print('accuracy $accuracy: 90 deg rotation -> left after $latency ms');
        expect(latency, isNotNull);
        // Previously 1700 / 2160 ms, and no change within 4 s at accuracy 45.
        expect(latency!, lessThanOrEqualTo(1400));
        // No intermediate or overshoot cue on the way.
        expect(run.changes.map((c) => c.$2), [NavigationDirection.left]);
      });
    }

    test('45 degree phone rotation updates the cue quickly', () {
      final run = _Run()..run(5000, _rotate(0, 45, 2000, 250));
      final latency = run.latency(2000, NavigationDirection.forwardLeft);
      // ignore: avoid_print
      print('accuracy 30: 45 deg rotation -> forwardLeft after $latency ms');
      expect(latency, isNotNull);
      // Bounded by the unchanged 500 ms one-sector confirmation (was 1580 ms).
      expect(latency!, lessThanOrEqualTo(1150));
    });

    test('180 degree turn-around reaches back without wrong cues', () {
      final run = _Run()..run(7000, _rotate(0, 180, 2000, 600));
      final latency = run.latency(2000, NavigationDirection.back);
      // ignore: avoid_print
      print('accuracy 30: 180 deg rotation -> back after $latency ms');
      expect(latency, isNotNull);
      // Previously 2980 ms.
      expect(latency!, lessThanOrEqualTo(1400));
      expect(run.changes.last.$2, NavigationDirection.back);
    });
  });

  group('compass stability', () {
    test('a still phone never changes the cue and the heading barely moves', () {
      for (final accuracy in <double?>[15, 30, 45]) {
        final run = _Run(accuracy: accuracy, noiseDegrees: 4)
          ..run(30000, (_) => 0);
        expect(run.changes, isEmpty, reason: 'accuracy $accuracy');
        final steady = run.headings.skip(50).map(HeadingEstimator.wrap180);
        final maxError = steady.map((h) => h.abs()).reduce(math.max);
        // ignore: avoid_print
        print('accuracy $accuracy: still phone max heading error '
            '${maxError.toStringAsFixed(2)} deg');
        expect(maxError, lessThan(6), reason: 'accuracy $accuracy');
      }
    });

    test('holding the phone close to a sector boundary does not flicker', () {
      // Relative angle about -20 deg: 2.5 deg inside the forward sector.
      final run = _Run(noiseDegrees: 4)..run(30000, (_) => 20);
      expect(run.changes, isEmpty);
    });

    test('a short magnetic spike does not change the cue', () {
      for (final spikeMs in [100, 200, 300]) {
        final run = _Run()
          ..run(8000, (ms) => ms >= 3000 && ms < 3000 + spikeMs ? 80 : 0);
        expect(run.changes, isEmpty, reason: '$spikeMs ms spike');
      }
    });
  });
}
