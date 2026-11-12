/// A university location record. Firestore locations and live OSM entrance
/// nodes share this coordinate model; runtime campus targets are loaded from
/// OSM and carry the optional OSM tags below.
class UniversityLocation {
  const UniversityLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.destinationKey,
    this.ref,
    this.entrance,
    this.access,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// OSM entrance tags used to identify the destination without fixed
  /// coordinates embedded in the app.
  final String? destinationKey;
  final String? ref;
  final String? entrance;
  final String? access;

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
