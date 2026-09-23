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
  // ================================================================
  // TEST DESTINATION
  // ================================================================

  static const LatLon _testDestination = LatLon(
    latitude: 32.450504351029885,
    longitude: 35.29032163919892,
  );

  // ================================================================
  // ROUTE PROGRESS
  // ================================================================

  static const double _lookAheadMeters = 10.0;

  final RouteProgressService _routeProgressService =
      RouteProgressService();

  bool _isLoading = false;

  String? _errorMessage;

  LatLon? _currentLocation;

  RouteResult? _route;

  int? _nearestIndex;

  int? _targetIndex;

  LatLon? _targetPoint;

  double? _distanceFromRoute;

  double? _distanceAhead;

  // ================================================================
  // RUN TEST
  // ================================================================

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

      _distanceFromRoute = null;
      _distanceAhead = null;
    });

    try {
      // ============================================================
      // 1. GET CURRENT GPS LOCATION
      // ============================================================

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

      // ============================================================
      // 2. CALCULATE REAL OSRM WALKING ROUTE
      // ============================================================

      final routingService =
          ref.read(routingServiceProvider);

      final route =
          await routingService.computeRoute(
        origin: currentLocation,
        destination: _testDestination,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _route = route;
      });

      // ============================================================
      // 3. FIND NEAREST POINT ON ROUTE
      // ============================================================

      final nearestIndex =
          _routeProgressService.findNearestPointIndex(
        currentPosition: currentLocation,
        polyline: route.polyline,
      );

      // ============================================================
      // 4. FIND TARGET 10 METERS AHEAD ON ROUTE
      // ============================================================

      final target =
          _routeProgressService.getNextTarget(
        currentPosition: currentLocation,
        route: route,
        lookAheadMeters: _lookAheadMeters,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearestIndex = nearestIndex;

        _targetIndex = target.index;

        _targetPoint = target.point;

        _distanceFromRoute =
            target.distanceFromRouteMeters;

        _distanceAhead =
            target.distanceAheadMeters;
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
        _errorMessage =
            'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route Progress Test',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ======================================================
            // TEST DESTINATION
            // ======================================================

            const Text(
              'Test Destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Latitude: '
              '${_testDestination.latitude}\n'
              'Longitude: '
              '${_testDestination.longitude}',
            ),

            const SizedBox(height: 20),

            // ======================================================
            // LOOK-AHEAD
            // ======================================================

            const Text(
              'Navigation Target',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'The system looks 10 meters ahead '
              'along the actual walking route.',
            ),

            const SizedBox(height: 20),

            // ======================================================
            // BUTTON
            // ======================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _runTest,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
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

            // ======================================================
            // ERROR
            // ======================================================

            if (_errorMessage != null)
              Container(
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
              ),

            // ======================================================
            // CURRENT GPS
            // ======================================================

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

            // ======================================================
            // ROUTE INFORMATION
            // ======================================================

            if (_route != null) ...[
              const Divider(height: 32),

              const Text(
                'Real OSRM Walking Route',
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

            // ======================================================
            // ROUTE PROGRESS
            // ======================================================

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
                'Nearest route segment: '
                '$_nearestIndex',
              ),

              const SizedBox(height: 6),

              Text(
                'Look-ahead distance: '
                '${_distanceAhead?.toStringAsFixed(2) ?? '--'} m',
              ),

              const SizedBox(height: 6),

              Text(
                'Distance from route: '
                '${_distanceFromRoute?.toStringAsFixed(2) ?? '--'} m',
              ),

              const SizedBox(height: 6),

              Text(
                'Target route segment: '
                '$_targetIndex',
              ),
            ],

            // ======================================================
            // TARGET POINT
            // ======================================================

            if (_targetPoint != null) ...[
              const Divider(height: 32),

              const Text(
                'Next Target Point',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Latitude: '
                '${_targetPoint!.latitude}',
              ),

              Text(
                'Longitude: '
                '${_targetPoint!.longitude}',
              ),

              const SizedBox(height: 12),

              Container(
                padding:
                    const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Text(
                  'Target is approximately '
                  '${_distanceAhead?.toStringAsFixed(1) ?? '--'} '
                  'meters ahead on the route.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}