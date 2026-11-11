import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// OSRM HTTP client using the pedestrian `foot` profile.
/// Campus navigation points this client at a dedicated OSRM dataset built
/// from the AAUP OSM snapshot; general navigation may use a separate endpoint.
class OsrmRoutingService implements RoutingService {
  OsrmRoutingService({
    String baseUrl = 'https://router.project-osrm.org',
    this.maxSnapRadiusMeters,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = httpClient ?? http.Client() {
    if (maxSnapRadiusMeters != null && maxSnapRadiusMeters! <= 0) {
      throw ArgumentError.value(
        maxSnapRadiusMeters,
        'maxSnapRadiusMeters',
        'Must be greater than zero.',
      );
    }
  }

  final String _baseUrl;
  final http.Client _client;

  /// Optional maximum snap radius for both endpoints. Campus routing sets
  /// this to prevent OSRM from attaching a destination to a distant path.
  final double? maxSnapRadiusMeters;

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    // OSRM coordinate order is longitude,latitude.
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final queryParameters = <String, String>{
      'overview': 'full',
      'geometries': 'geojson',
    };
    if (maxSnapRadiusMeters != null) {
      final radius = maxSnapRadiusMeters!.toStringAsFixed(1);
      queryParameters['radiuses'] = '$radius;$radius';
    }

    final uri = Uri.parse('$_baseUrl/route/v1/foot/$coordinates').replace(
      queryParameters: queryParameters,
    );

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 15));
    } on SocketException {
      throw const RoutingFailure(
        RoutingErrorType.networkError,
        'Network error while calculating route. Please check your connection.',
      );
    } on Exception {
      throw const RoutingFailure(
        RoutingErrorType.networkError,
        'Could not reach the routing service.',
      );
    }

    if (response.statusCode != 200) {
      throw RoutingFailure(
        RoutingErrorType.apiError,
        'Routing failed (status ${response.statusCode}).',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const RoutingFailure(
        RoutingErrorType.apiError,
        'Received an unexpected response from the routing service.',
      );
    }

    if (body['code'] != 'Ok') {
      throw RoutingFailure(
        RoutingErrorType.noRouteFound,
        'No walking route found between those points '
        '(OSRM code: ${body['code']}).',
      );
    }

    final routes = body['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw const RoutingFailure(
        RoutingErrorType.noRouteFound,
        'No route found between those points.',
      );
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>;
    final rawCoordinates = geometry['coordinates'] as List<dynamic>;

    final polyline = rawCoordinates.map((point) {
      final pair = point as List<dynamic>;
      return LatLon(
        latitude: (pair[1] as num).toDouble(),
        longitude: (pair[0] as num).toDouble(),
      );
    }).toList();

    return RouteResult(
      polyline: polyline,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
    );
  }

  void dispose() {
    _client.close();
  }
}
