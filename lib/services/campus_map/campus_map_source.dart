import 'dart:convert';

/// Identifies and validates the exact campus map snapshot copied from main.
class CampusMapSource {
  static const String nodesAsset =
      'assets/campus_map_v3/exported/nodes.geojson';
  static const String edgesAsset =
      'assets/campus_map_v3/exported/edges.geojson';

  static const String repository =
      'Salahaldin-tech/droobi-wearable-navigation-belt';
  static const String sourceBranch = 'main';
  static const String sourcePath =
      'assets/campus_map_v3/campus_network.gpkg';
  static const String sourceGitBlobSha1 =
      'a1eb1b7652d6e6f6251a2dce9f0e7c99d4decf41';
  static const String projectPath =
      'assets/campus_map_v3/AAUP_Campus_Network.qgz';
  static const String projectGitBlobSha1 =
      'ae94aaf49c669bc5e8147ec94b863711a8f3d998';

  static const String nodesLayer = 'campus_network';
  static const String edgesLayer = 'edges';
  static const String coordinateReferenceSystem = 'EPSG:4326';

  static Map<String, dynamic> decodeAndValidate(
    String source, {
    required String expectedLayer,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['type'] != 'FeatureCollection') {
      throw const FormatException(
        'Campus map data is not a GeoJSON FeatureCollection.',
      );
    }

    final metadata = decoded['metadata'];
    if (metadata is! Map<String, dynamic>) {
      throw const FormatException(
        'Campus map provenance metadata is missing. Re-export the main-branch GeoPackage.',
      );
    }

    final expected = <String, String>{
      'source_repository': repository,
      'source_branch': sourceBranch,
      'source_path': sourcePath,
      'source_git_blob_sha1': sourceGitBlobSha1,
      'source_project_path': projectPath,
      'source_project_git_blob_sha1': projectGitBlobSha1,
      'source_layer': expectedLayer,
      'crs': coordinateReferenceSystem,
    };

    for (final entry in expected.entries) {
      if (metadata[entry.key]?.toString() != entry.value) {
        throw FormatException(
          'Campus map source mismatch for ' + entry.key +
          '. Expected ' + entry.value +
          ', received ' + metadata[entry.key].toString() + '.',
        );
      }
    }

    final features = decoded['features'];
    if (features is! List || features.isEmpty) {
      throw FormatException(
        'The verified ' + expectedLayer + ' layer contains no features.',
      );
    }
    for (final feature in features) {
      if (feature is! Map<String, dynamic>) {
        throw FormatException(
          'The verified ' + expectedLayer + ' layer contains an invalid feature.',
        );
      }
      final properties = feature['properties'];
      if (properties is! Map<String, dynamic> ||
          properties['_source_layer']?.toString() != expectedLayer) {
        throw FormatException(
          'A feature does not belong to the expected ' + expectedLayer + ' layer.',
        );
      }
    }

    return decoded;
  }
}
