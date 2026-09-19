/// A bare coordinate pair - the sole contract between destination
/// search and routing (Phase 2, design decision #2). Routing never
/// depends on Destination (name/address) or any other domain model;
/// callers construct a LatLon from whatever they have
/// (Destination, FavoriteLocation, UniversityLocation, a raw GPS fix)
/// via its own .latitude/.longitude fields.
class LatLon {
  const LatLon({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  String toString() => 'LatLon($latitude, $longitude)';
}
