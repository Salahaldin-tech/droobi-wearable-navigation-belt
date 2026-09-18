/// A user's saved favorite location, matching the
/// users/{uid}/favorites/{favoriteId} schema from Stage 2.
class FavoriteLocation {
  const FavoriteLocation({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  factory FavoriteLocation.fromFirestore(String id, Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    final DateTime createdAt = switch (rawCreatedAt) {
      DateTime dt => dt,
      _ when rawCreatedAt != null &&
          rawCreatedAt.runtimeType.toString() == 'Timestamp' =>
        (rawCreatedAt as dynamic).toDate() as DateTime,
      _ => DateTime.now(),
    };

    return FavoriteLocation(
      id: id,
      label: (data['label'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestoreFields() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
