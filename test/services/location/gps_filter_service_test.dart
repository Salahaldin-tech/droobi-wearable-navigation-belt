import 'dart:math' as math;

import 'package:droobi/core/geo/geo_math.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/location_fix.dart';
import 'package:droobi/services/location/gps_filter_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = LatLon(latitude: 32.4100, longitude: 35.2900);
final _frame = LocalFrame(_origin);
final _t0 = DateTime.utc(2026, 11, 15, 10);

LocationFix _fix(double east, double north, int second,
    {double accuracy = 5, double? speed, double? course}) {
  return LocationFix(
    position: _frame.toLatLon(east, north),
    accuracyMeters: accuracy,
    timestamp: _t0.add(Duration(milliseconds: (second * 1000).round())),
    speedMetersPerSecond: speed,
    courseDegrees: course,
  );
}

void main() {
  group('GpsFilterService validation', () {
    test('accepts the first good fix and rejects poor accuracy', () {
      final filter = GpsFilterService();
      expect(filter.process(_fix(0, 0, 0, accuracy: 40)), isNull);
      expect(filter.lastRejectReason, GpsRejectReason.poorAccuracy);
      expect(filter.process(_fix(0, 0, 1)), isNotNull);
    });

    test('rejects null island, duplicate and out-of-order fixes', () {
      final filter = GpsFilterService();
      expect(
        filter.process(LocationFix(
          position: const LatLon(latitude: 0, longitude: 0),
          accuracyMeters: 5,
          timestamp: _t0,
        )),
        isNull,
      );
      expect(filter.process(_fix(0, 0, 5)), isNotNull);
      expect(filter.process(_fix(1, 0, 5)), isNull);
      expect(filter.process(_fix(1, 0, 4)), isNull);
      expect(filter.lastRejectReason, GpsRejectReason.outOfOrder);
    });
  });

  group('GpsFilterService plausibility', () {
    test('rejects a jump that requires an implausible walking speed', () {
      final filter = GpsFilterService();
      filter.process(_fix(0, 0, 0));
      expect(filter.process(_fix(60, 0, 1)), isNull);
      expect(filter.lastRejectReason, GpsRejectReason.implausibleJump);
    });

    test('accepts a large apparent move explained by reported accuracy', () {
      // 20 m in 2 s is 10 m/s raw, but both fixes claim ±15 m. A raw speed
      // check (V4) rejected this honest fix.
      final filter = GpsFilterService();
      filter.process(_fix(0, 0, 0, accuracy: 15));
      expect(filter.process(_fix(20, 0, 2, accuracy: 15)), isNotNull);
    });

    test('re-anchors when the anchor itself was the outlier', () {
      final filter = GpsFilterService();
      // Bad first fix 80 m away from the user's real position.
      filter.process(_fix(80, 0, 0));
      // Real, mutually consistent fixes around (0, 0).
      expect(filter.process(_fix(0, 0, 1)), isNull);
      expect(filter.process(_fix(0.5, 0.5, 2)), isNull);
      final recovered = filter.process(_fix(1, 1, 3));
      expect(recovered, isNotNull);
      expect(GeoMath.distance(recovered!.position, _frame.toLatLon(1, 1)),
          lessThan(0.5));
      expect(filter.consecutiveRejections, 0);
    });

    test('does not re-anchor on scattered outliers', () {
      final filter = GpsFilterService();
      filter.process(_fix(0, 0, 0));
      expect(filter.process(_fix(100, 0, 1)), isNull);
      expect(filter.process(_fix(-100, 0, 2)), isNull);
      expect(filter.process(_fix(0, 120, 3)), isNull);
      // A genuine nearby fix is still accepted against the original anchor.
      expect(filter.process(_fix(2, 2, 4)), isNotNull);
    });

    test('re-anchors after a long gap instead of gating against stale data', () {
      final filter = GpsFilterService();
      filter.process(_fix(0, 0, 0));
      final after = filter.process(_fix(60, 0, 20));
      expect(after, isNotNull);
      expect(GeoMath.distance(after!.position, _frame.toLatLon(60, 0)),
          lessThan(0.5));
    });
  });

  group('GpsFilterService smoothing', () {
    test('reduces jitter on a straight walk and estimates the course', () {
      final filter = GpsFilterService();
      final random = math.Random(7);
      var rawError = 0.0;
      var filteredError = 0.0;
      LocationFix? last;
      const n = 40;
      for (var i = 0; i < n; i++) {
        final trueNorth = i * 1.3;
        final noiseE = (random.nextDouble() - 0.5) * 6;
        final noiseN = (random.nextDouble() - 0.5) * 6;
        final raw = _fix(noiseE, trueNorth + noiseN, i, accuracy: 5);
        last = filter.process(raw);
        expect(last, isNotNull);
        if (i >= 10) {
          final truth = _frame.toLatLon(0, trueNorth);
          rawError += math.pow(GeoMath.distance(raw.position, truth), 2);
          filteredError += math.pow(GeoMath.distance(last!.position, truth), 2);
        }
      }
      expect(filteredError, lessThan(rawError * 0.75));
      expect(last!.courseDegrees, isNotNull);
      expect(GeoMath.wrap180(last.courseDegrees!).abs(), lessThan(15));
      expect(last.speedMetersPerSecond, closeTo(1.3, 0.4));
    });

    test('prefers the platform course when the receiver provides one', () {
      final filter = GpsFilterService();
      filter.process(_fix(0, 0, 0));
      final out = filter.process(_fix(0, 1.2, 1, speed: 1.2, course: 93));
      expect(out!.courseDegrees, 93);
    });

    test('reports no course while standing still', () {
      final filter = GpsFilterService();
      LocationFix? out;
      for (var i = 0; i < 10; i++) {
        out = filter.process(_fix(0, 0, i));
      }
      expect(out!.courseDegrees, isNull);
    });
  });
}
