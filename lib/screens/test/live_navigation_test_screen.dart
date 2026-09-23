import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/navigation_direction.dart';
import '../../models/lat_lon.dart';
import '../../services/navigation/navigation_service.dart';
import '../../state/navigation_notifier.dart';

class LiveNavigationTestScreen extends ConsumerStatefulWidget {
  const LiveNavigationTestScreen({
    super.key,
  });

  @override
  ConsumerState<LiveNavigationTestScreen> createState() =>
      _LiveNavigationTestScreenState();
}

class _LiveNavigationTestScreenState
    extends ConsumerState<LiveNavigationTestScreen> {
  // ================================================================
  // TEST DESTINATION
  // ================================================================

  static const LatLon _testDestination = LatLon(
    latitude: 32.462187947498116,
    longitude: 35.29858848014951,
  );

  // ================================================================
  // STATE
  // ================================================================

  NavigationSnapshot? _snapshot;

  StreamSubscription<NavigationSnapshot>? _snapshotSubscription;

  bool _isStarting = false;

  String? _errorMessage;

  // ================================================================
  // NAVIGATION SERVICE
  // ================================================================

  NavigationService get _navigationService =>
      ref.read(navigationServiceProvider);

  // ================================================================
  // START
  // ================================================================

  Future<void> _startNavigation() async {
    if (_isStarting || _navigationService.isNavigating) {
      return;
    }

    await _snapshotSubscription?.cancel();
    _snapshotSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
      _snapshot = null;
    });

    _snapshotSubscription =
        _navigationService.snapshots.listen(
      (snapshot) {
        if (!mounted) {
          return;
        }

        setState(() {
          _snapshot = snapshot;
          _errorMessage = snapshot.errorMessage;
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = error.toString();
        });
      },
    );

    try {
      await _navigationService.start(
        destination: _testDestination,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  // ================================================================
  // STOP
  // ================================================================

  Future<void> _stopNavigation() async {
    await _navigationService.stop();

    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = _navigationService.snapshot;
      _errorMessage = null;
      _isStarting = false;
    });
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    _navigationService.stop();

    super.dispose();
  }

  // ================================================================
  // FORMAT HELPERS
  // ================================================================

  String _stateText(NavigationState state) {
    switch (state) {
      case NavigationState.idle:
        return 'IDLE';

      case NavigationState.starting:
        return 'STARTING';

      case NavigationState.navigating:
        return 'NAVIGATING';

      case NavigationState.gpsUnavailable:
        return 'GPS UNAVAILABLE';

      case NavigationState.routeUnavailable:
        return 'ROUTE UNAVAILABLE';

      case NavigationState.recovering:
        return 'RECOVERING';

      case NavigationState.arrived:
        return 'ARRIVED';

      case NavigationState.stopped:
        return 'STOPPED';
    }
  }

  Color _stateColor(NavigationState state) {
    switch (state) {
      case NavigationState.navigating:
        return Colors.green;

      case NavigationState.arrived:
        return Colors.blue;

      case NavigationState.starting:
      case NavigationState.recovering:
        return Colors.orange;

      case NavigationState.gpsUnavailable:
      case NavigationState.routeUnavailable:
        return Colors.red;

      case NavigationState.idle:
      case NavigationState.stopped:
        return Colors.grey;
    }
  }

  String _coordinateText(LatLon? position) {
    if (position == null) {
      return '—';
    }

    return '${position.latitude.toStringAsFixed(7)}, '
        '${position.longitude.toStringAsFixed(7)}';
  }

  String _metersText(double? value) {
    if (value == null) {
      return '—';
    }

    return '${value.toStringAsFixed(1)} m';
  }

  String _degreesText(double? value) {
    if (value == null) {
      return '—';
    }

    return '${value.toStringAsFixed(1)}°';
  }

  String _directionText(NavigationDirection? direction) {
    if (direction == null) {
      return '—';
    }

    return direction.name.toUpperCase();
  }

  // ================================================================
  // INFO ROW
  // ================================================================

  Widget _infoRow(
    String label,
    String value, {
    bool important = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    important
                        ? FontWeight.bold
                        : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SECTION
  // ================================================================

  Widget _section(
    String title,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...children,
          ],
        ),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    final bool isNavigating =
        _navigationService.isNavigating;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Navigation Test',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ==========================================================
          // DESTINATION
          // ==========================================================

          _section(
            'Test Destination',
            [
              _infoRow(
                'Latitude',
                _testDestination.latitude
                    .toStringAsFixed(7),
              ),
              _infoRow(
                'Longitude',
                _testDestination.longitude
                    .toStringAsFixed(7),
              ),
            ],
          ),

          // ==========================================================
          // START / STOP
          // ==========================================================

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isStarting
                      ? null
                      : isNavigating
                          ? _stopNavigation
                          : _startNavigation,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                child: Text(
                  _isStarting
                      ? 'Starting...'
                      : isNavigating
                          ? 'Stop Navigation'
                          : 'Start Live Navigation',
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ==========================================================
          // ERROR
          // ==========================================================

          if (_errorMessage != null)
            Card(
              color: Colors.red.withValues(
                alpha: 0.08,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

          // ==========================================================
          // NO DATA YET
          // ==========================================================

          if (snapshot == null)
            _section(
              'Navigation',
              const [
                Text(
                  'Press "Start Live Navigation" '
                  'to begin the live test.',
                ),
              ],
            ),

          // ==========================================================
          // LIVE DATA
          // ==========================================================

          if (snapshot != null) ...[
            // ========================================================
            // STATE
            // ========================================================

            _section(
              'Navigation State',
              [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _stateColor(
                          snapshot.state,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Text(
                      _stateText(
                        snapshot.state,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                if (snapshot.errorMessage !=
                    null) ...[
                  const SizedBox(height: 12),
                  Text(
                    snapshot.errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],
              ],
            ),

            // ========================================================
            // GPS
            // ========================================================

            _section(
              'Live GPS',
              [
                _infoRow(
                  'Current Position',
                  _coordinateText(
                    snapshot.currentPosition,
                  ),
                  important: true,
                ),
                _infoRow(
                  'GPS Accuracy',
                  _metersText(
                    snapshot.accuracyMeters,
                  ),
                ),
              ],
            ),

            // ========================================================
            // ROUTE
            // ========================================================

            _section(
              'Route',
              [
                _infoRow(
                  'Status',
                  snapshot.route == null
                      ? 'No route'
                      : 'Route loaded',
                  important: true,
                ),
                _infoRow(
                  'Route Distance',
                  snapshot.route == null
                      ? '—'
                      : _metersText(
                          snapshot
                              .route!
                              .distanceMeters,
                        ),
                ),
                _infoRow(
                  'Route Duration',
                  snapshot.route == null
                      ? '—'
                      : '${snapshot.route!.durationSeconds.toStringAsFixed(0)} s',
                ),
                _infoRow(
                  'Route Points',
                  snapshot.route == null
                      ? '—'
                      : snapshot
                          .route!
                          .polyline
                          .length
                          .toString(),
                ),
              ],
            ),

            // ========================================================
            // TARGET
            // ========================================================

            _section(
              '10 Meter Navigation Target',
              [
                _infoRow(
                  'Target Point',
                  _coordinateText(
                    snapshot.targetPoint,
                  ),
                  important: true,
                ),
                _infoRow(
                  'Distance From Route',
                  _metersText(
                    snapshot.distanceFromRouteMeters,
                  ),
                ),
              ],
            ),

            // ========================================================
            // COMPASS
            // ========================================================

            _section(
              'Compass',
              [
                _infoRow(
                  'Phone Heading',
                  _degreesText(
                    snapshot.heading,
                  ),
                  important: true,
                ),
              ],
            ),

            // ========================================================
            // DIRECTION
            // ========================================================

            _section(
              'Direction Calculation',
              [
                _infoRow(
                  'Target Bearing',
                  _degreesText(
                    snapshot.targetBearing,
                  ),
                ),
                _infoRow(
                  'Relative Angle',
                  _degreesText(
                    snapshot.relativeAngle,
                  ),
                ),
                _infoRow(
                  'Direction',
                  _directionText(
                    snapshot.direction,
                  ),
                  important: true,
                ),
                _infoRow(
                  'Command',
                  snapshot.command ?? '—',
                  important: true,
                ),
              ],
            ),

            // ========================================================
            // ARRIVED
            // ========================================================

            if (snapshot.state ==
                NavigationState.arrived)
              Card(
                color: Colors.green.withValues(
                  alpha: 0.10,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 56,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'ARRIVED',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 24,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}