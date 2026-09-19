import 'package:flutter/material.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import '../../services/routing/osrm_routing_service.dart';
import '../../services/routing/routing_service.dart';

/// TEMPORARY screen for Phase 2 step 1 validation only.
///
/// Purpose: confirm OSRM (OSM "foot" profile) returns a usable
/// walking route/polyline for hardcoded coordinates near the Arab
/// American University campus, and surface whether OSM has adequate
/// pedestrian path data there - before any GPS, heading, or
/// direction-calculation code is written.
///
/// Hardcoded points are placeholders near the AAUP Jenin campus
/// (~32.4066N, 35.3433E per public campus coordinates) - adjust to
/// two real, more precise points on/near campus if these don't
/// reflect where you want to test.
class RoutingTestScreen extends StatefulWidget {
  const RoutingTestScreen({super.key});

  @override
  State<RoutingTestScreen> createState() => _RoutingTestScreenState();
}

class _RoutingTestScreenState extends State<RoutingTestScreen> {
  final RoutingService _routingService = OsrmRoutingService();

  static const LatLon _origin = LatLon(latitude: 32.4066, longitude: 35.3433);
  static const LatLon _destination =
      LatLon(latitude: 32.4130, longitude: 35.3433);

  bool _isLoading = false;
  String? _errorMessage;
  RouteResult? _result;

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _routingService.computeRoute(
        origin: _origin,
        destination: _destination,
      );
      setState(() => _result = result);
    } on RoutingFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routing Test (Phase 2 Step 1)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Origin: $_origin'),
            Text('Destination: $_destination'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _runTest,
              child: Text(_isLoading ? 'Requesting route...' : 'Compute Route'),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_result != null) ...[
              Text('Polyline points: ${_result!.polyline.length}'),
              Text(
                'Distance: ${_result!.distanceMeters.toStringAsFixed(1)} m',
              ),
              Text(
                'Duration: ${_result!.durationSeconds.toStringAsFixed(0)} s',
              ),
              const SizedBox(height: 8),
              const Text('First few polyline points:'),
              Expanded(
                child: ListView(
                  children: _result!.polyline
                      .take(15)
                      .map((p) => Text(p.toString()))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
