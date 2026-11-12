import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/university_location.dart';

/// Loads current campus entrance nodes directly from OpenStreetMap's
/// Overpass API. No bundled coordinate snapshot or Firestore coordinates
/// are used as runtime destination fallbacks.
class CampusOsmEntranceService {
  CampusOsmEntranceService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _query = '''
[out:json][timeout:25];
node["entrance"](32.404,35.340,32.411,35.348);
out body;
''';

  static final Uri _overpassUri =
      Uri.https('overpass-api.de', '/api/interpreter');

  Future<List<UniversityLocation>> fetchEntrances() async {
    final response = await _client
        .post(
          _overpassUri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': 'DroobiCampusNavigation/1.0',
          },
          body: {'data': _query},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw CampusOsmException(
        'OpenStreetMap Overpass returned HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const CampusOsmException(
        'OpenStreetMap returned an invalid response.',
      );
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      throw const CampusOsmException(
        'OpenStreetMap response did not contain entrance elements.',
      );
    }

    final entrances = <UniversityLocation>[];
    for (final element in elements) {
      if (element is! Map<String, dynamic> ||
          element['type'] != 'node') {
        continue;
      }

      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;

      final entrance = (tags['entrance'] ?? '').toString().toLowerCase();
      final access = (tags['access'] ?? 'yes').toString().toLowerCase();
      if (entrance.isEmpty || access == 'no' || access == 'private') {
        continue;
      }

      final latitude = (element['lat'] as num?)?.toDouble();
      final longitude = (element['lon'] as num?)?.toDouble();
      final id = (element['id'] ?? '').toString();
      if (latitude == null || longitude == null || id.isEmpty) continue;

      final destinationKey =
          (tags['destination_key'] ?? '').toString().trim();
      final ref = (tags['ref'] ?? '').toString().trim();
      final name = (tags['name'] ?? '').toString().trim();
      final displayName = ref.isNotEmpty
          ? ref
          : name.isNotEmpty
              ? name
              : destinationKey.isNotEmpty
                  ? destinationKey
                  : 'OSM entrance $id';

      entrances.add(UniversityLocation(
        id: id,
        name: displayName,
        latitude: latitude,
        longitude: longitude,
        destinationKey: destinationKey.isEmpty ? null : destinationKey,
        ref: ref.isEmpty ? null : ref,
        entrance: entrance,
        access: access,
      ));
    }

    if (entrances.isEmpty) {
      throw const CampusOsmException(
        'No mapped entrance nodes were found in the university area.',
      );
    }

    return entrances;
  }

  void dispose() {
    _client.close();
  }
}

class CampusOsmException implements Exception {
  const CampusOsmException(this.message);

  final String message;

  @override
  String toString() => message;
}
