import 'package:flutter_test/flutter_test.dart';
import 'package:droobi/services/navigation/heading_estimator.dart';

void main() {
  group('HeadingEstimator', () {
    test('handles 359 to 1 degree wraparound', () {
      final estimator = HeadingEstimator(timeConstantSeconds: 0.01);
      final t0 = DateTime.utc(2026, 1, 1);
      estimator.update(359, timestamp: t0);
      final result = estimator.update(1, timestamp: t0.add(const Duration(seconds: 1)));
      expect(result, isNotNull);
      expect(result! < 5 || result > 355, isTrue);
    });

    test('holds last heading briefly when accuracy is poor', () {
      final estimator = HeadingEstimator();
      final t0 = DateTime.utc(2026, 1, 1);
      estimator.update(90, timestamp: t0);
      expect(
        estimator.update(180, accuracyDegrees: 80, timestamp: t0.add(const Duration(seconds: 1))),
        90,
      );
      expect(
        estimator.update(180, accuracyDegrees: 80, timestamp: t0.add(const Duration(seconds: 5))),
        isNull,
      );
    });

    test('tracks a deliberate rotation quickly', () {
      final estimator = HeadingEstimator();
      final t0 = DateTime.utc(2026, 1, 1);
      estimator.update(0, accuracyDegrees: 30, timestamp: t0);
      double? heading;
      for (var ms = 20; ms <= 500; ms += 20) {
        heading = estimator.update(90,
            accuracyDegrees: 30, timestamp: t0.add(Duration(milliseconds: ms)));
      }
      // The jitter time constant alone (0.8 s at this accuracy) would only
      // reach about 42 degrees after 0.5 s.
      expect(heading!, greaterThan(70));
    });

    test('a one-sample spike barely moves the heading', () {
      final estimator = HeadingEstimator();
      final t0 = DateTime.utc(2026, 1, 1);
      for (var ms = 0; ms <= 1000; ms += 20) {
        estimator.update(0, accuracyDegrees: 15, timestamp: t0.add(Duration(milliseconds: ms)));
      }
      final spiked = estimator.update(90,
          accuracyDegrees: 15, timestamp: t0.add(const Duration(milliseconds: 1020)));
      expect(HeadingEstimator.wrap180(spiked!).abs(), lessThan(5));
      double? after;
      for (var ms = 1040; ms <= 1500; ms += 20) {
        after = estimator.update(0, accuracyDegrees: 15, timestamp: t0.add(Duration(milliseconds: ms)));
      }
      // Decays like before (about 1.3 deg left after 0.48 s).
      expect(HeadingEstimator.wrap180(after!).abs(), lessThan(2));
    });

    test('low accuracy slows jitter smoothing no more than medium accuracy', () {
      double after500(double accuracy) {
        final estimator = HeadingEstimator();
        final t0 = DateTime.utc(2026, 1, 1);
        estimator.update(0, accuracyDegrees: accuracy, timestamp: t0);
        double? heading;
        for (var ms = 20; ms <= 500; ms += 20) {
          heading = estimator.update(6,
              accuracyDegrees: accuracy, timestamp: t0.add(Duration(milliseconds: ms)));
        }
        return heading!;
      }
      expect(after500(45), closeTo(after500(30), 1e-9));
      expect(after500(15), greaterThan(after500(30)));
    });
  });
}
