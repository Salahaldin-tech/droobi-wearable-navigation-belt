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
import 'heading_estimator.dart';
import 'relative_direction_engine.dart';
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
    RoutingService? campusRoutingService,
    required CompassService compassService,
    GpsFilterService? gpsFilterService,
    GpsFilterService? campusGpsFilterService,
    RouteProgressService? routeProgressService,
    DirectionCalculator? directionCalculator,

    // --------------------------------------------------------------
    // ROUTE FOLLOWING
    // --------------------------------------------------------------
    //
    // null means RouteProgressService decides the look-ahead
    // adaptively according to the route and upcoming turns.
    //
    this.lookAheadMeters,

    this.arrivalDistanceMeters = 8.0,

    // --------------------------------------------------------------
    // COMPASS SMOOTHING
    // --------------------------------------------------------------

    this.compassSampleCount = 5,

    this.minimumHeadingChangeDegrees = 8.0,

    // --------------------------------------------------------------
    // DIRECTION STABILITY
    // --------------------------------------------------------------

    this.directionConfirmationSamples = 3,
  })  : _locationService = locationService,
        _routingService = routingService,
        _campusRoutingService = campusRoutingService,
        _compassService = compassService,
        _gpsFilterService =
            gpsFilterService ?? GpsFilterService(),
        _campusGpsFilterService =
            campusGpsFilterService ?? GpsFilterService(),
        _routeProgressService =
            routeProgressService ?? RouteProgressService(),
        _directionCalculator =
            directionCalculator ?? DirectionCalculator();

  final LocationService _locationService;

  final RoutingService _routingService;

  final RoutingService? _campusRoutingService;

  RoutingService? _activeRoutingService;

  bool _isCampusNavigation = false;
  bool _isRerouting = false;
  int _offRouteSamples = 0;
  DateTime? _lastCampusRerouteAt;

  static const double _campusOffRouteMinimumMeters = 12.0;
  static const int _campusOffRouteSamplesRequired = 2;
  static const Duration _campusRerouteCooldown = Duration(seconds: 5);

  final CompassService _compassService;

  final GpsFilterService _gpsFilterService;

  final GpsFilterService _campusGpsFilterService;

  GpsFilterService? _activeGpsFilterService;

  final RouteProgressService _routeProgressService;

  final DirectionCalculator _directionCalculator;

  // ================================================================
  // SETTINGS
  // ================================================================

  /// Optional fallback look-ahead.
  ///
  /// When null, RouteProgressService calculates the adaptive
  /// look-ahead automatically.
  final double? lookAheadMeters;

  final double arrivalDistanceMeters;

  final int compassSampleCount;

  final double minimumHeadingChangeDegrees;

  final int directionConfirmationSamples;

  // ================================================================
  // STREAMS
  // ================================================================

  StreamSubscription<LocationFix>? _locationSubscription;

  StreamSubscription<double>? _compassSubscription;

  final StreamController<NavigationSnapshot>
      _snapshotController =
      StreamController<NavigationSnapshot>.broadcast();

  // ================================================================
  // HEADING AND DIRECTION ENGINES
  // ================================================================

  final HeadingEstimator _headingEstimator = HeadingEstimator();
  final RelativeDirectionEngine _relativeDirectionEngine =
      RelativeDirectionEngine();

  // ================================================================
  // STATE
  // ================================================================

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

  // ================================================================
  // ARRIVAL TRACKING
  // ================================================================

  DateTime? _lastArrivalFixTimestamp;
  int _arrivalFixCount = 0;

  // ================================================================
  // PUBLIC
  // ================================================================

  Stream<NavigationSnapshot> get snapshots =>
      _snapshotController.stream;

  NavigationSnapshot get snapshot => _snapshot;

  bool get isNavigating => _isNavigating;

  // ================================================================
  // START
  // ================================================================

  Future<void> start({
    required LatLon destination,
    List<LatLon>? destinationCandidates,
    bool campusNavigation = false,
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

    _isCampusNavigation = campusNavigation;
    _activeGpsFilterService =
        campusNavigation ? _campusGpsFilterService : _gpsFilterService;
    _activeRoutingService = campusNavigation
        ? _campusRoutingService
        : _routingService;
    if (_activeRoutingService == null) {
      throw const NavigationFailure(
        'Campus routing service is unavailable.',
      );
    }
    _destination = destination;

    _publish(
      const NavigationSnapshot(
        state: NavigationState.starting,
      ),
    );

    try {
      // ------------------------------------------------------------
      // 1. INITIAL GPS
      // ------------------------------------------------------------
      //
      // Keeps trying until the GPS quality filter accepts a fix
      // (or the timeout is reached).

      final filteredFix =
          await _waitForGoodInitialFix();

      _lastAcceptedFix = filteredFix;

      // ------------------------------------------------------------
      // 2. ROUTE
      // ------------------------------------------------------------

      // If a campus destination has multiple OSM entrance candidates,
      // compute a pedestrian route to each and choose the shortest reachable
      // route. OSRM performs the network snap; no straight-line route is made.
      final candidates = destinationCandidates
              ?.where((point) =>
                  point.latitude != 0 && point.longitude != 0)
              .toList() ??
          const <LatLon>[];
      var selectedDestination = destination;
      RouteResult? bestRoute;
      Object? lastRouteError;

      if (campusNavigation && candidates.isNotEmpty) {
        for (final candidate in candidates) {
          try {
            final candidateRoute =
                await _activeRoutingService!.computeRoute(
              origin: filteredFix.position,
              destination: candidate,
            );
            if (candidateRoute.polyline.isEmpty) continue;
            if (bestRoute == null ||
                candidateRoute.distanceMeters < bestRoute.distanceMeters) {
              bestRoute = candidateRoute;
              selectedDestination = candidate;
            }
          } catch (error) {
            lastRouteError = error;
          }
        }
      } else {
        bestRoute = await _activeRoutingService!.computeRoute(
          origin: filteredFix.position,
          destination: destination,
        );
      }

      if (bestRoute == null || bestRoute.polyline.isEmpty) {
        if (lastRouteError != null) throw lastRouteError;
        throw const NavigationFailure(
          'No reachable OSM pedestrian route was found for this destination.',
        );
      }

      // Keep the selected entrance as the target for arrival detection and
      // any later off-route recalculation.
      _destination = selectedDestination;
      final route = bestRoute;
      _route = route;

      // ------------------------------------------------------------
      // 3. INITIAL COMPASS
      // ------------------------------------------------------------

      final initialHeading =
          await _compassService.getStableHeading();

      _resetCompassSmoothing();

      final smoothedInitialHeading =
          _headingEstimator.update(
            initialHeading,
            timestamp: DateTime.now(),
          ) ??
          initialHeading;

      _latestHeading = smoothedInitialHeading;

      // ------------------------------------------------------------
      // 4. START LIVE NAVIGATION
      // ------------------------------------------------------------

      _isNavigating = true;

      _publish(
        NavigationSnapshot(
          state: NavigationState.navigating,
          currentPosition: filteredFix.position,
          accuracyMeters: filteredFix.accuracyMeters,
          route: route,
          heading: smoothedInitialHeading,
        ),
      );

      _startCompassStream();

      _startLocationStream();

      // ------------------------------------------------------------
      // 5. FIRST CALCULATION
      // ------------------------------------------------------------

      _updateNavigation(
        filteredFix,
        smoothedInitialHeading,
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
  // INITIAL GPS RETRY
  // ================================================================

  Future<LocationFix> _waitForGoodInitialFix({
    Duration timeout = const Duration(seconds: 30),
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // stop() was called while we were waiting.
      if (_destination == null) {
        throw const NavigationFailure(
          'Navigation was cancelled.',
        );
      }

      try {
        final rawFix =
            await _locationService.getCurrentLocationFix();

        final filtered =
            _activeGpsFilterService!.process(rawFix);

        if (filtered != null) {
          return filtered;
        }
      } catch (_) {
        // GPS read failed, keep trying until the timeout.
      }

      await Future.delayed(retryDelay);
    }

    throw const NavigationFailure(
      'Could not get a good GPS fix. '
      'Move to an open area and try again.',
    );
  }

  // ================================================================
  // GPS STREAM
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
            state: NavigationState.gpsUnavailable,
            currentPosition: _lastAcceptedFix?.position,
            accuracyMeters:
                _lastAcceptedFix?.accuracyMeters,
            route: _route,
            heading: _latestHeading,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  Future<void> _handleLocationFix(
    LocationFix rawFix,
  ) async {
    if (!_isNavigating || _route == null) {
      return;
    }

    final filteredFix =
        _activeGpsFilterService!.process(rawFix);

    if (filteredFix == null) {
      // Ignore rejected GPS samples without stopping navigation.
      return;
    }

    _lastAcceptedFix = filteredFix;

    if (_isCampusNavigation) {
      final routeReady = await _maybeRerouteCampus(filteredFix);
      if (!routeReady) return;
    }

    final heading = _latestHeading;

    if (heading == null) {
      _publish(
        NavigationSnapshot(
          state: NavigationState.recovering,
          currentPosition: filteredFix.position,
          accuracyMeters: filteredFix.accuracyMeters,
          route: _route,
          errorMessage: 'Waiting for compass heading.',
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
  // CAMPUS OFF-ROUTE RECOVERY
  // ================================================================

  Future<bool> _maybeRerouteCampus(LocationFix fix) async {
    final route = _route;
    final destination = _destination;
    final router = _activeRoutingService;
    if (!_isNavigating || route == null || destination == null ||
        router == null || _isRerouting) {
      return true;
    }

    final progress = _routeProgressService.getNextTarget(
      currentPosition: fix.position,
      route: route,
      lookAheadMeters: 0,
    );
    final offRouteThreshold = math.max(
      _campusOffRouteMinimumMeters,
      fix.accuracyMeters * 1.5,
    );

    // Do not interpret walking beyond the route endpoint as an off-route
    // departure that should be recalculated backwards to the same destination.
    final endpoint = route.polyline.isNotEmpty
        ? route.polyline.last
        : destination;
    final distanceToEndpoint =
        _routeProgressService.distanceBetween(fix.position, endpoint);
    final remainingRoute = _routeProgressService.remainingRouteMeters;
    final passedEndpoint = remainingRoute <= 2.0 &&
        distanceToEndpoint > math.max(12.0, fix.accuracyMeters * 1.5);
    if (passedEndpoint) {
      _offRouteSamples = 0;
      return true;
    }

    if (progress.distanceFromRouteMeters > offRouteThreshold) {
      _offRouteSamples++;
    } else {
      _offRouteSamples = 0;
      return true;
    }

    if (_offRouteSamples < _campusOffRouteSamplesRequired) return true;
    final now = DateTime.now();
    if (_lastCampusRerouteAt != null &&
        now.difference(_lastCampusRerouteAt!) < _campusRerouteCooldown) {
      return true;
    }

    _isRerouting = true;
    _lastCampusRerouteAt = now;
    try {
      // The campus OSRM foot profile snaps this fresh GPS fix to the
      // imported OSM pedestrian graph and recalculates the route.
      final replacement = await router.computeRoute(
        origin: fix.position,
        destination: destination,
      );
      if (!_isNavigating || replacement.polyline.isEmpty) return false;
      _route = replacement;
      _offRouteSamples = 0;
      // A replacement route starts a new arrival evaluation window.
      _arrivalFixCount = 0;
      _lastArrivalFixTimestamp = null;
      return true;
    } catch (error) {
      // A failed reroute must not terminate the navigation session.
      // Pause guidance for this fix, keep the last accepted route, and
      // retry recovery when another trustworthy GPS fix arrives.
      _offRouteSamples = 0;
      _publish(NavigationSnapshot(
        state: NavigationState.recovering,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: _route,
        heading: _latestHeading,
        errorMessage: 'Campus route recovery is temporarily unavailable: $error',
      ));
      return false;
    } finally {
      _isRerouting = false;
    }
  }

  // ================================================================
  // COMPASS STREAM
  // ================================================================

  void _startCompassStream() {
    _compassSubscription?.cancel();

    _compassSubscription =
        _compassService.headingStream.listen(
      _handleCompassHeading,
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        _publish(
          NavigationSnapshot(
            state: NavigationState.recovering,
            currentPosition: _lastAcceptedFix?.position,
            accuracyMeters:
                _lastAcceptedFix?.accuracyMeters,
            route: _route,
            heading: _latestHeading,
            errorMessage: 'Compass error: $error',
          ),
        );
      },
    );
  }

  void _handleCompassHeading(
    double rawHeading,
  ) {
    if (!_isNavigating ||
        _lastAcceptedFix == null ||
        _route == null) {
      return;
    }

    final smoothedHeading = _headingEstimator.update(rawHeading);

    if (smoothedHeading == null) {
      return;
    }

    _latestHeading = smoothedHeading;

    _updateNavigation(
      _lastAcceptedFix!,
      smoothedHeading,
    );
  }

  // ================================================================
  // COMPASS SMOOTHING
  // ================================================================

  void _resetCompassSmoothing() {
    _headingEstimator.reset();
    _latestHeading = null;
  }

  // ================================================================
  // NAVIGATION CALCULATION
  // ================================================================

  void _updateNavigation(
    LocationFix fix,
    double heading,
  ) {
    final route = _route;
    final destination = _destination;

    if (route == null || destination == null) {
      return;
    }

    // ------------------------------------------------------------
    // GET ADAPTIVE ROUTE TARGET
    // ------------------------------------------------------------

    final target =
        _routeProgressService.getNextTarget(
      currentPosition: fix.position,
      route: route,

      // null tells RouteProgressService to choose
      // the appropriate look-ahead automatically.
      lookAheadMeters: lookAheadMeters,
    );

    // ------------------------------------------------------------
    // ARRIVAL
    // ------------------------------------------------------------

    final distanceToDestination =
        _routeProgressService.distanceBetween(
      fix.position,
      destination,
    );

    // Count only distinct GPS fixes. Arrival requires endpoint proximity
    // AND route completion. A user who has passed the endpoint must not be
    // rerouted back toward it or continue receiving a stale forward cue.
    if (_lastArrivalFixTimestamp != fix.timestamp) {
      _lastArrivalFixTimestamp = fix.timestamp;
      final endpoint = route.polyline.isNotEmpty
          ? route.polyline.last
          : destination;
      final distanceToEndpoint = _routeProgressService.distanceBetween(
        fix.position,
        endpoint,
      );
      final arrivalRadius = math.max(
        arrivalDistanceMeters,
        math.min(12.0, fix.accuracyMeters * 0.75),
      );
      final remainingRoute = _routeProgressService.remainingRouteMeters;
      final nearDestination = distanceToDestination <= arrivalRadius ||
          distanceToEndpoint <= arrivalRadius;
      final routeNearlyComplete = remainingRoute <=
          math.max(10.0, fix.accuracyMeters * 0.75);
      final passedEndpoint = remainingRoute <= 2.0 &&
          distanceToEndpoint > arrivalRadius;

      if (passedEndpoint) {
        _arrivalFixCount = 0;
      } else if (nearDestination && routeNearlyComplete) {
        _arrivalFixCount++;
      } else {
        _arrivalFixCount = 0;
      }
    }

    if (_arrivalFixCount >= 3) {
      _publish(
        NavigationSnapshot(
          state: NavigationState.arrived,
          currentPosition: fix.position,
          accuracyMeters: fix.accuracyMeters,
          route: route,
          targetPoint: destination,
          distanceFromRouteMeters: target.distanceFromRouteMeters,
          heading: heading,
        ),
      );
      _isNavigating = false;
      return;
    }

    // ------------------------------------------------------------
    // ROUTE BEARING
    // ------------------------------------------------------------
    //
    // IMPORTANT:
    //
    // We intentionally use the direction of the route segment,
    // rather than calculating GPS -> target point.
    //
    // This prevents a small left/right GPS offset from producing
    // a false instruction to cross the road.
    //
    // The route itself determines the direction of travel.
    // ------------------------------------------------------------

    final bearing =
        target.routeBearing ??
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
    // RAW DIRECTION
    // ------------------------------------------------------------

    final rawDirection =
        _directionCalculator.directionFromAngle(
      relativeAngle,
    );

    // ------------------------------------------------------------
    // STABILIZED DIRECTION
    // ------------------------------------------------------------

    final direction = _relativeDirectionEngine.update(
      relativeAngle,
      routeTurnContext: target.isNearTurn,
    );

    // ------------------------------------------------------------
    // PUBLISH
    // ------------------------------------------------------------

    _publish(
      NavigationSnapshot(
        state: NavigationState.navigating,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        targetPoint: target.point,
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
  // DIRECTION STABILITY
  // ================================================================



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
    _campusGpsFilterService.reset();
    _activeGpsFilterService = null;

    _lastAcceptedFix = null;
    _latestHeading = null;

    _route = null;
    _destination = null;
    _activeRoutingService = null;
    _isCampusNavigation = false;
    _isRerouting = false;
    _offRouteSamples = 0;
    _lastCampusRerouteAt = null;

    _relativeDirectionEngine.reset();
    _arrivalFixCount = 0;
    _lastArrivalFixTimestamp = null;
    _routeProgressService.reset();

    _resetCompassSmoothing();

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
      _snapshotController.add(snapshot);
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

    if (!_snapshotController.isClosed) {
      await _snapshotController.close();
    }
  }
}

class NavigationFailure implements Exception {
  const NavigationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}