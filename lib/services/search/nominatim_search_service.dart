import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/destination.dart';
import 'destination_search_service.dart';

/// Destination search implementation using the public
/// OpenStreetMap Nominatim search service.
///
/// Results are restricted to Palestine using `countrycodes=ps`.
class NominatimSearchService implements DestinationSearchService {
  NominatimSearchService({
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  static const String _endpoint =
      'https://nominatim.openstreetmap.org/search';

  final http.Client _client;

  @override
  Future<List<Destination>> searchDestinations(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      return const [];
    }

    final uri = Uri.parse(_endpoint).replace(
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '10',
        'countrycodes': 'ps',
        'addressdetails': '1',
        'accept-language': 'en,ar',
      },
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

  Destination? _toDestination(Map<String, dynamic> result) {
    final latitude = double.tryParse(result['lat']?.toString() ?? '');
    final longitude = double.tryParse(result['lon']?.toString() ?? '');

    if (latitude == null || longitude == null) {
      return null;
    }

    final displayName = result['display_name'] as String?;
    final name = result['name'] as String?;

    final resolvedName =
        (name != null && name.trim().isNotEmpty)
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
    if (displayName == null || displayName.trim().isEmpty) {
      return 'Unnamed place';
    }

    return displayName.split(',').first.trim();
  }
}