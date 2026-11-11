import 'package:flutter_test/flutter_test.dart';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/route_result.dart';
import 'package:droobi/services/navigation/route_progress_service.dart';

void main() {
  group('RouteProgressService adaptive look-ahead', () {
    test('uses the shorter target when a turn is close', () {
      const route = RouteResult(
        polyline: [
          LatLon(latitude: 32.0, longitude: 35.0),
          LatLon(latitude: 32.0000449, longitude: 35.0),
          LatLon(latitude: 32.0000449, longitude: 35.0000449),
        ],
        distanceMeters: 10,
        durationSeconds: 10,
      );
      final service = RouteProgressService();

      final target = service.getNextTarget(
        currentPosition: const LatLon(latitude: 32.0, longitude: 35.0),
        route: route,
      );

      expect(target.distanceAheadMeters, closeTo(3.5, 0.25));
    });

    test('keeps the normal look-ahead on a straight path', () {
      const route = RouteResult(
        polyline: [
          LatLon(latitude: 32.0, longitude: 35.0),
          LatLon(latitude: 32.0000898, longitude: 35.0),
          LatLon(latitude: 32.0001796, longitude: 35.0),
        ],
        distanceMeters: 20,
        durationSeconds: 20,
      );
      final service = RouteProgressService();

      final target = service.getNextTarget(
        currentPosition: const LatLon(latitude: 32.0, longitude: 35.0),
        route: route,
      );

      expect(target.distanceAheadMeters, closeTo(7.5, 0.25));
    });
  });

  group('RouteProgressService distance-aware matching', () {
    final origin = const LatLon(latitude: 32, longitude: 35);

    List<LatLon> buildDenseRoute() {
      return List.generate(
        151,
        (index) => LatLon(
          latitude: 32 + index * 0.000008983,
          longitude: 35,
        ),
      );
    }

    test('uses speed and horizontal accuracy to expand the metre window', () {
      final route = RouteResult(
        polyline: buildDenseRoute(),
        distanceMeters: 150,
        durationSeconds: 150,
      );
      final service = RouteProgressService();

      service.getNextTarget(
        currentPosition: origin,
        route: route,
        lookAheadMeters: 0,
      );
      final atThirtyMetres = service.getNextTarget(
        currentPosition: route.polyline[30],
        route: route,
        lookAheadMeters: 0,
        speedMetersPerSecond: 2,
        horizontalAccuracyMeters: 5,
      );

      expect(atThirtyMetres.progressMeters, closeTo(30, 1.5));
      expect(atThirtyMetres.progressJumpDetected, isFalse);
    });

    test('does not move route progress backwards during GPS jitter', () {
      final route = RouteResult(
        polyline: buildDenseRoute(),
        distanceMeters: 150,
        durationSeconds: 150,
      );
      final service = RouteProgressService();

      service.getNextTarget(
        currentPosition: origin,
        route: route,
        lookAheadMeters: 0,
      );
      final forward = service.getNextTarget(
        currentPosition: route.polyline[20],
        route: route,
        lookAheadMeters: 0,
      );
      final smallRetreat = service.getNextTarget(
        currentPosition: route.polyline[15],
        route: route,
        lookAheadMeters: 0,
      );

      expect(forward.progressMeters, greaterThan(18));
      expect(
        smallRetreat.progressMeters,
        greaterThanOrEqualTo(forward.progressMeters),
      );
    });

    test('flags a large unexpected route-progress jump', () {
      final route = RouteResult(
        polyline: buildDenseRoute(),
        distanceMeters: 150,
        durationSeconds: 150,
      );
      final service = RouteProgressService();

      service.getNextTarget(
        currentPosition: origin,
        route: route,
        lookAheadMeters: 0,
      );
      final jump = service.getNextTarget(
        currentPosition: route.polyline[90],
        route: route,
        lookAheadMeters: 0,
        speedMetersPerSecond: 3,
        horizontalAccuracyMeters: 10,
      );

      expect(jump.progressJumpDetected, isTrue);
      expect(jump.progressMeters, lessThan(1));
    });
  });
}
