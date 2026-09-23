import 'dart:async';

import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';
import '../../models/navigation_direction.dart';
import '../../models/route_result.dart';
import '../location/gps_filter_service.dart';
import '../location/location_service.dart';
import '../routing/routing_service.dart';
import 'compass_service.dart';
import 'direction_calculator.dart';
import 'route_progress_service.dart';

enum NavigationState {
  idle,
  starting,
  navigating,
  gpsUnavailable,
  routeUnavailable,
  recovering,
  arrived,
  stopped,
}

class NavigationSnapshot {
  const NavigationSnapshot({
    required this.state,
    this.currentPosition,
    this.accuracyMeters,
    this.route,
    this.targetPoint,
    this.distanceFromRouteMeters,
    this.targetBearing,
    this.heading,
    this.relativeAngle,
    this.direction,
    this.errorMessage,
  });

  final NavigationState state;

  final LatLon? currentPosition;
  final double? accuracyMeters;

  final RouteResult? route;

  final LatLon? targetPoint;

  final double? distanceFromRouteMeters;

  final double? targetBearing;

  final double? heading;

  final double? relativeAngle;

  final NavigationDirection? direction;

  final String? errorMessage;

  String? get command => direction?.command;
}

class NavigationService {
  NavigationService({
    required LocationService locationService,
    required RoutingService routingService,
    required CompassService compassService,
    GpsFilterService? gpsFilterService,
    RouteProgressService? routeProgressService,
    DirectionCalculator? directionCalculator,
    this.lookAheadMeters = 10.0,
    this.arrivalDistanceMeters = 8.0,
  })  : _locationService = locationService,
        _routingService = routingService,
        _compassService = compassService,
        _gpsFilterService =
            gpsFilterService ?? GpsFilterService(),
        _routeProgressService =
            routeProgressService ?? RouteProgressService(),
        _directionCalculator =
            directionCalculator ?? DirectionCalculator();

  final LocationService _locationService;

  final RoutingService _routingService;

  final CompassService _compassService;

  final GpsFilterService _gpsFilterService;

  final RouteProgressService _routeProgressService;

  final DirectionCalculator _directionCalculator;

  final double lookAheadMeters;

  final double arrivalDistanceMeters;

  StreamSubscription<LocationFix>? _locationSubscription;

  StreamSubscription<double>? _compassSubscription;

  final StreamController<NavigationSnapshot>
      _snapshotController =
      StreamController<NavigationSnapshot>.broadcast();

  NavigationSnapshot _snapshot =
      const NavigationSnapshot(
    state: NavigationState.idle,
  );

  RouteResult? _route;

  LatLon? _destination;

  LocationFix? _lastAcceptedFix;

  double? _latestHeading;

  bool _isStarting = false;

  bool _isNavigating = false;

  bool _isDisposed = false;

  Stream<NavigationSnapshot> get snapshots =>
      _snapshotController.stream;

  NavigationSnapshot get snapshot => _snapshot;

  bool get isNavigating => _isNavigating;

  // ================================================================
  // START NAVIGATION
  // ================================================================

  Future<void> start({
    required LatLon destination,
  }) async {
    if (_isDisposed) {
      throw StateError(
        'NavigationService has been disposed.',
      );
    }

    if (_isStarting || _isNavigating) {
      return;
    }

    _isStarting = true;

    await stop();

    _destination = destination;

    _publish(
      const NavigationSnapshot(
        state: NavigationState.starting,
      ),
    );

    try {
      // ------------------------------------------------------------
      // 1. GET INITIAL GPS
      // ------------------------------------------------------------

      final initialFix =
          await _locationService
              .getCurrentLocationFix();

      final filteredFix =
          _gpsFilterService.process(
        initialFix,
      );

      if (filteredFix == null) {
        throw const NavigationFailure(
          'Initial GPS position was rejected by '
          'the GPS quality filter.',
        );
      }

      _lastAcceptedFix = filteredFix;

      // ------------------------------------------------------------
      // 2. CALCULATE INITIAL ROUTE
      // ------------------------------------------------------------

      final route =
          await _routingService.computeRoute(
        origin: filteredFix.position,
        destination: destination,
      );

      if (route.polyline.isEmpty) {
        throw const NavigationFailure(
          'The routing service returned an empty route.',
        );
      }

      _route = route;

      // ------------------------------------------------------------
      // 3. START COMPASS
      // ------------------------------------------------------------

      final initialHeading =
          await _compassService
              .getCurrentHeading();

      _latestHeading = initialHeading;

      // ------------------------------------------------------------
      // 4. START LIVE STREAMS
      // ------------------------------------------------------------

      _isNavigating = true;

      _publish(
        NavigationSnapshot(
          state: NavigationState.navigating,
          currentPosition:
              filteredFix.position,
          accuracyMeters:
              filteredFix.accuracyMeters,
          route: route,
        ),
      );

      _startCompassStream();

      _startLocationStream();

      // ------------------------------------------------------------
      // 5. CALCULATE FIRST DIRECTION
      // ------------------------------------------------------------

      _updateNavigation(
        filteredFix,
        initialHeading,
      );
    } catch (e) {
      _isNavigating = false;

      _publish(
        NavigationSnapshot(
          state: NavigationState.routeUnavailable,
          errorMessage: e.toString(),
        ),
      );

      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  // ================================================================
  // LIVE GPS
  // ================================================================

  void _startLocationStream() {
    _locationSubscription?.cancel();

    _locationSubscription =
        _locationService.locationFixStream.listen(
      _handleLocationFix,
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        _publish(
          NavigationSnapshot(
            state:
                NavigationState.gpsUnavailable,
            currentPosition:
                _lastAcceptedFix?.position,
            accuracyMeters:
                _lastAcceptedFix?.accuracyMeters,
            route: _route,
            heading: _latestHeading,
            errorMessage:
                error.toString(),
          ),
        );
      },
    );
  }

  void _handleLocationFix(
    LocationFix rawFix,
  ) {
    if (!_isNavigating || _route == null) {
      return;
    }

    final filteredFix =
        _gpsFilterService.process(
      rawFix,
    );

    if (filteredFix == null) {
      // Do not immediately stop navigation.
      // Simply ignore this GPS sample.
      return;
    }

    _lastAcceptedFix = filteredFix;

    final heading = _latestHeading;

    if (heading == null) {
      _publish(
        NavigationSnapshot(
          state: NavigationState.recovering,
          currentPosition:
              filteredFix.position,
          accuracyMeters:
              filteredFix.accuracyMeters,
          route: _route,
          errorMessage:
              'Waiting for compass heading.',
        ),
      );

      return;
    }

    _updateNavigation(
      filteredFix,
      heading,
    );
  }

  // ================================================================
  // LIVE COMPASS
  // ================================================================

  void _startCompassStream() {
    _compassSubscription?.cancel();

    _compassSubscription =
        _compassService.headingStream.listen(
      (heading) {
        if (!_isNavigating ||
            _lastAcceptedFix == null ||
            _route == null) {
          return;
        }

        _latestHeading = heading;

        _updateNavigation(
          _lastAcceptedFix!,
          heading,
        );
      },
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        _publish(
          NavigationSnapshot(
            state: NavigationState.recovering,
            currentPosition:
                _lastAcceptedFix?.position,
            accuracyMeters:
                _lastAcceptedFix?.accuracyMeters,
            route: _route,
            errorMessage:
                'Compass error: $error',
          ),
        );
      },
    );
  }

