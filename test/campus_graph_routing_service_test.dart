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
  });
}
