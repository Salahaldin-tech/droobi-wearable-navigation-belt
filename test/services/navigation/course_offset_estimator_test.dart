import 'package:flutter_test/flutter_test.dart';
import 'package:droobi/services/navigation/course_offset_estimator.dart';

void main() {
  test('learns a bounded phone-to-course offset', () {
    final estimator = CourseOffsetEstimator();
    for (var i = 0; i < 20; i++) {
      estimator.addSample(courseTrueDegrees: 20, phoneTrueHeadingDegrees: 0);
    }
    expect(estimator.offsetDegrees, closeTo(20, 1));
    expect(estimator.acceptedSamples, 20);
  });

  test('never trusts a single sample', () {
    final estimator = CourseOffsetEstimator();
    for (var i = 0; i < 4; i++) {
      estimator.addSample(courseTrueDegrees: 30, phoneTrueHeadingDegrees: 0);
    }
    expect(estimator.offsetDegrees, isNull);
    estimator.addSample(courseTrueDegrees: 30, phoneTrueHeadingDegrees: 0);
    expect(estimator.offsetDegrees, closeTo(30, 0.5));
  });

  test('does not publish an offset from inconsistent samples', () {
    final estimator = CourseOffsetEstimator();
    const offsets = [30.0, -30.0, 25.0, -25.0, 0.0, 30.0, -30.0];
    for (final offset in offsets) {
      estimator.addSample(courseTrueDegrees: offset, phoneTrueHeadingDegrees: 0);
    }
    expect(estimator.offsetDegrees, isNull);
  });

  test('handles wraparound and clamps to the maximum offset', () {
    final estimator = CourseOffsetEstimator();
    for (var i = 0; i < 10; i++) {
      estimator.addSample(courseTrueDegrees: 10, phoneTrueHeadingDegrees: 300);
    }
    // 10 - 300 = 70 → clamped to 35.
    expect(estimator.offsetDegrees, 35);
  });

  test('ignores outliers once calibrated', () {
    final estimator = CourseOffsetEstimator();
    for (var i = 0; i < 5; i++) {
      estimator.addSample(courseTrueDegrees: 10, phoneTrueHeadingDegrees: 0);
    }
    estimator.addSample(courseTrueDegrees: 180, phoneTrueHeadingDegrees: 0);
    expect(estimator.offsetDegrees, closeTo(10, 0.5));
  });
}
