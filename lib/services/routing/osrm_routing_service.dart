import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import 'routing_service.dart';

/// Concrete RoutingService using OSRM's HTTP API with the OSM "foot"
/// profile (spec point #1). Returns geometry only - never turn-by-turn
/// text - since direction is computed downstream from the polyline
/// plus live position/heading (DirectionCalculator, later step).
///
/// This is the only file that talks to OSRM directly.
///
/// baseUrl defaults to the public OSRM demo instance
/// (router.project-osrm.org), which is fine for this step's
/// hardcoded-coordinate testing but is rate-limited and NOT intended
/// for production/sustained use - a self-hosted instance is expected
/// before real walk-testing (development order step 6+).
class OsrmRoutingService implements RoutingService {
  OsrmRoutingService({
    String baseUrl = 'https://router.project-osrm.org',
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _client = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    // OSRM expects "lon,lat" order, NOT "lat,lon".
    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final uri = Uri.parse('$_baseUrl/route/v1/foot/$coordinates').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
      },
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
      // GeoJSON order is [lon, lat] - swapped back to LatLon here.
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
}
