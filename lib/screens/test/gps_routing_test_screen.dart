import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import '../../services/location/location_service.dart';
import '../../services/routing/routing_service.dart';
import '../../state/location_notifier.dart';
import '../../state/routing_notifier.dart';

class GpsRoutingTestScreen extends ConsumerStatefulWidget {
  const GpsRoutingTestScreen({super.key});

  @override
  ConsumerState<GpsRoutingTestScreen> createState() =>
      _GpsRoutingTestScreenState();
}

class _GpsRoutingTestScreenState
    extends ConsumerState<GpsRoutingTestScreen> {
  // Temporary fixed destination for testing.
  // Arab American University - Jenin area.
  static const LatLon _testDestination = LatLon(
    latitude: 32.4130,
    longitude: 35.3433,
  );

  bool _isLoading = false;
  String? _errorMessage;
  LatLon? _currentLocation;
  RouteResult? _route;

  Future<void> _calculateRoute() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentLocation = null;
      _route = null;
    });

    final locationService = ref.read(locationServiceProvider);
    final routingService = ref.read(routingServiceProvider);

    try {
      // Step 1: Get the phone's current GPS location.
      final currentLocation =
          await locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _currentLocation = currentLocation;
      });

      // Step 2: Calculate a walking route from the
      // current GPS position to the fixed destination.
      final route = await routingService.computeRoute(
        origin: currentLocation,
        destination: _testDestination,
      );

      if (!mounted) return;

      setState(() {
        _route = route;
      });
    } on LocationFailure catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } on RoutingFailure catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS + Routing Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Latitude: ${_testDestination.latitude}',
            ),
            Text(
              'Longitude: ${_testDestination.longitude}',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _calculateRoute,
              child: Text(
                _isLoading
                    ? 'Calculating route...'
                    : 'Get GPS + Calculate Route',
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),

            if (_currentLocation != null) ...[
              const Divider(),
              const Text(
                'Current GPS Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Latitude: ${_currentLocation!.latitude}',
              ),
              Text(
                'Longitude: ${_currentLocation!.longitude}',
              ),
            ],

            if (_route != null) ...[
              const Divider(),
              const Text(
                'Route Result',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Distance: '
                '${_route!.distanceMeters.toStringAsFixed(1)} m',
              ),
              Text(
                'Duration: '
                '${_route!.durationSeconds.toStringAsFixed(0)} seconds',
              ),
              Text(
                'Polyline points: ${_route!.polyline.length}',
              ),
              const SizedBox(height: 12),
              const Text(
                'First 5 route points:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ..._route!.polyline
                  .take(5)
                  .map((point) => Text(point.toString())),
            ],
          ],
        ),
      ),
    );
  }
}