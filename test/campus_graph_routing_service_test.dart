import 'package:flutter_test/flutter_test.dart';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/routing/campus_graph_routing_service.dart';
import 'package:droobi/services/routing/routing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusGraphRoutingService V3', () {
    test('loads the latest GeoPackage export and reports its coverage', () async {
      final service = CampusGraphRoutingService();
      final diagnostics = await service.diagnostics();

      expect(diagnostics.nodeCount, 28);
      expect(diagnostics.edgeCount, 20);
      expect(diagnostics.connectedComponents, 3);
      expect(diagnostics.allEdgesFieldVerified, isFalse);
      expect(diagnostics.warnings, isNotEmpty);
    });

    test('routes from Gate 3 to Cafeteria door C1 on the mapped network',
        () async {
      final service = CampusGraphRoutingService();
      const gateThree = LatLon(
        latitude: 32.407343612351234,
        longitude: 35.34132248882196,
      );
      const cafeteriaC1 = LatLon(
        latitude: 32.40702199291816,
        longitude: 35.342165855390974,
      );

      final route = await service.computeRoute(
        origin: gateThree,
        destination: cafeteriaC1,
      );

      expect(route.polyline.length, greaterThan(2));
      expect(route.distanceMeters, greaterThan(0));
      expect(route.polyline.first.latitude, closeTo(gateThree.latitude, 0.00001));
      expect(route.polyline.last.latitude,
          closeTo(cafeteriaC1.latitude, 0.00001));
    });

    test('routes from Gate 3 to the IT entrance across connected QGIS edges',
        () async {
      final service = CampusGraphRoutingService();
      const gateThree = LatLon(
        latitude: 32.407343612351234,
        longitude: 35.34132248882196,
      );
      const itEntrance = LatLon(
        latitude: 32.406762881757636,
        longitude: 35.34341922867782,
      );

      final route = await service.computeRoute(
        origin: gateThree,
        destination: itEntrance,
      );

      expect(route.polyline.length, greaterThan(10));
      expect(route.distanceMeters, greaterThan(0));
    });

    test('respects one-way QGIS edges and rejects reverse Gate 3 routing',
        () async {
      final service = CampusGraphRoutingService();
      const cafeteriaC1 = LatLon(
        latitude: 32.40702199291816,
        longitude: 35.342165855390974,
      );
      const gateThree = LatLon(
        latitude: 32.407343612351234,
        longitude: 35.34132248882196,
      );

      await expectLater(
        service.computeRoute(
          origin: cafeteriaC1,
          destination: gateThree,
        ),
        throwsA(
          isA<RoutingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('GRAPH_CONNECTIVITY'),
          ),
        ),
      );
    });

    test('routes from Gate 1 using the new ED08 path', () async {
      final service = CampusGraphRoutingService();
      const gateOne = LatLon(
        latitude: 32.4055253160422,
        longitude: 35.342239729578615,
      );
      const itEntrance = LatLon(
        latitude: 32.406762881757636,
        longitude: 35.34341922867782,
      );

      final route = await service.computeRoute(
        origin: gateOne,
        destination: itEntrance,
      );

      expect(route.polyline.length, greaterThan(2));
      expect(route.distanceMeters, greaterThan(0));
    });

    test('rejects GPS outside mapped coverage without adding a connector',
        () async {
      final service = CampusGraphRoutingService();
      const outsideCampus = LatLon(latitude: 32.5, longitude: 35.5);
      const itEntrance = LatLon(
        latitude: 32.406762881757636,
        longitude: 35.34341922867782,
      );

      await expectLater(
        service.computeRoute(
          origin: outsideCampus,
          destination: itEntrance,
        ),
        throwsA(
          isA<RoutingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('MAP_MATCH_DISTANCE'),
          ),
        ),
      );
    });

    test('routes to the connected mapped University destinations', () async {
      final service = CampusGraphRoutingService();
      const gateThree = LatLon(
        latitude: 32.407343612351234,
        longitude: 35.34132248882196,
      );
      const destinations = <LatLon>[
        // Arts Faculty AR1.
        LatLon(latitude: 32.40798931227382, longitude: 35.34459590815139),
        // Engineering E1.
        LatLon(latitude: 32.40830546890924, longitude: 35.34564986940725),
        // Gate 1.
        LatLon(latitude: 32.4055253160422, longitude: 35.342239729578615),
        // Gate 2.
        LatLon(latitude: 32.40616771233306, longitude: 35.34154870278381),
        // Allied Medical Sciences entrance AMS_A.
        LatLon(latitude: 32.4071651284486, longitude: 35.34412952070336),
      ];

      for (final destination in destinations) {
        final route = await service.computeRoute(
          origin: gateThree,
          destination: destination,
        );
        expect(route.polyline.length, greaterThan(2));
        expect(route.distanceMeters, greaterThan(0));
      }
    });

    test('does not invent connections to isolated QGIS destinations', () async {
      final service = CampusGraphRoutingService();
      const gateThree = LatLon(
        latitude: 32.407343612351234,
        longitude: 35.34132248882196,
      );
      const isolatedDestinations = <LatLon>[
        // MED, connected only to the isolated ED011 fragment.
        LatLon(latitude: 32.407006828855685, longitude: 35.34492687872492),
        // AMS_B, connected only to the isolated ED012 fragment.
        LatLon(latitude: 32.40649595534037, longitude: 35.34454701758947),
      ];

      for (final destination in isolatedDestinations) {
        await expectLater(
          service.computeRoute(
            origin: gateThree,
            destination: destination,
          ),
          throwsA(
            isA<RoutingFailure>().having(
              (failure) => failure.message,
              'message',
              contains('GRAPH_CONNECTIVITY'),
            ),
          ),
        );
      }
    });
  });
}
