import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/destination.dart';
import '../models/favorite_location.dart';
import '../services/firebase/favorites_service.dart';
import '../services/firebase/firestore_favorites_service.dart';
import 'auth_state_notifier.dart';

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FirestoreFavoritesService();
});

/// Streams the signed-in user's favorites. Emits an empty list when
/// signed out, rather than erroring - screens can check auth state
/// separately if they need to distinguish "no favorites" from
/// "not signed in".
final favoritesProvider = StreamProvider<List<FavoriteLocation>>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  final authState = ref.watch(authStateProvider);

  final uid = authState.maybeWhen(
    data: (user) => user?.uid,
    orElse: () => null,
  );

  if (uid == null) {
    return Stream.value(const []);
  }
  return service.watchFavorites(uid);
});

/// Thin action wrapper for add/remove, so screens don't need to reach
/// into favoritesServiceProvider + auth state directly.
class FavoritesActions {
  FavoritesActions(this._ref);

  final Ref _ref;

  Future<void> addFavorite({
    required String label,
    required Destination destination,
  }) async {
    final uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await _ref.read(favoritesServiceProvider).addFavorite(
          uid: uid,
          label: label,
          destination: destination,
        );
  }

  Future<void> removeFavorite(String favoriteId) async {
    final uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await _ref
        .read(favoritesServiceProvider)
        .removeFavorite(uid: uid, favoriteId: favoriteId);
  }
}

final favoritesActionsProvider = Provider<FavoritesActions>((ref) {
  return FavoritesActions(ref);
});
