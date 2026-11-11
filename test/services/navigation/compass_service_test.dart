import 'package:droobi/services/navigation/compass_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompassService', () {
    test('collects at least 12 stable samples over one second', () async {
      final compass = CompassService(
        headingSource: Stream<double>.periodic(
          const Duration(milliseconds: 100),
          (_) => 359.0,
        ).take(12),
      );

      final heading = await compass.getStableHeading();

      expect(heading, closeTo(359.0, 0.1));
    });

    test('uses WMM2025 east-positive declination', () {
      final compass = CompassService();

      // NOAA WMM2025 reference point: 0°N, 120°E at epoch 2025.0.
      final declination = compass.getDeclinationDegrees(
        latitude: 0,
        longitude: 120,
        date: DateTime.utc(2025, 1, 1),
      );

      expect(declination, closeTo(-0.16, 0.25));
    });
  });
}
