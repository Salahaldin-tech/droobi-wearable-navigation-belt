import '../../models/destination.dart';

/// Accessible, user-facing search error categories - mirrors the
/// AuthFailure pattern from Stage 6 so failures are always plain
/// messages, never raw HTTP/API exceptions, by the time they reach
/// the UI or a future FeedbackService announcement.
enum DestinationSearchErrorType {
  networkError,
  noResults,
  apiError,
  unknown,
}

class DestinationSearchFailure implements Exception {
  const DestinationSearchFailure(this.type, this.message);

  final DestinationSearchErrorType type;
  final String message;

  @override
  String toString() => message;
}

/// Abstract interface for resolving a free-text destination query
/// into candidate destinations. The rest of the app depends only on
/// this interface, never on the underlying search provider directly -
/// consistent with the "interfaces over concrete implementations"
/// rule used for BLE and Auth in earlier stages.
abstract class DestinationSearchService {
  /// Resolves [query] (typed or voice-transcribed text) into a list
  /// of candidate destinations. Returns an empty list if nothing
  /// matched - never throws for "no results", only for actual
  /// network/API failures (see [DestinationSearchFailure]).
  Future<List<Destination>> searchDestinations(String query);
}
