import 'lat_lon.dart';

/// A fixed, surveyed campus destination selectable from the Uni screen.
///
/// [name] must match the Uni screen card name exactly; [id] is a stable,
/// unique identifier that does not depend on the display name.
class CampusDestination {
  const CampusDestination({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final LatLon position;
}

/// Navigable campus destinations. Each entry owns its own coordinates;
/// no two entries may share an id, a name, or a coordinate pair.
const List<CampusDestination> campusDestinations = [
  CampusDestination(
    id: 'medicine',
    name: 'Faculty of Medicine',
    position: LatLon(
      latitude: 32.40717398179162,
      longitude: 35.34498148187609,
    ),
  ),
  CampusDestination(
    id: 'engineering',
    name: 'Faculty of Engineering',
    position: LatLon(
      latitude: 32.40830854009759,
      longitude: 35.345596474631094,
    ),
  ),
  CampusDestination(
    id: 'arts-education',
    name: 'Faculty of Arts and Education',
    position: LatLon(
      latitude: 32.408006935848874,
      longitude: 35.34456342369225,
    ),
  ),
  CampusDestination(
    id: 'gate-1',
    name: 'Gate 1',
    position: LatLon(
      latitude: 32.40552263782652,
      longitude: 35.342175006237284,
    ),
  ),
  CampusDestination(
    id: 'cafeteria',
    name: 'Cafeteria',
    position: LatLon(
      latitude: 32.407057851627115,
      longitude: 35.34257998109297,
    ),
  ),
  CampusDestination(
    id: 'information-technology',
    name: 'Faculty of Information Technology',
    position: LatLon(
      latitude: 32.40675340855915,
      longitude: 35.34339310908723,
    ),
  ),
  CampusDestination(
    id: 'gate-3',
    name: 'Gate 3',
    position: LatLon(
      latitude: 32.40734220259285,
      longitude: 35.341330768462434,
    ),
  ),
];

/// Returns the destination whose [CampusDestination.name] matches
/// [name] exactly, or null when that card is not navigable yet.
CampusDestination? campusDestinationByName(String name) {
  for (final destination in campusDestinations) {
    if (destination.name == name) return destination;
  }
  return null;
}
