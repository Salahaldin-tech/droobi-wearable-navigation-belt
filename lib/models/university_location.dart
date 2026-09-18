/// A static/seeded university location, matching the
/// universityLocations/{locationId} schema from Stage 2. Read-only
/// from the app's perspective.
class UniversityLocation {
  const UniversityLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  factory UniversityLocation.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return UniversityLocation(
      id: id,
      name: (data['name'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}
