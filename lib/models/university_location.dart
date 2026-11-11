/// A destination or entrance loaded from the canonical QGIS nodes layer.
/// Coordinates are WGS84 values exported from the source GeoPackage.
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

  /// Legacy deserialization retained for Firebase-backed screens that have
  /// not yet migrated. The University destination screen does not consume
  /// this provider; its spatial source of truth is the QGIS nodes layer.
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
