import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../models/route_result.dart';
import '../../services/location/location_service.dart';
import '../../services/navigation/compass_service.dart';
import '../../services/navigation/direction_calculator.dart';
import '../../services/navigation/route_progress_service.dart';
import '../../services/routing/routing_service.dart';
import '../../state/compass_notifier.dart';
import '../../state/location_notifier.dart';
import '../../state/routing_notifier.dart';

class NavigationDirectionTestScreen extends ConsumerStatefulWidget {
  const NavigationDirectionTestScreen({
    super.key,
  });

  @override
  ConsumerState<NavigationDirectionTestScreen> createState() =>
      _NavigationDirectionTestScreenState();
}

class _NavigationDirectionTestScreenState
    extends ConsumerState<NavigationDirectionTestScreen> {
  // ------------------------------------------------------
  // TEST DESTINATION
  // ------------------------------------------------------

  static const LatLon _testDestination = LatLon(
  latitude: 32.45076561146529,
  longitude: 35.29026575356918,
);

  // ------------------------------------------------------
  // SERVICES
  // ------------------------------------------------------

  final RouteProgressService _routeProgressService =
      RouteProgressService();

  final DirectionCalculator _directionCalculator =
      DirectionCalculator();

  // ------------------------------------------------------
  // STATE
  // ------------------------------------------------------

  bool _isLoading = false;

  String? _errorMessage;

  LatLon? _currentLocation;

  RouteResult? _route;

  int? _nearestIndex;

  int? _targetIndex;

  LatLon? _targetPoint;

  double? _targetBearing;

  double? _phoneHeading;

  double? _relativeAngle;

  NavigationDirection? _direction;

  StreamSubscription<double>? _compassSubscription;

  static const int _lookAheadPoints = 5;

  // ------------------------------------------------------
  // START TEST
  // ------------------------------------------------------

  Future<void> _startTest() async {
    if (_isLoading) {
      return;
    }

    await _stopCompass();

    setState(() {
      _isLoading = true;
      _errorMessage = null;

      _currentLocation = null;
      _route = null;

      _nearestIndex = null;
      _targetIndex = null;
      _targetPoint = null;

      _targetBearing = null;
      _phoneHeading = null;
      _relativeAngle = null;
      _direction = null;
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

      if (route.polyline.isEmpty) {
        throw const NavigationDirectionTestFailure(
          'OSRM returned an empty route.',
        );
      }

      setState(() {
        _route = route;
      });

      // ==================================================
      // 3. FIND NEAREST ROUTE POINT
      // ==================================================

      final nearestIndex =
          _routeProgressService.findNearestPointIndex(
        currentPosition: currentLocation,
        polyline: route.polyline,
      );

      // ==================================================
      // 4. SELECT LOOK-AHEAD TARGET
      // ==================================================

      final targetIndex = (nearestIndex + _lookAheadPoints)
          .clamp(
            0,
            route.polyline.length - 1,
          );

      final targetPoint =
          route.polyline[targetIndex];

      // ==================================================
      // 5. CALCULATE BEARING TO TARGET
      // ==================================================

      final targetBearing =
          _directionCalculator.calculateBearing(
        from: currentLocation,
        to: targetPoint,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _nearestIndex = nearestIndex;
        _targetIndex = targetIndex;
        _targetPoint = targetPoint;
        _targetBearing = targetBearing;
        _isLoading = false;
      });

      // ==================================================
      // 6. START LIVE COMPASS
      // ==================================================

      _startCompass();
    } on LocationFailure catch (e) {
      _showError(e.message);
    } on RoutingFailure catch (e) {
      _showError(e.message);
    } on RouteProgressFailure catch (e) {
      _showError(e.message);
    } on CompassFailure catch (e) {
      _showError(e.message);
    } on NavigationDirectionTestFailure catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unexpected error: $e');
    }
  }

  // ------------------------------------------------------
  // START COMPASS
  // ------------------------------------------------------

  void _startCompass() {
    final compassService =
        ref.read(compassServiceProvider);

    _compassSubscription =
        compassService.headingStream.listen(
      _handleHeading,
      onError: (Object error) {
        _showError(
          'Compass error: $error',
        );
      },
    );
  }

  // ------------------------------------------------------
  // HANDLE LIVE HEADING
  // ------------------------------------------------------

  void _handleHeading(double heading) {
    if (!mounted) {
      return;
    }

    final currentLocation = _currentLocation;
    final targetPoint = _targetPoint;

    if (currentLocation == null ||
        targetPoint == null) {
      return;
    }

    // Recalculate bearing in case the user moved
    // slightly while testing.
    final targetBearing =
        _directionCalculator.calculateBearing(
      from: currentLocation,
      to: targetPoint,
    );

    final relativeAngle =
        _directionCalculator.normalizeAngle(
      targetBearing - heading,
    );

    final direction =
        _directionCalculator.directionFromAngle(
      relativeAngle,
    );

    setState(() {
      _phoneHeading = heading;
      _targetBearing = targetBearing;
      _relativeAngle = relativeAngle;
      _direction = direction;
    });
  }

  // ------------------------------------------------------
  // STOP COMPASS
  // ------------------------------------------------------

  Future<void> _stopCompass() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  // ------------------------------------------------------
  // ERROR
  // ------------------------------------------------------

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  // ------------------------------------------------------
  // DIRECTION NAME
  // ------------------------------------------------------

  String _directionName(
    NavigationDirection direction,
  ) {
    switch (direction) {
      case NavigationDirection.forward:
        return 'FORWARD';

      case NavigationDirection.forwardRight:
        return 'FORWARD RIGHT';

      case NavigationDirection.right:
        return 'RIGHT';

      case NavigationDirection.backRight:
        return 'BACK RIGHT';

      case NavigationDirection.back:
        return 'BACK';

      case NavigationDirection.backLeft:
        return 'BACK LEFT';

      case NavigationDirection.left:
        return 'LEFT';

      case NavigationDirection.forwardLeft:
        return 'FORWARD LEFT';
    }
  }

  // ------------------------------------------------------
  // COMPASS CARDINAL DIRECTION
  // ------------------------------------------------------

  String _compassName(double heading) {
    if (heading >= 337.5 || heading < 22.5) {
      return 'NORTH';
    }

    if (heading >= 22.5 && heading < 67.5) {
      return 'NORTHEAST';
    }

    if (heading >= 67.5 && heading < 112.5) {
      return 'EAST';
    }

    if (heading >= 112.5 && heading < 157.5) {
      return 'SOUTHEAST';
    }

    if (heading >= 157.5 && heading < 202.5) {
      return 'SOUTH';
    }

    if (heading >= 202.5 && heading < 247.5) {
      return 'SOUTHWEST';
    }

    if (heading >= 247.5 && heading < 292.5) {
      return 'WEST';
    }

    return 'NORTHWEST';
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------
  // UI
  // ------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Navigation Direction Test',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ==================================================
            // DESTINATION
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
            // START BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading ? null : _startTest,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child: Text(
                    _isLoading
                        ? 'Getting GPS + Route...'
                        : 'Start Navigation Test',
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

            // ==================================================
            // GPS
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
            // ROUTE
            // ==================================================

            if (_route != null) ...[
              const Divider(height: 32),

              const Text(
                'OSRM Route',
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
                '${_route!.durationSeconds.toStringAsFixed(0)} s',
              ),

              Text(
                'Polyline points: '
                '${_route!.polyline.length}',
              ),
            ],

            // ==================================================
            // TARGET
            // ==================================================

            if (_targetPoint != null) ...[
              const Divider(height: 32),

              const Text(
                'Navigation Target',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Nearest index: $_nearestIndex',
              ),

              Text(
                'Target index: $_targetIndex',
              ),

              const SizedBox(height: 8),

              Text(
                'Target latitude: '
                '${_targetPoint!.latitude}',
              ),

              Text(
                'Target longitude: '
                '${_targetPoint!.longitude}',
              ),

              const SizedBox(height: 8),

              Text(
                'Target bearing: '
                '${_targetBearing?.toStringAsFixed(1) ?? '--'}°',
              ),
            ],

            // ==================================================
            // COMPASS
            // ==================================================

            if (_phoneHeading != null) ...[
              const Divider(height: 32),

              const Text(
                'Phone Compass',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Heading: '
                '${_phoneHeading!.toStringAsFixed(1)}°',
              ),

              Text(
                'Direction: '
                '${_compassName(_phoneHeading!)}',
              ),

              const SizedBox(height: 8),

              Text(
                'Relative angle: '
                '${_relativeAngle!.toStringAsFixed(1)}°',
              ),
            ],

            // ==================================================
            // FINAL 8-DIRECTION RESULT
            // ==================================================

            if (_direction != null) ...[
              const Divider(height: 32),

              const Text(
                '8-Direction Result',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black12,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _directionName(_direction!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Command: '
                      '${_direction!.command}',
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NavigationDirectionTestFailure
    implements Exception {
  const NavigationDirectionTestFailure(
    this.message,
  );

  final String message;

  @override
  String toString() => message;
}