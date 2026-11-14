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
  });
}
