import '../../models/destination.dart';


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


abstract class DestinationSearchService {
  
  Future<List<Destination>> searchDestinations(
    String query, {
    String? city,
  });
}