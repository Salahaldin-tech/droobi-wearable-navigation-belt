import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';
import '../services/search/destination_search_service.dart';
import '../services/search/nominatim_search_service.dart';

const searchCities = <String>[
  'Ramallah',
  'East Jerusalem',
  'Hebron',
  'Nablus',
  'Jenin',
  'Bethlehem',
  'Jericho',
  'Tulkarm',
  'Qalqilya',
  'Tubas',
  'Salfit',
  'Gaza City',
  'Khan Yunis',
  'Rafah',
  'Jabalia',
  'Deir al-Balah',
];

/// ===========================================================
/// DESTINATION SEARCH PROVIDER
/// ===========================================================

final destinationSearchServiceProvider =
    Provider<DestinationSearchService>((ref) {
  return NominatimSearchService();
});

class DestinationSearchState {
  const DestinationSearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCity = 'Jenin',
  });

  final String query;
  final List<Destination> results;
  final bool isLoading;
  final String? errorMessage;
  final String selectedCity;

  DestinationSearchState copyWith({
    String? query,
    List<Destination>? results,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? selectedCity,
  }) {
    return DestinationSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      selectedCity: selectedCity ?? this.selectedCity,
    );
  }
}

class DestinationSearchNotifier
    extends StateNotifier<DestinationSearchState> {
  DestinationSearchNotifier(this._service)
      : super(const DestinationSearchState()) {
    _loadSelectedCity();
  }

  final DestinationSearchService _service;

  // Invalidates older requests when the user clears or starts a new search.
  int _searchRequestId = 0;

  static const String _cityPreferenceKey =
      'destination_search_city';

  Future<void> _loadSelectedCity() async {
    final preferences =
        await SharedPreferences.getInstance();

    final savedCity =
        preferences.getString(_cityPreferenceKey);

    if (savedCity != null &&
        searchCities.contains(savedCity)) {
      state = state.copyWith(
        selectedCity: savedCity,
      );
    }
  }

  Future<void> setCity(String city) async {
    if (!searchCities.contains(city)) {
      return;
    }

    _searchRequestId++;
    state = state.copyWith(
      selectedCity: city,
      results: const [],
      isLoading: false,
      clearError: true,
    );

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _cityPreferenceKey,
      city,
    );
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      clear();
      return;
    }

    final requestId = ++_searchRequestId;
    state = state.copyWith(
      query: normalizedQuery,
      results: const [],
      isLoading: true,
      clearError: true,
    );

    try {
      final results = await _service.searchDestinations(
        normalizedQuery,
        city: state.selectedCity,
      );

      // Ignore stale responses if a newer search or clear happened meanwhile.
      if (requestId != _searchRequestId) return;

      state = state.copyWith(
        results: results,
        isLoading: false,
        clearError: true,
      );
    } on Exception catch (e) {
      if (requestId != _searchRequestId) return;

      state = state.copyWith(
        isLoading: false,
        results: const [],
        errorMessage: e.toString(),
      );
    }
  }

  void clear() {
    _searchRequestId++;
    state = DestinationSearchState(
      selectedCity: state.selectedCity,
    );
  }
}

final destinationSearchProvider =
    StateNotifierProvider<
        DestinationSearchNotifier,
        DestinationSearchState>((ref) {
  final service =
      ref.watch(destinationSearchServiceProvider);

  return DestinationSearchNotifier(service);
});