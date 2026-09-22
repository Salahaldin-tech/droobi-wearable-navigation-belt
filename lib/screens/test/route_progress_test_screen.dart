import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../models/route_result.dart';
import '../../services/location/location_service.dart';
import '../../services/navigation/route_progress_service.dart';
import '../../services/routing/routing_service.dart';
import '../../state/location_notifier.dart';
import '../../state/routing_notifier.dart';

class RouteProgressTestScreen extends ConsumerStatefulWidget {
  const RouteProgressTestScreen({super.key});

  @override
  ConsumerState<RouteProgressTestScreen> createState() =>
      _RouteProgressTestScreenState();
}

class _RouteProgressTestScreenState
    extends ConsumerState<RouteProgressTestScreen> {
  static const LatLon _testDestination = LatLon(
    latitude: 32.4130,
    longitude: 35.3433,
  );

  static const int _lookAheadPoints = 5;

  final RouteProgressService _routeProgressService =
      RouteProgressService();

  bool _isLoading = false;

  String? _errorMessage;

  LatLon? _currentLocation;

  RouteResult? _route;

  int? _nearestIndex;

  int? _targetIndex;

  LatLon? _targetPoint;

  Future<void> _runTest() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentLocation = null;
      _route = null;
      _nearestIndex = null;
      _targetIndex = null;
      _targetPoint = null;
    });

    try {
      // ==================================================
      // 1. GET CURRENT GPS LOCATION
      // ==================================================

      final locationService =
          ref.read(locationServiceProvider);

      final currentLocation =
          await locationService.getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = currentLocation;
      });

      // ==================================================
      // 2. CALCULATE REAL OSRM ROUTE
      // ==================================================

      final routingService =
          ref.read(routingServiceProvider);

      final route = await routingService.computeRoute(
        origin: currentLocation,
        destination: _testDestination,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _route = route;
      });

      // ==================================================
      // 3. FIND NEAREST POINT ON THE ROUTE
      // ==================================================

      final nearestIndex =
          _routeProgressService.findNearestPointIndex(
        currentPosition: currentLocation,
        polyline: route.polyline,
      );

      // ==================================================
      // 4. GET POINT AHEAD OF USER
      // ==================================================

      final targetIndex = (nearestIndex + _lookAheadPoints)
          .clamp(
            0,
            route.polyline.length - 1,
          );

      final targetPoint =
          route.polyline[targetIndex];

      if (!mounted) {
        return;
      }

      setState(() {
        _nearestIndex = nearestIndex;
        _targetIndex = targetIndex;
        _targetPoint = targetPoint;
      });
    } on LocationFailure catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
      });
    } on RoutingFailure catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
      });
    } on RouteProgressFailure catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

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
        title: const Text('Route Progress Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ==================================================
            // TEST DESTINATION
            // ==================================================

            const Text(
              'Test Destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Latitude: ${_testDestination.latitude}\n'
              'Longitude: ${_testDestination.longitude}',
            ),

            const SizedBox(height: 20),

            // ==================================================
            // BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _runTest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child: Text(
                    _isLoading
                        ? 'Getting GPS + Route...'
                        : 'Get GPS + Route Progress',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // ERROR
            // ==================================================

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
              ),

            // ==================================================
            // CURRENT GPS
            // ==================================================

            if (_currentLocation != null) ...[
              const Divider(height: 32),

              const Text(
                'Current GPS',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Latitude: '
                '${_currentLocation!.latitude}',
              ),

              Text(
                'Longitude: '
                '${_currentLocation!.longitude}',
              ),
            ],

            // ==================================================
            // ROUTE INFORMATION
            // ==================================================

            if (_route != null) ...[
              const Divider(height: 32),

              const Text(
                'Real OSRM Route',
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
                'Polyline points: '
                '${_route!.polyline.length}',
              ),
            ],

            // ==================================================
            // ROUTE PROGRESS
            // ==================================================

            if (_nearestIndex != null) ...[
              const Divider(height: 32),

              const Text(
                'Route Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Nearest route index: $_nearestIndex',
              ),

              Text(
                'Look-ahead points: $_lookAheadPoints',
              ),

              Text(
                'Target route index: $_targetIndex',
              ),
            ],

            // ==================================================
            // TARGET POINT
            // ==================================================

            if (_targetPoint != null) ...[
              const SizedBox(height: 16),

              const Text(
                'Next Target Point',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Latitude: '
                '${_targetPoint!.latitude}',
              ),

              Text(
                'Longitude: '
                '${_targetPoint!.longitude}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}