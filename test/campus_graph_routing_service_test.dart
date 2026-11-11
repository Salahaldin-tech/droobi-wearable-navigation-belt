import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/services/campus_map/campus_map_source.dart';
import 'package:droobi/services/routing/campus_graph_routing_service.dart';
import 'package:droobi/services/routing/routing_service.dart';

Map<String, dynamic> _metadata(String layer) => {
      'source_repository': CampusMapSource.repository,
      'source_branch': CampusMapSource.sourceBranch,
      'source_path': CampusMapSource.sourcePath,
      'source_git_blob_sha1': CampusMapSource.sourceGitBlobSha1,
      'source_project_path': CampusMapSource.projectPath,
      'source_project_git_blob_sha1': CampusMapSource.projectGitBlobSha1,
      'source_layer': layer,
      'crs': CampusMapSource.coordinateReferenceSystem,
    };

String _nodesGeoJson({String? sourceSha}) => jsonEncode({
      'type': 'FeatureCollection',
      'metadata': {
        ..._metadata(CampusMapSource.nodesLayer),
        if (sourceSha != null) 'source_git_blob_sha1': sourceSha,
      },
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [34.0, 31.0],
          },
          'properties': {
            'node_id': 'N1',
            'name': 'Node One',
            'category': 'Test locations',
            '_source_layer': 'campus_network',
          },
        },
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [34.001, 31.0],
          },
          'properties': {
            'node_id': 'N2',
            'name': 'Node Two',
            'category': 'Test locations',
            '_source_layer': 'campus_network',
          },
        },
      ],
    });

String _edgesGeoJson() => jsonEncode({
      'type': 'FeatureCollection',
      'metadata': _metadata(CampusMapSource.edgesLayer),
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [34.0, 31.0],
              [34.001, 31.0],
            ],
          },
          'properties': {
            'edge_id': 'E1',
            'from_node': 'N1',
            'to_node': 'N2',
            '_source_layer': 'edges',
          },
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusGraphRoutingService main-map source', () {
    test('routes using only the verified main GeoPackage exports', () async {
      final requestedAssets = <String>[];
      final service = CampusGraphRoutingService(
        maximumSnapMeters: 5,
        assetLoader: (path) async {
          requestedAssets.add(path);
          if (path == CampusMapSource.nodesAsset) return _nodesGeoJson();
          if (path == CampusMapSource.edgesAsset) return _edgesGeoJson();
          throw FlutterError('Unexpected campus asset requested: $path');
        },
      );

      final route = await service.computeRoute(
        origin: const LatLon(latitude: 31.0, longitude: 34.0),
        destination: const LatLon(latitude: 31.0, longitude: 34.001),
      );

      expect(route.distanceMeters, greaterThan(100));
      expect(requestedAssets, [
        CampusMapSource.nodesAsset,
        CampusMapSource.edgesAsset,
      ]);
      expect(
        requestedAssets.any((path) => path.contains('docs/campus-mapping')),
        isFalse,
      );
    });

    test('does not fall back to V2 assets when a main export is missing',
        () async {
      final requestedAssets = <String>[];
      final service = CampusGraphRoutingService(
        assetLoader: (path) async {
          requestedAssets.add(path);
          throw FlutterError('Missing asset: $path');
        },
      );

      await expectLater(
        service.computeRoute(
          origin: const LatLon(latitude: 31.0, longitude: 34.0),
          destination: const LatLon(latitude: 31.0, longitude: 34.001),
        ),
        throwsA(isA<RoutingFailure>()),
      );

      expect(requestedAssets, [CampusMapSource.nodesAsset]);
      expect(
        requestedAssets.any((path) => path.contains('docs/campus-mapping')),
        isFalse,
      );
    });

    test('rejects GeoJSON that does not identify the exact main map blob',
        () async {
      final service = CampusGraphRoutingService(
        assetLoader: (path) async {
          if (path == CampusMapSource.nodesAsset) {
            return _nodesGeoJson(sourceSha: 'not-the-main-map');
          }
          return _edgesGeoJson();
        },
      );

      await expectLater(
        service.computeRoute(
          origin: const LatLon(latitude: 31.0, longitude: 34.0),
          destination: const LatLon(latitude: 31.0, longitude: 34.001),
        ),
        throwsA(
          isA<RoutingFailure>().having(
            (failure) => failure.message,
            'message',
            contains('source_git_blob_sha1'),
          ),
        ),
      );
    });
  });
}
