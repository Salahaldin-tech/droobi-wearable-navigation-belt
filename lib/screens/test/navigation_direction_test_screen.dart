import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';
import '../../models/navigation_direction.dart';
import '../../models/route_result.dart';
import '../../services/location/gps_filter_service.dart';
import '../../services/location/location_service.dart';
import '../../services/navigation/compass_service.dart';
import '../../services/navigation/direction_calculator.dart';
import '../../services/navigation/route_progress_service.dart';
import '../../services/routing/routing_service.dart';
import '../../state/location_notifier.dart';
import '../../state/routing_notifier.dart';

class NavigationDirectionTestScreen
    extends ConsumerStatefulWidget {
  const NavigationDirectionTestScreen({
    super.key,
  });

  @override
  ConsumerState<NavigationDirectionTestScreen> createState() =>
      _NavigationDirectionTestScreenState();
}

class _NavigationDirectionTestScreenState
    extends ConsumerState<NavigationDirectionTestScreen> {
  // ================================================================
  // TEST DESTINATION
  // ================================================================

  static const LatLon _testDestination = LatLon(
    latitude: 32.462187947498116,
    longitude: 35.29858848014951,
  );

  // ================================================================
  // NAVIGATION CONFIGURATION
  // ================================================================

  static const double _lookAheadMeters = 10.0;

  // ================================================================
  // SERVICES
  // ================================================================

  final GpsFilterService _gpsFilterService =
      GpsFilterService();

  final RouteProgressService _routeProgressService =
      RouteProgressService();

  final DirectionCalculator _directionCalculator =
      DirectionCalculator();

  // IMPORTANT:
  // We intentionally use CompassService directly.
  // There is NO compassServiceProvider.
  // There is NO compass_notifier.dart dependency.

  final CompassService _compassService =
      CompassService();

  StreamSubscription<double>? _compassSubscription;

  // ================================================================
  // STATE
  // ================================================================

  bool _isLoading = false;

  bool _isNavigationReady = false;

  String? _errorMessage;

  LocationFix? _rawFix;

  LocationFix? _filteredFix;

  RouteResult? _route;

  LatLon? _targetPoint;

  double? _distanceFromRoute;

  double? _targetBearing;

  double? _heading;

  double? _relativeAngle;

  NavigationDirection? _direction;

  // ================================================================
  // START TEST
  // ================================================================

  Future<void> _startTest() async {
    if (_isLoading) {
      return;
    }

    await _stopCompass();

    setState(() {
      _isLoading = true;
      _isNavigationReady = false;

      _errorMessage = null;

      _rawFix = null;
      _filteredFix = null;

      _route = null;

      _targetPoint = null;
      _distanceFromRoute = null;

      _targetBearing = null;
      _heading = null;
      _relativeAngle = null;

      _direction = null;
    });

    try {
      // ============================================================
      // 1. GET GPS FIX
      // ============================================================

      final locationService =
          ref.read(locationServiceProvider);

      final rawFix =
          await locationService.getCurrentLocationFix();

      if (!mounted) {
        return;
      }

      setState(() {
        _rawFix = rawFix;
      });

      // ============================================================
      // 2. GPS QUALITY FILTER
      // ============================================================

      final filteredFix =
          _gpsFilterService.process(rawFix);

      if (filteredFix == null) {
        throw const LocationFailure(
          LocationErrorType.unavailable,
          'GPS position was rejected by the quality filter.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _filteredFix = filteredFix;
      });

      // ============================================================
      // 3. CALCULATE OSRM WALKING ROUTE
      // ============================================================

      final routingService =
          ref.read(routingServiceProvider);

      final route =
          await routingService.computeRoute(
        origin: filteredFix.position,
        destination: _testDestination,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _route = route;
      });

      // ============================================================
      // 4. GET 10-METER TARGET
      // ============================================================

      final target =
          _routeProgressService.getNextTarget(
        currentPosition: filteredFix.position,
        route: route,
        lookAheadMeters: _lookAheadMeters,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _targetPoint = target.point;
        _distanceFromRoute =
            target.distanceFromRouteMeters;
      });

      // ============================================================
      // 5. GET INITIAL COMPASS HEADING
      // ============================================================

      final initialHeading =
          await _compassService.getCurrentHeading();

      if (!mounted) {
        return;
      }

      // ============================================================
      // 6. CALCULATE INITIAL DIRECTION
      // ============================================================

      _updateDirection(
        filteredFix.position,
        target.point,
        initialHeading,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isNavigationReady = true;
      });

      // ============================================================
      // 7. LISTEN TO LIVE COMPASS
      // ============================================================

      _compassSubscription =
          _compassService.headingStream.listen(
        (heading) {
          if (!mounted ||
              _filteredFix == null ||
              _targetPoint == null) {
            return;
          }

          _updateDirection(
            _filteredFix!.position,
            _targetPoint!,
            heading,
          );
        },
      );
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
    } on CompassFailure catch (e) {
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

  // ================================================================
  // UPDATE DIRECTION
  // ================================================================

  void _updateDirection(
    LatLon currentPosition,
    LatLon targetPoint,
    double heading,
  ) {
    final bearing =
        _directionCalculator.calculateBearing(
      from: currentPosition,
      to: targetPoint,
    );

    final relativeAngle =
        _directionCalculator.normalizeAngle(
      bearing - heading,
    );

    final direction =
        _directionCalculator.directionFromAngle(
      relativeAngle,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _targetBearing = bearing;
      _heading = heading;
      _relativeAngle = relativeAngle;
      _direction = direction;
    });
  }

  // ================================================================
  // STOP COMPASS
  // ================================================================

  Future<void> _stopCompass() async {
    await _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Navigation Direction Test',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                '${_testDestination.latitude}',
              ),

              Text(
                'Longitude: '
                '${_testDestination.longitude}',
              ),

              const SizedBox(height: 20),

              // ======================================================
              // LOOK AHEAD
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
                'Target is 10 meters ahead on the '
                'actual OSRM walking route.',
              ),

              const SizedBox(height: 20),

              // ======================================================
              // START BUTTON
              // ======================================================

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _startTest,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: Text(
                      _isLoading
                          ? 'Calculating Navigation...'
                          : 'Start Navigation Test',
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
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(
                      alpha: 0.08,
                    ),
                    borderRadius:
                        BorderRadius.circular(12),
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
              // RAW GPS
              // ======================================================

              if (_rawFix != null) ...[
                const Divider(height: 32),

                const Text(
                  'RAW GPS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Latitude: '
                  '${_rawFix!.position.latitude}',
                ),

                Text(
                  'Longitude: '
                  '${_rawFix!.position.longitude}',
                ),

                Text(
                  'Accuracy: '
                  '${_rawFix!.accuracyMeters.toStringAsFixed(1)} m',
                ),
              ],

              // ======================================================
              // FILTERED GPS
              // ======================================================

              if (_filteredFix != null) ...[
                const Divider(height: 32),

                const Text(
                  'FILTERED GPS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Latitude: '
                  '${_filteredFix!.position.latitude}',
                ),

                Text(
                  'Longitude: '
                  '${_filteredFix!.position.longitude}',
                ),

                Text(
                  'Accuracy: '
                  '${_filteredFix!.accuracyMeters.toStringAsFixed(1)} m',
                ),
              ],

              // ======================================================
              // ROUTE
              // ======================================================

              if (_route != null) ...[
                const Divider(height: 32),

                const Text(
                  'OSRM WALKING ROUTE',
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
                  'OSRM Duration: '
                  '${_route!.durationSeconds.toStringAsFixed(0)} s',
                ),

                Text(
                  'Polyline Points: '
                  '${_route!.polyline.length}',
                ),
              ],

              // ======================================================
              // TARGET
              // ======================================================

              if (_targetPoint != null) ...[
                const Divider(height: 32),

                const Text(
                  '10-METER TARGET',
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

                if (_distanceFromRoute != null)
                  Text(
                    'Distance From Route: '
                    '${_distanceFromRoute!.toStringAsFixed(2)} m',
                  ),
              ],

              // ======================================================
              // COMPASS
              // ======================================================

              if (_heading != null) ...[
                const Divider(height: 32),

                const Text(
                  'COMPASS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Heading: '
                  '${_heading!.toStringAsFixed(1)}°',
                ),
              ],

              // ======================================================
              // BEARING
              // ======================================================

              if (_targetBearing != null) ...[
                const Divider(height: 32),

                const Text(
                  'TARGET BEARING',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Bearing: '
                  '${_targetBearing!.toStringAsFixed(1)}°',
                ),
              ],

              // ======================================================
              // RELATIVE ANGLE
              // ======================================================

              if (_relativeAngle != null) ...[
                const Divider(height: 32),

                const Text(
                  'RELATIVE ANGLE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Relative Angle: '
                  '${_relativeAngle!.toStringAsFixed(1)}°',
                ),
              ],

              // ======================================================
              // DIRECTION
              // ======================================================

              if (_direction != null) ...[
                const Divider(height: 32),

                const Text(
                  'DIRECTION',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(16),
                    color: Colors.blue
                        .withValues(alpha: 0.08),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _direction!
                            .name
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Command: '
                        '${_direction!.command}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ======================================================
              // STATUS
              // ======================================================

              if (_isNavigationReady) ...[
                const Divider(height: 32),

                const Text(
                  'STATUS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Navigation direction calculation '
                  'is active.',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}