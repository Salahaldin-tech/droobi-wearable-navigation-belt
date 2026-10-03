import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/destination.dart';
import 'destination_search_service.dart';

/// Searches OpenStreetMap through Nominatim.
///
/// The selected city is applied as a geographic boundary so results
/// outside that area are excluded from the search.
class NominatimSearchService implements DestinationSearchService {
  NominatimSearchService({
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  static const String _endpoint =
      'https://nominatim.openstreetmap.org/search';

  final http.Client _client;

  // These boxes are used as search areas for the cities in Settings.
  //
  // Format:
  // west, north, east, south
  static const Map<String, List<double>> _cityViewboxes = {
    'Ramallah': [
      35.15,
      32.02,
      35.25,
      31.87,
    ],
    'East Jerusalem': [
      35.18,
      32.00,
      35.27,
      31.72,
    ],
    'Hebron': [
      35.05,
      31.65,
      35.18,
      31.47,
    ],
    'Nablus': [
      35.20,
      32.27,
      35.35,
      32.18,
    ],
    'Jenin': [
      35.25,
      32.52,
      35.38,
      32.42,
    ],
    'Bethlehem': [
      35.15,
      31.75,
      35.25,
      31.65,
    ],
    'Jericho': [
      35.40,
      31.90,
      35.52,
      31.80,
    ],
    'Tulkarm': [
      35.00,
      32.34,
      35.12,
      32.27,
    ],
    'Qalqilya': [
      34.98,
      32.23,
      35.08,
      32.12,
    ],
    'Tubas': [
      35.35,
      32.36,
      35.47,
      32.27,
    ],
    'Salfit': [
      35.13,
      32.12,
      35.22,
      32.03,
    ],
    'Gaza City': [
      34.40,
      31.58,
      34.55,
      31.45,
    ],
    'Khan Yunis': [
      34.25,
      31.38,
      34.35,
      31.30,
    ],
    'Rafah': [
      34.18,
      31.34,
      34.28,
      31.23,
    ],
    'Jabalia': [
      34.43,
      31.58,
      34.52,
      31.50,
    ],
    'Deir al-Balah': [
      34.30,
      31.46,
      34.40,
      31.39,
    ],
  };

  @override
  Future<List<Destination>> searchDestinations(
    String query, {
    String? city,
  }) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      return const [];
    }

    final parameters = <String, String>{
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '10',
      'countrycodes': 'ps',
      'addressdetails': '1',
      'accept-language': 'en,ar',
    };

    final viewbox = _cityViewboxes[city];

    if (viewbox != null) {
      parameters['viewbox'] = viewbox.join(',');
      parameters['bounded'] = '1';
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: parameters,
    );

    late final http.Response response;

    try {
      response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Droobi/1.0 (Navigation Belt Project)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
    } on SocketException {
      throw const DestinationSearchFailure(
        DestinationSearchErrorType.networkError,
        'Network error while searching. Please check your connection and try again.',
      );
    } on Exception {
      throw const DestinationSearchFailure(
        DestinationSearchErrorType.networkError,
        'Could not reach the search service. Please try again.',
      );
    }

    if (response.statusCode != 200) {
      throw DestinationSearchFailure(
        DestinationSearchErrorType.apiError,
        'Destination search failed (status ${response.statusCode}). Please try again.',
      );
    }

    final List<dynamic> results;

    try {
      results = jsonDecode(response.body) as List<dynamic>;
    } on FormatException {
      throw const DestinationSearchFailure(
        DestinationSearchErrorType.apiError,
        'Received an unexpected response from the search service.',
      );
    }

    if (results.isEmpty) {
      return const [];
    }

    return results
        .map((result) {
          if (result is! Map<String, dynamic>) {
            return null;
          }

          return _toDestination(result);
        })
        .whereType<Destination>()
        .toList();
  }

  Destination? _toDestination(
    Map<String, dynamic> result,
  ) {
    final latitude = double.tryParse(
      result['lat']?.toString() ?? '',
    );

    final longitude = double.tryParse(
      result['lon']?.toString() ?? '',
    );

    if (latitude == null || longitude == null) {
      return null;
    }

    final displayName =
        result['display_name'] as String?;

    final name =
        result['name'] as String?;

    final resolvedName =
        name != null && name.trim().isNotEmpty
            ? name.trim()
            : _fallbackName(displayName);

    return Destination(
      name: resolvedName,
      latitude: latitude,
      longitude: longitude,
      address: displayName,
    );
  }

  String _fallbackName(String? displayName) {
    if (displayName == null ||
        displayName.trim().isEmpty) {
      return 'Unnamed place';
    }

    return displayName.split(',').first.trim();
  }
}