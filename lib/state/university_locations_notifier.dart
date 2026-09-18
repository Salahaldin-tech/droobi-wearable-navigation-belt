import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/university_location.dart';
import '../services/firebase/firestore_university_locations_service.dart';
import '../services/firebase/university_locations_service.dart';

final universityLocationsServiceProvider =
    Provider<UniversityLocationsService>((ref) {
  return FirestoreUniversityLocationsService();
});

final universityLocationsProvider =
    StreamProvider<List<UniversityLocation>>((ref) {
  final service = ref.watch(universityLocationsServiceProvider);
  return service.watchUniversityLocations();
});
