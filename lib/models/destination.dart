/// A resolved destination candidate, as returned by destination search.
///
/// This is the shared shape used by search results now, and will be
/// reused by Favorites/University Locations in later stages since
/// they carry the same minimal fields (per the Stage 2 data model).
class Destination {
  const Destination({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String name;
  final double latitude;
  final double longitude;

  /// Formatted address, when the search provider returns one.
  /// Nullable because not every provider/result guarantees it.
  final String? address;
}
