import 'dart:convert';
import 'dart:io';

import 'package:droobi/models/campus_destination.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/routing/osrm_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _origin = LatLon(latitude: 32.4055108, longitude: 35.3422267);

/// Exact entrance coordinates from the JOSM map, per Uni screen card.
const _expected = <String, List<double>>{
  'Allied Medical Sciences – AMS-A': [32.4071561, 35.3441229],
  'Allied Medical Sciences – AMS-B': [32.4065527, 35.3445109],
  'Faculty of Arts and Education': [32.4079498, 35.3445806],
  'Faculty of Business': [32.40637963603, 35.34252405033],
  'Dentistry – DEN-A': [32.40599410285, 35.34183807604],
  'Dentistry – DEN-B': [32.40578067275, 35.341416298],
  'Faculty of Engineering': [32.40828122459, 35.34562605184],
  'Faculty of Information Technology': [32.4067799, 35.3434195],
  'Faculty of Law': [32.40994276264, 35.34271314606],
  'Faculty of Medicine': [32.40698765272, 35.34493736856],
  'Faculty of Sports Sciences': [32.40916606511, 35.34312352404],
  'Gate 1': [32.4055108, 35.3422267],
  'Gate 2': [32.40608128658, 35.34152358703],
  'Gate 3': [32.40732166418, 35.3413358324],
  'Gate 4': [32.408963575, 35.34113709847],
  'Gate 5': [32.41070360271, 35.34392818674],
  'Cafeteria': [32.4070554, 35.3425649],
  'Administration': [32.40909133875, 35.34282311663],
  'Deanship of Admission and Registration': [32.40683706467, 35.34197419748],
  'Presidential Building': [32.40813574288, 35.3429451558],
  'International Soccer Stadium': [32.40953969708, 35.34442841738],
};

/// Cards with no entrance in the map; they must stay unavailable.
const _unavailable = [
  'Faculty of Nursing',
  'Faculty of Pharmacy',
  'Faculty of Science',
  'Library',
];

/// Card names declared in the Uni screen (`_UniversityItem(name: ...)`).
List<String> _uniScreenCardNames() {
  final source = File('lib/screens/university/university_locations_screen.dart')
      .readAsStringSync();
  return RegExp(r"_UniversityItem\(\s*name:\s*'([^']+)'")
      .allMatches(source)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  test('every destination uses the exact JOSM entrance coordinates', () {
    expect(campusDestinations.map((d) => d.name).toSet(),
        _expected.keys.toSet());
    _expected.forEach((name, coordinates) {
      final destination = campusDestinationByName(name);
      expect(destination, isNotNull, reason: name);
      expect(destination!.position.latitude, coordinates[0], reason: name);
      expect(destination.position.longitude, coordinates[1], reason: name);
    });
  });

  test('every Uni screen card is either navigable or deliberately unavailable',
      () {
    final cards = _uniScreenCardNames();
    expect(cards.toSet(), hasLength(cards.length), reason: 'duplicate card');
    expect(cards.toSet(), {..._expected.keys, ..._unavailable});
    for (final name in _unavailable) {
      expect(campusDestinationByName(name), isNull, reason: name);
    }
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

  test('every destination is inside the campus bounds', () {
    for (final d in campusDestinations) {
      expect(d.position.latitude, inInclusiveRange(32.404, 32.411),
          reason: d.name);
      expect(d.position.longitude, inInclusiveRange(35.340, 35.348),
          reason: d.name);
    }
  });

  test('each destination produces its own OSRM foot request', () async {
    final requestedPaths = <String, String>{};
    for (final d in campusDestinations) {
      final service = OsrmRoutingService(
        baseUrl: 'http://campus.test:5002',
        httpClient: MockClient((request) async {
          requestedPaths[d.name] = request.url.path;
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
                      [d.position.longitude, d.position.latitude],
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
                  'location': [d.position.longitude, d.position.latitude],
                },
              ],
            }),
            200,
          );
        }),
      );
      await service.computeRoute(origin: _origin, destination: d.position);
    }

    expect(requestedPaths.values.toSet(), hasLength(campusDestinations.length));
    expect(requestedPaths['Faculty of Engineering'],
        '/route/v1/foot/35.3422267,32.4055108;35.34562605184,32.40828122459');
    expect(requestedPaths['Dentistry – DEN-B'],
        '/route/v1/foot/35.3422267,32.4055108;35.341416298,32.40578067275');
  });
}
