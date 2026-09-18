import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/destination.dart';
import '../../models/favorite_location.dart';
import 'favorites_service.dart';

/// Concrete FavoritesService backed by Firestore, using the
/// users/{uid}/favorites/{favoriteId} schema from Stage 2.
class FirestoreFavoritesService implements FavoritesService {
  FirestoreFavoritesService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _favoritesCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('favorites');

  @override
  Stream<List<FavoriteLocation>> watchFavorites(String uid) {
    return _favoritesCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FavoriteLocation.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> addFavorite({
    required String uid,
    required String label,
    required Destination destination,
  }) async {
    await _favoritesCollection(uid).add({
      'label': label,
      'latitude': destination.latitude,
      'longitude': destination.longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeFavorite({
    required String uid,
    required String favoriteId,
  }) async {
    await _favoritesCollection(uid).doc(favoriteId).delete();
  }
}
