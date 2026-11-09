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
}
