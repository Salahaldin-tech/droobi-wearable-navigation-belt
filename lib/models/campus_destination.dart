import 'lat_lon.dart';

/// A fixed campus destination selectable from the Uni screen.
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
///
/// Coordinates are copied verbatim from the entrance nodes placed in JOSM
/// (campus-network-map/josm/aaup-campus-edit.osm, saved 2026-11-18). Every
/// entrance node sits on the foot-routable network the campus OSRM server is
/// built from, so OSRM ends each route at the entrance itself. The app does
/// not read the OSM file; to move a destination, edit the coordinate here.
///
/// Cards without an entrance in that map (Nursing, Pharmacy, Science,
/// Library) are intentionally absent and stay unavailable.
const List<CampusDestination> campusDestinations = [
  // ---- Colleges -------------------------------------------------------
  CampusDestination(
    id: 'allied-medical-sciences-a',
    name: 'Allied Medical Sciences – AMS-A',
    // OSM node 14368505148, ref AMS-A.
    position: LatLon(latitude: 32.4071561, longitude: 35.3441229),
  ),
  CampusDestination(
    id: 'allied-medical-sciences-b',
    name: 'Allied Medical Sciences – AMS-B',
    // OSM node 10003173854, ref AMS-B.
    position: LatLon(latitude: 32.4065527, longitude: 35.3445109),
  ),
  CampusDestination(
    id: 'arts-education',
    name: 'Faculty of Arts and Education',
    // OSM node 14368505138, "Arts main door".
    position: LatLon(latitude: 32.4079498, longitude: 35.3445806),
  ),
  CampusDestination(
    id: 'business',
    name: 'Faculty of Business',
    // JOSM node -26793, "Business Faculty Entrance".
    position: LatLon(latitude: 32.40637963603, longitude: 35.34252405033),
  ),
  CampusDestination(
    id: 'dentistry-a',
    name: 'Dentistry – DEN-A',
    // JOSM node -27252, ref DEN-A.
    position: LatLon(latitude: 32.40599410285, longitude: 35.34183807604),
  ),
  CampusDestination(
    id: 'dentistry-b',
    name: 'Dentistry – DEN-B',
    // JOSM node -27259, ref DEN-B.
    position: LatLon(latitude: 32.40578067275, longitude: 35.341416298),
  ),
  CampusDestination(
    id: 'engineering',
    name: 'Faculty of Engineering',
    // OSM node 14368505140, "Engineering main door".
    position: LatLon(latitude: 32.40828122459, longitude: 35.34562605184),
  ),
  CampusDestination(
    id: 'information-technology',
    name: 'Faculty of Information Technology',
    // OSM node 14368505133, "IT main door".
    position: LatLon(latitude: 32.4067799, longitude: 35.3434195),
  ),
  CampusDestination(
    id: 'law',
    name: 'Faculty of Law',
    // JOSM node -27236, ref LAW.
    position: LatLon(latitude: 32.40994276264, longitude: 35.34271314606),
  ),
  CampusDestination(
    id: 'medicine',
    name: 'Faculty of Medicine',
    // JOSM node -27405, ref MED.
    position: LatLon(latitude: 32.40698765272, longitude: 35.34493736856),
  ),
  CampusDestination(
    id: 'sports-sciences',
    name: 'Faculty of Sports Sciences',
    // JOSM node -27308, ref SH (Sports Hall).
    position: LatLon(latitude: 32.40916606511, longitude: 35.34312352404),
  ),

  // ---- Gates ----------------------------------------------------------
  CampusDestination(
    id: 'gate-1',
    name: 'Gate 1',
    // OSM node 14368505157.
    position: LatLon(latitude: 32.4055108, longitude: 35.3422267),
  ),
  CampusDestination(
    id: 'gate-2',
    name: 'Gate 2',
    // JOSM node -27133.
    position: LatLon(latitude: 32.40608128658, longitude: 35.34152358703),
  ),
  CampusDestination(
    id: 'gate-3',
    name: 'Gate 3',
    // JOSM node -27773.
    position: LatLon(latitude: 32.40732166418, longitude: 35.3413358324),
  ),
  CampusDestination(
    id: 'gate-4',
    name: 'Gate 4',
    // JOSM node -27481, ref G4.
    position: LatLon(latitude: 32.408963575, longitude: 35.34113709847),
  ),
  CampusDestination(
    id: 'gate-5',
    name: 'Gate 5',
    // JOSM node -27498, ref G5.
    position: LatLon(latitude: 32.41070360271, longitude: 35.34392818674),
  ),

  // ---- Facilities -----------------------------------------------------
  CampusDestination(
    id: 'cafeteria',
    name: 'Cafeteria',
    // OSM node 14368505156, "cafeteria main door".
    position: LatLon(latitude: 32.4070554, longitude: 35.3425649),
  ),
  CampusDestination(
    id: 'administration',
    name: 'Administration',
    // JOSM node -27328, ref AD (Administrative Departments Building).
    position: LatLon(latitude: 32.40909133875, longitude: 35.34282311663),
  ),
  CampusDestination(
    id: 'admission-registration',
    name: 'Deanship of Admission and Registration',
    // JOSM node -26839, DAR.
    position: LatLon(latitude: 32.40683706467, longitude: 35.34197419748),
  ),
  CampusDestination(
    id: 'presidential-building',
    name: 'Presidential Building',
    // JOSM node -27295, ref PR.
    position: LatLon(latitude: 32.40813574288, longitude: 35.3429451558),
  ),
  CampusDestination(
    id: 'soccer-stadium',
    name: 'International Soccer Stadium',
    // JOSM node -27346, ref ISS.
    position: LatLon(latitude: 32.40953969708, longitude: 35.34442841738),
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
