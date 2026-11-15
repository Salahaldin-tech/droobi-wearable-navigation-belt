import 'dart:convert';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/routing/osrm_routing_service.dart';
import 'package:droobi/services/routing/routing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _origin = LatLon(latitude: 32.40734220259285, longitude: 35.341330768462434);
const _destination =
    LatLon(latitude: 32.40700627577471, longitude: 35.34214214101637);

Map<String, dynamic> _body({
  String mode = 'walking',
  double originSnap = 1.8,
  double destinationSnap = 3.2,
}) =>
    {
      'code': 'Ok',
      'routes': [
        {
          'distance': 130.0,
          'duration': 95.0,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [35.341332, 32.407326],
              [35.342100, 32.407010],
            ],
          },
          'legs': [
            {
              'steps': [
                {'mode': mode},
                {'mode': mode},
              ],
            },
          ],
        },
      ],
      'waypoints': [
        {'distance': originSnap, 'location': [35.341332, 32.407326]},
        {'distance': destinationSnap, 'location': [35.342100, 32.407010]},
      ],
    };

OsrmRoutingService _service(http.Response Function(http.Request) handler,
        {bool requireWalkingMode = true}) =>
    OsrmRoutingService(
      baseUrl: 'http://campus.test:5001/',
      maxSnapRadiusMeters: 20,
      requireWalkingMode: requireWalkingMode,
      httpClient: MockClient((request) async => handler(request)),
    );

void main() {
  test('builds a lon,lat foot request with steps and radiuses', () async {
    late Uri uri;
    final service = _service((request) {
      uri = request.url;
      return http.Response(jsonEncode(_body()), 200);
    });
    await service.computeRoute(origin: _origin, destination: _destination);
    expect(uri.path,
        '/route/v1/foot/35.341330768462434,32.40734220259285;35.34214214101637,32.40700627577471');
    expect(uri.queryParameters['steps'], 'true');
    expect(uri.queryParameters['radiuses'], '20.0;20.0');
    expect(uri.queryParameters['geometries'], 'geojson');
  });

  test('accepts a walking route and reports snap distances', () async {
    final service =
        _service((_) => http.Response(jsonEncode(_body()), 200));
    final route =
        await service.computeRoute(origin: _origin, destination: _destination);
    expect(route.polyline, hasLength(2));
    expect(route.polyline.first.latitude, 32.407326);
    expect(route.originSnapMeters, 1.8);
    expect(route.destinationSnapMeters, 3.2);
  });

  test('rejects a car route returned for a foot request', () async {
    final service = _service(
        (_) => http.Response(jsonEncode(_body(mode: 'driving')), 200));
    expect(
      service.computeRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoutingFailure>().having(
          (f) => f.message, 'message', contains('did not return a pedestrian'))),
    );
  });

  test('rejects a response without step modes when walking is required',
      () async {
    final body = _body();
    (body['routes'] as List).first['legs'] = [
      {'steps': []}
    ];
    final service = _service((_) => http.Response(jsonEncode(body), 200));
    expect(
      service.computeRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoutingFailure>()),
    );
  });

  test('enforces the snap radius even if the server ignores radiuses',
      () async {
    final service = _service((_) =>
        http.Response(jsonEncode(_body(destinationSnap: 53.0)), 200));
    expect(
      service.computeRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoutingFailure>().having(
          (f) => f.message, 'message', contains('53.0 m'))),
    );
  });

  test('explains NoSegment instead of a bare HTTP status', () async {
    final service = _service((_) => http.Response(
        jsonEncode({
          'code': 'NoSegment',
          'message': 'Could not find a matching segment for coordinate 1',
        }),
        400));
    expect(
      service.computeRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoutingFailure>().having(
          (f) => f.message, 'message', contains('NoSegment'))),
    );
  });

  test('general routing keeps its previous behaviour (no mode check)',
      () async {
    late Uri uri;
    final service = _service((request) {
      uri = request.url;
      return http.Response(jsonEncode(_body(mode: 'driving')), 200);
    }, requireWalkingMode: false);
    final route =
        await service.computeRoute(origin: _origin, destination: _destination);
    expect(route.polyline, isNotEmpty);
    expect(uri.queryParameters.containsKey('steps'), isFalse);
  });

  test('unconfigured campus router fails with a clear message', () async {
    const router = UnconfiguredRoutingService('not configured');
    expect(
      router.computeRoute(origin: _origin, destination: _destination),
      throwsA(isA<RoutingFailure>()),
    );
  });
}
