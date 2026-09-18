import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/destination.dart';
import 'destination_search_service.dart';

/// TEMPORARY substitute for [GooglePlacesSearchService], used only
/// because Google Cloud billing setup is currently blocked on the
/// developer's account (unrelated to this project's code). This
/// implementation is otherwise a drop-in replacement - it satisfies
/// the exact same [DestinationSearchService] interface, so nothing
/// outside lib/services/search/ and the provider wiring needed to
/// change.
///
/// REVERT PLAN: once Google Cloud billing works, switch
/// destinationSearchServiceProvider back to GooglePlacesSearchService
/// (see lib/state/destination_search_notifier.dart). This file can
/// stay in the project afterward as an optional fallback, or be
/// deleted - your call at that point.
///
/// Uses the Geoapify Geocoding API (free tier, API key required but
/// no billing/card needed): https://api.geoapify.com/v1/geocode/search
class GeoapifySearchService implements DestinationSearchService {
  GeoapifySearchService({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _client = httpClient ?? http.Client();

  static const String _endpoint = 'https://api.geoapify.com/v1/geocode/search';

  final String _apiKey;
  final http.Client _client;

  @override
  Future<List<Destination>> searchDestinations(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'text': trimmed,
      'format': 'geojson',
      'limit': '10',
      'apiKey': _apiKey,
    });

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
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

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const DestinationSearchFailure(
        DestinationSearchErrorType.apiError,
        'Received an unexpected response from the search service.',
      );
    }

    final features = body['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      return const [];
    }

    return features
        .map((feature) => _toDestination(feature as Map<String, dynamic>))
        .whereType<Destination>()
        .toList();
  }

  /// Converts a single Geoapify GeoJSON feature into a [Destination].
  /// Returns null (and skips the entry) if required fields are missing.
  Destination? _toDestination(Map<String, dynamic> feature) {
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (properties == null) return null;

    final latitude = (properties['lat'] as num?)?.toDouble();
    final longitude = (properties['lon'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    final formatted = properties['formatted'] as String?;
    final name = (properties['name'] as String?) ?? formatted ?? 'Unnamed place';

    return Destination(
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: formatted,
    );
  }
}
