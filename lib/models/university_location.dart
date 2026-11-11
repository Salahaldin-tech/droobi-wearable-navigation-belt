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
}
