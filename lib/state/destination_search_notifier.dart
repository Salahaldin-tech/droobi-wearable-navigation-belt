import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../services/search/destination_search_service.dart';
import '../services/search/google_places_search_service.dart';

/// The Places API key is supplied at build/run time via --dart-define,
/// never hardcoded in source. See the setup steps provided separately
/// for exactly how to pass this on Windows.
///
/// Example:
///   flutter run --dart-define=GOOGLE_PLACES_API_KEY=your_key_here
const String _googlePlacesApiKey =
    String.fromEnvironment('GOOGLE_PLACES_API_KEY');

/// The single DestinationSearchService instance for the app.
/// Everywhere else should depend on [DestinationSearchService] (the
/// interface) via this provider, so the search provider stays
/// swappable, consistent with the BLE/Auth pattern.
final destinationSearchServiceProvider =
    Provider<DestinationSearchService>((ref) {
  if (_googlePlacesApiKey.isEmpty) {
    throw StateError(
      'GOOGLE_PLACES_API_KEY was not provided. Run with '
      '--dart-define=GOOGLE_PLACES_API_KEY=your_key_here',
    );
  }
  return GooglePlacesSearchService(apiKey: _googlePlacesApiKey);
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
