import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/university_location.dart';
import 'university_locations_service.dart';

/// Concrete UniversityLocationsService backed by Firestore, reading
/// the shared/static universityLocations collection from Stage 2.
///
/// This collection is not written to by the app - it's expected to
/// be seeded manually/administratively in the Firebase Console (per
/// Stage 1 decision #5: a simple predefined list, not user-editable).
class FirestoreUniversityLocationsService implements UniversityLocationsService {
  FirestoreUniversityLocationsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<UniversityLocation>> watchUniversityLocations() {
    return _firestore
        .collection('universityLocations')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UniversityLocation.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}
