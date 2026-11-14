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
}
