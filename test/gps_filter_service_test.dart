import 'package:flutter_test/flutter_test.dart';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/location_fix.dart';
import 'package:droobi/services/location/gps_filter_service.dart';

void main() {
  group('GpsFilterService V3', () {
    final now = DateTime.utc(2026, 11, 11, 10);

    LocationFix fix({
      required double latitude,
      required DateTime timestamp,
      double accuracy = 5,
      double? speed,
      double? course,
      double? courseAccuracy,
    }) {
      return LocationFix(
        position: LatLon(latitude: latitude, longitude: 35),
        accuracyMeters: accuracy,
        timestamp: timestamp,
        speedMetersPerSecond: speed,
        courseDegrees: course,
        courseAccuracyDegrees: courseAccuracy,
      );
    }

    test('rejects a stale GPS fix', () {
      final service = GpsFilterService(clock: () => now);

      final accepted = service.process(fix(
        latitude: 32,
        timestamp: now.subtract(const Duration(seconds: 20)),
      ));

      expect(accepted, isNull);
      expect(service.lastAcceptedFix, isNull);
    });

    test('rejects duplicate and out-of-order timestamps', () {
      final service = GpsFilterService(clock: () => now);
      final first = fix(latitude: 32, timestamp: now);
      expect(service.process(first), same(first));

      expect(
        service.process(fix(
          latitude: 32.000001,
          timestamp: now,
        )),
        isNull,
      );
      expect(
        service.process(fix(
          latitude: 32.000001,
          timestamp: now.subtract(const Duration(seconds: 1)),
        )),
        isNull,
      );
    });

    test('rejects an implausible GPS jump', () {
      final service = GpsFilterService(clock: () => now);
      service.process(fix(latitude: 32, timestamp: now));

      final jump = service.process(fix(
        latitude: 32.001,
        timestamp: now.add(const Duration(seconds: 1)),
      ));

      expect(jump, isNull);
      expect(service.lastAcceptedFix!.position.latitude, 32);
    });

    test('accepts and preserves valid speed and course metadata', () {
      final service = GpsFilterService(clock: () => now);
      final incoming = fix(
        latitude: 32,
        timestamp: now,
        speed: 1.4,
        course: 91,
        courseAccuracy: 8,
      );

      final accepted = service.process(incoming);

      expect(accepted!.speedMetersPerSecond, 1.4);
      expect(accepted.courseDegrees, 91);
      expect(accepted.courseAccuracyDegrees, 8);
      expect(accepted.hasReliableCourse, isTrue);
    });

    test('rejects GPS fixes with poor horizontal accuracy', () {
      final service = GpsFilterService(clock: () => now);
      expect(
        service.process(fix(
          latitude: 32,
          timestamp: now,
          accuracy: 40,
        )),
        isNull,
      );
    });
  });
}
