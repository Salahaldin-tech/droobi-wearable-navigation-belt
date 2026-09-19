import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../services/search/destination_search_service.dart';
import '../services/search/nominatim_search_service.dart';

/// ===========================================================
/// DESTINATION SEARCH PROVIDER
/// ===========================================================
///
/// The app uses Nominatim / OpenStreetMap for destination search.
///
/// NominatimSearchService implements the same
/// DestinationSearchService interface used by the rest of the app,
/// so the UI and the search state do not need to know which provider
/// is being used.
///
/// Search results are restricted to Palestine by the
/// Nominatim service using:
///
///   countrycodes=ps
///
/// No API key or Google/Geoapify billing is required for this setup.
/// ===========================================================

/// The single DestinationSearchService instance for the app.
///
/// Everywhere else should depend only on [DestinationSearchService]
/// through this provider. This keeps the search provider swappable
/// without changing the UI or the rest of the application.
final destinationSearchServiceProvider =
    Provider<DestinationSearchService>((ref) {
  return NominatimSearchService();
});

/// Search state for the Destination Search screen and the future
/// voice destination flow feeding into the same pipeline.
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

/// Handles destination search requests and exposes the current
/// search state to the UI.
class DestinationSearchNotifier
    extends StateNotifier<DestinationSearchState> {
  DestinationSearchNotifier(this._service)
      : super(const DestinationSearchState());

  final DestinationSearchService _service;

  Future<void> search(String query) async {
    state = state.copyWith(
      query: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final results = await _service.searchDestinations(query);

      state = state.copyWith(
        results: results,
        isLoading: false,
        clearError: true,
      );
    } on Exception catch (e) {
      // DestinationSearchFailure exposes a plain-language message
      // through Exception.toString(), so it is safe to surface
      // directly to the UI.
      state = state.copyWith(
        isLoading: false,
        results: const [],
        errorMessage: e.toString(),
      );
    }
  }

  /// Clears the current search query, results, loading state,
  /// and error message.
  void clear() {
    state = const DestinationSearchState();
  }
}

/// Main provider consumed by the Destination Search UI.
final destinationSearchProvider = StateNotifierProvider<
    DestinationSearchNotifier,
    DestinationSearchState>((ref) {
  final service = ref.watch(destinationSearchServiceProvider);

  return DestinationSearchNotifier(service);
});