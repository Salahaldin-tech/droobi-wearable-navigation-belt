import 'dart:convert';

import 'package:droobi/models/campus_destination.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/routing/osrm_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _origin =
    LatLon(latitude: 32.40552263782652, longitude: 35.342175006237284);

void main() {
  test('the five surveyed destinations use the exact supplied coordinates',
      () {
    const expected = {
      'Faculty of Medicine': [32.40717398179162, 35.34498148187609],
      'Faculty of Engineering': [32.40830854009759, 35.345596474631094],
      'Faculty of Arts and Education': [32.408006935848874, 35.34456342369225],
      'Gate 1': [32.40552263782652, 35.342175006237284],
      'Cafeteria': [32.407057851627115, 35.34257998109297],
    };
    expected.forEach((name, coordinates) {
      final destination = campusDestinationByName(name);
      expect(destination, isNotNull, reason: name);
      expect(destination!.position.latitude, coordinates[0], reason: name);
      expect(destination.position.longitude, coordinates[1], reason: name);
    });
  });

  test('ids, names and coordinates are all unique', () {
    final ids = campusDestinations.map((d) => d.id).toList();
    final names = campusDestinations.map((d) => d.name).toList();
    final points = campusDestinations
        .map((d) => '${d.position.latitude},${d.position.longitude}')
        .toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(names.toSet(), hasLength(names.length));
    expect(points.toSet(), hasLength(points.length));
  });

  test('unknown cards are not navigable', () {
    expect(campusDestinationByName('Faculty of Law'), isNull);
  });

  test('Engineering and Arts produce distinct OSRM requests', () async {
    final requestedPaths = <String, String>{};
    for (final name in ['Faculty of Engineering',
        'Faculty of Arts and Education']) {
      final destination = campusDestinationByName(name)!.position;
      final service = OsrmRoutingService(
        baseUrl: 'http://campus.test:5001',
        httpClient: MockClient((request) async {
          requestedPaths[name] = request.url.path;
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 1.0,
                  'duration': 1.0,
                  'geometry': {
                    'type': 'LineString',
                    'coordinates': [
                      [_origin.longitude, _origin.latitude],
                      [destination.longitude, destination.latitude],
                    ],
                  },
                },
              ],
              'waypoints': [
                {
                  'distance': 0.0,
                  'location': [_origin.longitude, _origin.latitude],
                },
                {
                  'distance': 0.0,
                  'location': [destination.longitude, destination.latitude],
                },
              ],
            }),
            200,
          );
        }),
      );
      await service.computeRoute(origin: _origin, destination: destination);
    }

    expect(requestedPaths['Faculty of Engineering'],
        '/route/v1/foot/35.342175006237284,32.40552263782652;'
        '35.345596474631094,32.40830854009759');
    expect(requestedPaths['Faculty of Arts and Education'],
        '/route/v1/foot/35.342175006237284,32.40552263782652;'
        '35.34456342369225,32.408006935848874');
  });
}
