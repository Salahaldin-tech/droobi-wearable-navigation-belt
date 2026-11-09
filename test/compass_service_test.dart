import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:droobi/services/navigation/compass_service.dart';

void main() {
  group('CompassService.getStableHeading', () {
    test('uses circular mean across the north boundary', () async {
      final service = CompassService(
        headingSource: Stream<double>.fromIterable(
          [359, 1, 359, 1, 0, 359, 1, 0],
        ),
      );

      final heading = await service.getStableHeading(
        minimumSamplingWindow: Duration.zero,
      );

      final distanceFromNorth = math.min(heading, 360 - heading);
      expect(distanceFromNorth, lessThan(1));
    });

    test('rejects readings with no stable circular direction', () async {
      final service = CompassService(
        headingSource: Stream<double>.fromIterable(
          [0, 90, 180, 270, 0, 90, 180, 270],
        ),
      );

      await expectLater(
        service.getStableHeading(
          minimumSamplingWindow: Duration.zero,
        ),
        throwsA(isA<CompassFailure>()),
      );
    });

    test('requires at least three samples', () async {
      final service = CompassService(
        headingSource: Stream<double>.fromIterable([10, 10]),
      );

      await expectLater(
        service.getStableHeading(sampleCount: 2),
        throwsArgumentError,
      );
    });
  });
}
