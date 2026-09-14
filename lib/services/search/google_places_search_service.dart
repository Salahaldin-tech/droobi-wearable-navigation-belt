import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/destination.dart';
import 'destination_search_service.dart';

/// Concrete DestinationSearchService using Places API (New) Text
/// Search (POST https://places.googleapis.com/v1/places:searchText).
///
/// This is the only file that talks to the Places API directly.
/// Everything else in the app depends on [DestinationSearchService].
///
/// Scope note: this stage only performs Text Search. It deliberately
/// does NOT call Place Details or Autocomplete - those are separate
/// endpoints/APIs not part of this stage.
class GooglePlacesSearchService implements DestinationSearchService {
  GooglePlacesSearchService({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _client = httpClient ?? http.Client();

  static const String _endpoint =
      'https://places.googleapis.com/v1/places:searchText';

  /// Minimum field mask needed to populate [Destination]: name,
  /// coordinates, and address when available. Requesting only these
  /// fields (rather than the full place resource) keeps each call at
  /// the lowest Places API (New) SKU/cost tier that still satisfies
  /// this stage's requirements.
  static const String _fieldMask =
      'places.displayName,places.formattedAddress,places.location';

  final String _apiKey;
  final http.Client _client;

  @override
  Future<List<Destination>> searchDestinations(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
              'X-Goog-FieldMask': _fieldMask,
            },
            body: jsonEncode({'textQuery': trimmed}),
          )
          .timeout(const Duration(seconds: 10));
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

    final places = body['places'] as List<dynamic>?;
    if (places == null || places.isEmpty) {
      return const [];
    }

    return places
        .map((place) => _toDestination(place as Map<String, dynamic>))
        .whereType<Destination>()
        .toList();
  }

  /// Converts a single Places API (New) result into a [Destination].
  /// Returns null (and skips the entry) if required fields are
  /// missing, rather than throwing and discarding the whole result set.
  Destination? _toDestination(Map<String, dynamic> place) {
    final location = place['location'] as Map<String, dynamic>?;
    final latitude = (location?['latitude'] as num?)?.toDouble();
    final longitude = (location?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    final displayName = place['displayName'] as Map<String, dynamic>?;
    final name = (displayName?['text'] as String?) ?? 'Unnamed place';

    final address = place['formattedAddress'] as String?;

    return Destination(
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }
}
