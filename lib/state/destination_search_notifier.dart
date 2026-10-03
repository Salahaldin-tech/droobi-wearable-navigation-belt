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

    state = state.copyWith(
      selectedCity: city,
      results: const [],
    );

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _cityPreferenceKey,
      city,
    );
  }

  Future<void> search(String query) async {
    state = state.copyWith(
      query: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final results =
          await _service.searchDestinations(
        query,
        city: state.selectedCity,
      );

      state = state.copyWith(
        results: results,
        isLoading: false,
        clearError: true,
      );
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        results: const [],
        errorMessage: e.toString(),
      );
    }
  }

  void clear() {
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