import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../services/search/destination_search_service.dart';
import '../services/search/geoapify_search_service.dart';
// import '../services/search/google_places_search_service.dart'; // TEMPORARILY UNUSED - see note below

/// ===========================================================
/// TEMPORARY PROVIDER SWITCH (Stage 7)
/// ===========================================================
/// This currently wires up GeoapifySearchService instead of
/// GooglePlacesSearchService because Google Cloud billing setup is
/// blocked on the developer's account (unrelated to this project's
/// code - see chat history for error OR_BACR2_31).
///
/// Both classes implement the exact same DestinationSearchService
/// interface, which is why swapping only requires changing this
/// provider - no other file in the app needed to change.
///
/// REVERT PLAN: once Google Cloud billing is resolved, change the
/// provider below back to:
///   return GooglePlacesSearchService(apiKey: _googlePlacesApiKey);
/// and switch the API key constant/env var accordingly.
/// ===========================================================

/// The Places API key is supplied at build/run time via --dart-define,
/// never hardcoded in source. Currently unused while the Geoapify
/// substitute is active - kept here for the revert.
///
/// Example:
///   flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key_here
const String _googlePlacesApiKey =
    String.fromEnvironment('GOOGLE_PLACES_API_KEY');

/// Geoapify API key, supplied the same way, never hardcoded.
///
/// Example:
///   flutter run --dart-define=GEOAPIFY_API_KEY=your_key_here
const String _geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

/// The single DestinationSearchService instance for the app.
/// Everywhere else should depend on [DestinationSearchService] (the
/// interface) via this provider, so the search provider stays
/// swappable, consistent with the BLE/Auth pattern.
final destinationSearchServiceProvider =
    Provider<DestinationSearchService>((ref) {
  if (_geoapifyApiKey.isEmpty) {
    throw StateError(
      'GEOAPIFY_API_KEY was not provided. Run with '
      '--dart-define=GEOAPIFY_API_KEY=your_key_here',
    );
  }
  return GeoapifySearchService(apiKey: _geoapifyApiKey);

  // --- Google Places (New) version, for when billing is fixed: ---
  // if (_googlePlacesApiKey.isEmpty) {
  //   throw StateError(
  //     'GOOGLE_PLACES_API_KEY was not provided. Run with '
  //     '--dart-define=GOOGLE_PLACES_API_KEY=your_key_here',
  //   );
  // }
  // return GooglePlacesSearchService(apiKey: _googlePlacesApiKey);
});

/// Search state for the (not-yet-built) Destination Search screen and,
/// later, the voice destination flow feeding into the same pipeline.
class DestinationSearchState {
  const DestinationSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final List<Destination> results;
  final bool isLoading;
  final String? errorMessage;

  DestinationSearchState copyWith({
    String? query,
    List<Destination>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DestinationSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DestinationSearchNotifier extends StateNotifier<DestinationSearchState> {
  DestinationSearchNotifier(this._service)
      : super(const DestinationSearchState());

  final DestinationSearchService _service;

  Future<void> search(String query) async {
    state = state.copyWith(query: query, isLoading: true, clearError: true);

    try {
      final results = await _service.searchDestinations(query);
      state = state.copyWith(
        results: results,
        isLoading: false,
        clearError: true,
      );
    } on Exception catch (e) {
      // Interface guarantees a plain-language message (Exception.toString
      // for a DestinationSearchFailure returns `message`), so this is
      // already safe to surface directly to the UI / a future
      // FeedbackService announcement.
      state = state.copyWith(
        isLoading: false,
        results: const [],
        errorMessage: e.toString(),
      );
    }
  }

  void clear() {
    state = const DestinationSearchState();
  }
}

final destinationSearchProvider = StateNotifierProvider<
    DestinationSearchNotifier, DestinationSearchState>((ref) {
  final service = ref.watch(destinationSearchServiceProvider);
  return DestinationSearchNotifier(service);
});