  // ================================================================
  // NAVIGATION CALCULATION
  // ================================================================

  void _updateNavigation(
    LocationFix fix,
    double heading,
  ) {
    final route = _route;

    if (route == null) {
      return;
    }

    final target =
        _routeProgressService.getNextTarget(
      currentPosition: fix.position,
      route: route,
      lookAheadMeters:
          lookAheadMeters,
    );

    // ------------------------------------------------------------
    // ARRIVAL CHECK
    // ------------------------------------------------------------

    final distanceToDestination =
        _routeProgressService.distanceBetween(
      fix.position,
      _destination!,
    );

    if (distanceToDestination <=
        arrivalDistanceMeters) {
      _publish(
        NavigationSnapshot(
          state: NavigationState.arrived,
          currentPosition:
              fix.position,
          accuracyMeters:
              fix.accuracyMeters,
          route: route,
          targetPoint:
              _destination,
          distanceFromRouteMeters:
              target.distanceFromRouteMeters,
          heading: heading,
        ),
      );

      _isNavigating = false;

      return;
    }

    // ------------------------------------------------------------
    // BEARING
    // ------------------------------------------------------------

    final bearing =
        _directionCalculator.calculateBearing(
      from: fix.position,
      to: target.point,
    );

    // ------------------------------------------------------------
    // RELATIVE ANGLE
    // ------------------------------------------------------------

    final relativeAngle =
        _directionCalculator.normalizeAngle(
      bearing - heading,
    );

    // ------------------------------------------------------------
    // 8-DIRECTION DECISION
    // ------------------------------------------------------------

    final direction =
        _directionCalculator.directionFromAngle(
      relativeAngle,
    );

    // ------------------------------------------------------------
    // PUBLISH
    // ------------------------------------------------------------

    _publish(
      NavigationSnapshot(
        state: NavigationState.navigating,
        currentPosition:
            fix.position,
        accuracyMeters:
            fix.accuracyMeters,
        route: route,
        targetPoint:
            target.point,
        distanceFromRouteMeters:
            target.distanceFromRouteMeters,
        targetBearing: bearing,
        heading: heading,
        relativeAngle: relativeAngle,
        direction: direction,
      ),
    );
  }

  // ================================================================
  // STOP
  // ================================================================

  Future<void> stop() async {
    _isNavigating = false;

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _compassSubscription?.cancel();
    _compassSubscription = null;

    _gpsFilterService.reset();

    _lastAcceptedFix = null;
    _latestHeading = null;
    _route = null;
    _destination = null;

    if (!_isDisposed) {
      _publish(
        const NavigationSnapshot(
          state: NavigationState.stopped,
        ),
      );
    }
  }

  // ================================================================
  // PUBLISH
  // ================================================================

  void _publish(
    NavigationSnapshot snapshot,
  ) {
    _snapshot = snapshot;

    if (!_snapshotController.isClosed) {
      _snapshotController.add(
        snapshot,
      );
    }
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  Future<void> dispose() async {
    _isDisposed = true;

    _isNavigating = false;

    await _locationSubscription?.cancel();
    await _compassSubscription?.cancel();

    await _snapshotController.close();
  }
}

class NavigationFailure implements Exception {
  const NavigationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}