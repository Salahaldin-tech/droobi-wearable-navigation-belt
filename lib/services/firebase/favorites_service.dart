import '../../models/destination.dart';
import '../../models/favorite_location.dart';

/// Abstract interface for the signed-in user's favorite locations.
abstract class FavoritesService {
  /// Emits the current user's favorites list whenever it changes.
  Stream<List<FavoriteLocation>> watchFavorites(String uid);

  /// Adds a selected destination (from search or elsewhere) as a
  /// favorite under the given label.
  ///
  /// Scope note: only a caller-provided [destination] is supported
  /// here - "add current location" is explicitly out of scope until
  /// the GPS stage.
  Future<void> addFavorite({
    required String uid,
    required String label,
    required Destination destination,
  });

  Future<void> removeFavorite({
    required String uid,
    required String favoriteId,
  });
}
