import 'package:flutter_test/flutter_test.dart';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/routing/campus_graph_routing_service.dart';
import 'package:droobi/services/routing/routing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusGraphRoutingService', () {
    test('calculates a route from Gate 3 to the QGIS cafeteria entrance', () async {
      final service = CampusGraphRoutingService();
      const origin = LatLon(
        latitude: 32.407314121188996,
        longitude: 35.341274227489635,
      );
      const destination = LatLon(
        latitude: 32.40699249396461,
        longitude: 35.34216978223841,
      );

      final route = await service.computeRoute(
        origin: origin,
        destination: destination,
      );

      expect(route.polyline.length, greaterThan(2));
      expect(route.polyline.first.latitude, origin.latitude);
      expect(route.polyline.first.longitude, origin.longitude);
      expect(route.distanceMeters, greaterThan(0));
    });

    test('rejects a GPS position outside the QGIS campus map coverage', () async {
      final service = CampusGraphRoutingService();
      const outsideCampus = LatLon(latitude: 32.5, longitude: 35.5);
      const destination = LatLon(
        latitude: 32.40699249396461,
        longitude: 35.34216978223841,
      );

      await expectLater(
        service.computeRoute(
          origin: outsideCampus,
          destination: destination,
        ),
        throwsA(isA<RoutingFailure>()),
      );
    });

    test('routes in reverse across every QGIS edge including ED006', () async {
      final service = CampusGraphRoutingService();
      const engineeringEntrance = LatLon(
        latitude: 32.408136594,
        longitude: 35.345562575,
      );
      const gateThree = LatLon(
        latitude: 32.407343613,
        longitude: 35.341322488,
      );

      final route = await service.computeRoute(
        origin: engineeringEntrance,
        destination: gateThree,
      );

      expect(route.polyline.length, greaterThan(2));
      expect(route.polyline.first.latitude, engineeringEntrance.latitude);
      expect(route.polyline.last.latitude, gateThree.latitude);
      expect(route.distanceMeters, greaterThan(0));
    });

    test('reports Gate 1 as outside current mapped path coverage', () async {
      final service = CampusGraphRoutingService();
      const gateOne = LatLon(
        latitude: 32.405525317,
        longitude: 35.342239729,
      );
      const gateThree = LatLon(
        latitude: 32.407343613,
        longitude: 35.341322488,
      );

      await expectLater(
        service.computeRoute(origin: gateOne, destination: gateThree),
        throwsA(
          isA<RoutingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('GPS_SNAP_ORIGIN'),
          ),
        ),
      );
    });
  });
}
