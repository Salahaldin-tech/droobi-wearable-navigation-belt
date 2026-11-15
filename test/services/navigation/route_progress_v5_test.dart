import 'dart:math' as math;

import 'package:droobi/core/geo/geo_math.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/route_result.dart';
import 'package:droobi/services/navigation/route_progress_service.dart';
import 'package:flutter_test/flutter_test.dart';

final _frame = LocalFrame(const LatLon(latitude: 32.41, longitude: 35.29));
LatLon _p(double east, double north) => _frame.toLatLon(east, north);

RouteResult _route(List<LatLon> points) =>
    RouteResult(polyline: points, distanceMeters: 0, durationSeconds: 0);

/// 40 m north, then 40 m east (right turn at (0, 40)).
RouteResult _lRoute() => _route([_p(0, 0), _p(0, 40), _p(40, 40)]);

void main() {
  group('Route matching', () {
    test('reports progress, remaining distance and next turn', () {
      final service = RouteProgressService();
      final target =
          service.getNextTarget(currentPosition: _p(0, 10), route: _lRoute());
      expect(target.progressMeters, closeTo(10, 0.2));
      expect(target.remainingMeters, closeTo(70, 0.3));
      expect(target.distanceToNextTurnMeters, closeTo(30, 0.3));
      expect(target.nextTurnAngleDegrees, closeTo(90, 1));
      expect(service.remainingRouteMeters, closeTo(70, 0.3));
    });

    test('route bearing follows the path, not GPS-to-target', () {
      final service = RouteProgressService();
      // 2 m right of a north-bound path: within the dead band.
      final target =
          service.getNextTarget(currentPosition: _p(2, 10), route: _lRoute());
      expect(GeoMath.wrap180(target.routeBearing!).abs(), lessThan(1));
      expect(GeoMath.wrap180(target.guidanceBearing!).abs(), lessThan(1));
      expect(target.crossTrackMeters, closeTo(2, 0.1));
    });

    test('steers back toward the path when clearly off it (bounded)', () {
      final service = RouteProgressService();
      final right =
          service.getNextTarget(currentPosition: _p(9, 10), route: _lRoute());
      final steer = GeoMath.wrap180(right.guidanceBearing!);
      expect(steer, lessThan(-5)); // Right of path → steer left.
      expect(steer, greaterThanOrEqualTo(-25.01));

      final service2 = RouteProgressService();
      final left =
          service2.getNextTarget(currentPosition: _p(-9, 10), route: _lRoute());
      expect(GeoMath.wrap180(left.guidanceBearing!), greaterThan(5));
    });

    test('does not rotate the cue early, switches within a few meters of turn',
        () {
      final service = RouteProgressService();
      final early =
          service.getNextTarget(currentPosition: _p(0, 34), route: _lRoute());
      expect(GeoMath.wrap180(early.routeBearing!).abs(), lessThan(1));
      expect(early.isNearTurn, isTrue);

      final atTurn =
          service.getNextTarget(currentPosition: _p(0, 38), route: _lRoute());
      expect(atTurn.routeBearing, closeTo(90, 1));
    });

    test('detects a curve drawn with many small vertices as one turn', () {
      // Quarter circle of radius 8 m with 2-degree-ish steps, as OSRM emits.
      final points = <LatLon>[_p(0, 0), _p(0, 30)];
      for (var deg = 6; deg <= 90; deg += 6) {
        final a = deg * math.pi / 180;
        points.add(_p(8 - 8 * math.cos(a), 30 + 8 * math.sin(a)));
      }
      points.add(_p(40, 38));
      final service = RouteProgressService();
      final target =
          service.getNextTarget(currentPosition: _p(0, 5), route: _route(points));
      expect(target.distanceToNextTurnMeters, isNotNull);
      expect(target.distanceToNextTurnMeters!, inInclusiveRange(25, 40));
      expect(target.nextTurnAngleDegrees!, greaterThan(35));
    });

    test('does not get captured by a parallel return leg', () {
      // Hairpin: 60 m north, 6 m east, 60 m south.
      final route = _route([_p(0, 0), _p(0, 60), _p(6, 60), _p(6, 0)]);
      final service = RouteProgressService();
      for (var n = 0.0; n <= 20; n += 2) {
        service.getNextTarget(currentPosition: _p(0, n), route: route);
      }
      // A noisy fix that is closer to the return leg.
      final target =
          service.getNextTarget(currentPosition: _p(4, 22), route: route);
      expect(target.progressMeters, lessThan(40));
      expect(GeoMath.wrap180(target.routeBearing!).abs(), lessThan(1));
    });

    test('catches up after a GPS gap on a dense polyline', () {
      final points = [for (var n = 0; n <= 200; n++) _p(0, n.toDouble())];
      final route = _route(points);
      final service = RouteProgressService();
      service.getNextTarget(currentPosition: _p(0, 0), route: route);
      final target =
          service.getNextTarget(currentPosition: _p(0, 120), route: route);
      expect(target.distanceFromRouteMeters, lessThan(0.5));
      expect(target.progressMeters, closeTo(120, 0.5));
    });

    test('caches geometry: repeated calls are fast on long routes', () {
      final points = [for (var n = 0; n <= 2000; n++) _p(0, n * 0.5)];
      final route = _route(points);
      final service = RouteProgressService();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        service.getNextTarget(currentPosition: _p(0.5, i * 0.9), route: route);
      }
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
