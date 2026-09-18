import '../../models/university_location.dart';

/// Abstract interface for the static/seeded university locations list.
/// Read-only from the app's perspective, per Stage 1 decision #5.
abstract class UniversityLocationsService {
  Stream<List<UniversityLocation>> watchUniversityLocations();
}
