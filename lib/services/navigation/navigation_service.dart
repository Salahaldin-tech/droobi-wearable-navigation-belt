import 'dart:async';
import 'dart:math' as math;

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
import 'navigation_trace_logger.dart';

enum NavigationState {
  idle,
  starting,
  navigating,
  positionUncertain,
  offRoute,
  approaching,
  arrivalCandidate,
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
    this.progressMeters,
    this.remainingRouteMeters,
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

  final double? progressMeters;

  final double? remainingRouteMeters;

  String? get command => direction?.command;
}

class NavigationService {
  NavigationService({
    required LocationService locationService,
    required RoutingService routingService,
    RoutingService? campusRoutingService,
    required CompassService compassService,
    GpsFilterService? gpsFilterService,
    RouteProgressService? routeProgressService,
    DirectionCalculator? directionCalculator,
    NavigationTraceLogger? traceLogger,

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
        _routeProgressService =
            routeProgressService ?? RouteProgressService(),
        _directionCalculator =
            directionCalculator ?? DirectionCalculator(),
        _traceLogger = traceLogger ?? NavigationTraceLogger();

  final LocationService _locationService;

  final RoutingService _routingService;

  final RoutingService? _campusRoutingService;

  RoutingService? _activeRoutingService;

  bool _isCampusNavigation = false;
  bool _isRerouting = false;
  int _offRouteSamples = 0;
  DateTime? _lastCampusRerouteAt;

  static const int _campusOffRouteSamplesRequired = 2;
  static const Duration _campusRerouteCooldown = Duration(seconds: 5);

  final CompassService _compassService;

  final GpsFilterService _gpsFilterService;

  final RouteProgressService _routeProgressService;

  final DirectionCalculator _directionCalculator;
  final NavigationTraceLogger _traceLogger;

  NavigationTraceLogger get traceLogger => _traceLogger;

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
  Timer? _policyTimer;
  DateTime? _lastCompassAt;
  bool _gpsStreamHealthy = true;
  bool _compassStreamHealthy = true;

  static const Duration _policyInterval = Duration(milliseconds: 500);
  static const Duration _maximumFixAgeForGuidance = Duration(seconds: 12);
  static const Duration _maximumCompassAgeForGuidance = Duration(seconds: 5);
  static const double _minimumOffRouteThresholdMeters = 8.0;
  static const double _maximumOffRouteThresholdMeters = 18.0;

  final StreamController<NavigationSnapshot>
      _snapshotController =
      StreamController<NavigationSnapshot>.broadcast();

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
  // COMPASS SMOOTHING
  // ================================================================

  final List<double> _headingSamples = [];

  double? _lastPublishedHeading;

  // ================================================================
  // DIRECTION STABILITY
  // ================================================================

  NavigationDirection? _confirmedDirection;

  NavigationDirection? _candidateDirection;

  int _candidateDirectionCount = 0;

  DateTime? _candidateDirectionSince;
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
    _activeRoutingService = campusNavigation
        ? _campusRoutingService
        : _routingService;
    if (_activeRoutingService == null) {
      throw const NavigationFailure(
        'Campus routing is not configured.',
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

      // If the selected campus destination has multiple QGIS entrances,
      // compute a pedestrian route to each entrance and choose the shortest
      // reachable route. Straight-line distance is not used for this choice.
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
          'No reachable QGIS entrance was found for this destination.',
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
          _addCompassSample(
                initialHeading,
                forcePublish: true,
              ) ??
              initialHeading;

      _latestHeading = smoothedInitialHeading;
      _lastCompassAt = DateTime.now();

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
      _startPolicyTimer();
      _runPolicyTick();
    } catch (e) {
      _isNavigating = false;
      _cancelPolicyAndSensorStreams();

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
            _gpsFilterService.process(rawFix);

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

        _gpsStreamHealthy = false;
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
        _gpsFilterService.process(rawFix);

    if (filteredFix == null) {
      // Ignore rejected GPS samples without stopping navigation.
      return;
    }

    _lastAcceptedFix = filteredFix;
    _gpsStreamHealthy = true;
    _traceLogger.record('gps_accepted', fields: {
      'accuracy_m': filteredFix.accuracyMeters,
      'speed_mps': filteredFix.speedMetersPerSecond,
      'course_deg': filteredFix.courseDegrees,
      'course_accuracy_deg': filteredFix.courseAccuracyDegrees,
    });

    if (_isCampusNavigation) {
      await _maybeRerouteCampus(filteredFix);
      if (!_isNavigating) return;
    }

    // Sensor updates only refresh the latest data. The periodic policy
    // timer is the sole source of directional guidance decisions.
  }

  // ================================================================
  // CAMPUS OFF-ROUTE RECOVERY
  // ================================================================

  Future<void> _maybeRerouteCampus(LocationFix fix) async {
    final route = _route;
    final destination = _destination;
    final router = _activeRoutingService;
    if (!_isNavigating || route == null || destination == null ||
        router == null || _isRerouting) {
      return;
    }

    final progress = _routeProgressService.getNextTarget(
      currentPosition: fix.position,
      route: route,
      lookAheadMeters: 0,
      speedMetersPerSecond: fix.speedMetersPerSecond,
      horizontalAccuracyMeters: fix.accuracyMeters,
    );
    final offRouteThreshold = _offRouteThresholdFor(fix);

    if (progress.progressJumpDetected) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        heading: _latestHeading,
        errorMessage: 'A sudden GPS jump was detected. Waiting for a stable fix.',
      ));
      return;
    }

    if (progress.distanceFromRouteMeters > offRouteThreshold) {
      _offRouteSamples++;
      _publish(NavigationSnapshot(
        state: NavigationState.offRoute,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: progress.distanceFromRouteMeters,
        heading: _latestHeading,
        errorMessage: 'You appear to be away from the mapped path. Guidance is paused.',
      ));
    } else {
      _offRouteSamples = 0;
      return;
    }

    if (_offRouteSamples < _campusOffRouteSamplesRequired) return;
    final now = DateTime.now();
    if (_lastCampusRerouteAt != null &&
        now.difference(_lastCampusRerouteAt!) < _campusRerouteCooldown) {
      return;
    }

    _isRerouting = true;
    _lastCampusRerouteAt = now;
    try {
      // CampusGraphRoutingService snaps this fresh GPS fix to the nearest
      // QGIS edge and runs shortest-path routing to the original destination.
      final replacement = await router.computeRoute(
        origin: fix.position,
        destination: destination,
      );
      if (!_isNavigating || replacement.polyline.isEmpty) return;
      _route = replacement;
      _offRouteSamples = 0;
      // A replacement route starts a new arrival evaluation window.
      _arrivalFixCount = 0;
      _lastArrivalFixTimestamp = null;
      _confirmedDirection = null;
      _candidateDirection = null;
      _candidateDirectionCount = 0;
    } catch (error) {
      // Do not continue issuing directions along a stale route after the
      // user has left it and QGIS cannot find a connected replacement.
      _isNavigating = false;
      _cancelPolicyAndSensorStreams();
      _publish(NavigationSnapshot(
        state: NavigationState.routeUnavailable,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: _route,
        heading: _latestHeading,
        errorMessage: 'Could not reconnect to the campus paths: $error',
      ));
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

        _compassStreamHealthy = false;
        _latestHeading = null;
        _publish(
          NavigationSnapshot(
            state: NavigationState.positionUncertain,
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

    final smoothedHeading =
        _addCompassSample(rawHeading);

    if (smoothedHeading == null) {
      return;
    }

    _latestHeading = smoothedHeading;
    _lastCompassAt = DateTime.now();
    _compassStreamHealthy = true;
    _traceLogger.record('compass_heading', fields: {
      'heading_deg': smoothedHeading,
    });
    // The next fixed policy tick uses this fresh heading.
  }

  // ================================================================
  // COMPASS SMOOTHING
  // ================================================================

  double? _addCompassSample(
    double heading, {
    bool forcePublish = false,
  }) {
    final normalized =
        _normalizeHeading(heading);

    _headingSamples.add(normalized);

    while (_headingSamples.length >
        compassSampleCount) {
      _headingSamples.removeAt(0);
    }

    final smoothed =
        _circularMean(_headingSamples);

    if (forcePublish ||
        _lastPublishedHeading == null) {
      _lastPublishedHeading = smoothed;

      return smoothed;
    }

    final change = _angularDifference(
      smoothed,
      _lastPublishedHeading!,
    );

    // Ignore small compass fluctuations.
    if (change < minimumHeadingChangeDegrees) {
      return _lastPublishedHeading;
    }

    _lastPublishedHeading = smoothed;

    return smoothed;
  }

  // ================================================================
  // FIXED-CADENCE NAVIGATION POLICY
  // ================================================================

  double _offRouteThresholdFor(LocationFix fix) {
    // A poor GPS accuracy estimate allows a little more cross-track error,
    // but the tolerance is capped so a very noisy fix cannot authorize
    // continued guidance far away from a pedestrian path.
    return math.max(
      _minimumOffRouteThresholdMeters,
      math.min(
        _maximumOffRouteThresholdMeters,
        fix.accuracyMeters * 0.75,
      ),
    ).toDouble();
  }

  void _cancelPolicyAndSensorStreams() {
    _policyTimer?.cancel();
    _policyTimer = null;

    final locationSubscription = _locationSubscription;
    _locationSubscription = null;
    if (locationSubscription != null) {
      unawaited(locationSubscription.cancel());
    }

    final compassSubscription = _compassSubscription;
    _compassSubscription = null;
    if (compassSubscription != null) {
      unawaited(compassSubscription.cancel());
    }
  }

  void _startPolicyTimer() {
    _policyTimer?.cancel();
    _policyTimer = Timer.periodic(_policyInterval, (_) {
      _runPolicyTick();
    });
  }

  void _runPolicyTick() {
    if (!_isNavigating || _isDisposed) return;

    if (_isRerouting) {
      _publish(NavigationSnapshot(
        state: NavigationState.recovering,
        currentPosition: _lastAcceptedFix?.position,
        accuracyMeters: _lastAcceptedFix?.accuracyMeters,
        route: _route,
        heading: _latestHeading,
        errorMessage: 'Reconnecting to the mapped pedestrian network.',
      ));
      return;
    }

    final route = _route;
    final fix = _lastAcceptedFix;
    final heading = _latestHeading;
    if (!_gpsStreamHealthy || !_compassStreamHealthy ||
        route == null || fix == null || heading == null) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix?.position,
        accuracyMeters: fix?.accuracyMeters,
        route: route,
        heading: heading,
        errorMessage: 'Waiting for reliable position and compass readings.',
      ));
      return;
    }

    final now = DateTime.now();
    final fixAge = now.difference(fix.timestamp);
    final compassAge = _lastCompassAt == null
        ? _maximumCompassAgeForGuidance
        : now.difference(_lastCompassAt!);

    if (fixAge > _maximumFixAgeForGuidance ||
        fixAge < const Duration(seconds: -2) ||
        compassAge > _maximumCompassAgeForGuidance) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        heading: heading,
        errorMessage: 'GPS or compass data is stale. Directional guidance is paused.',
      ));
      return;
    }

    _updateNavigation(fix, heading);
  }
  double _circularMean(

    List<double> values,
  ) {
    if (values.isEmpty) {
      return 0;
    }

    double sinSum = 0;
    double cosSum = 0;

    for (final value in values) {
      final radians =
          value * math.pi / 180.0;

      sinSum += math.sin(radians);
      cosSum += math.cos(radians);
    }

    var result =
        math.atan2(
              sinSum,
              cosSum,
            ) *
            180.0 /
            math.pi;

    if (result < 0) {
      result += 360;
    }

    return result;
  }

  double _angularDifference(
    double first,
    double second,
  ) {
    var difference =
        (first - second) % 360;

    if (difference > 180) {
      difference -= 360;
    }

    if (difference < -180) {
      difference += 360;
    }

    return difference.abs();
  }

  double _normalizeHeading(
    double heading,
  ) {
    var normalized = heading % 360;

    if (normalized < 0) {
      normalized += 360;
    }

    return normalized;
  }

  void _resetCompassSmoothing() {
    _headingSamples.clear();

    _lastPublishedHeading = null;

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
      speedMetersPerSecond: fix.speedMetersPerSecond,
      horizontalAccuracyMeters: fix.accuracyMeters,
    );

    if (target.progressJumpDetected) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        heading: heading,
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
        errorMessage: 'Route progress changed unexpectedly. Waiting for GPS confirmation.',
      ));
      return;
    }

    final offRouteThreshold = _offRouteThresholdFor(fix);
    if (target.distanceFromRouteMeters > offRouteThreshold) {
      _publish(NavigationSnapshot(
        state: NavigationState.offRoute,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        heading: heading,
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
        errorMessage: 'Position is outside the mapped route. Directional guidance is paused.',
      ));
      return;
    }

    // ------------------------------------------------------------
    // ARRIVAL
    // ------------------------------------------------------------

    final distanceToDestination =
        _routeProgressService.distanceBetween(
      fix.position,
      destination,
    );

    // Count only distinct GPS fixes. Compass callbacks can recalculate
    // navigation many times per second and are not independent arrival proof.
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

      if (nearDestination && routeNearlyComplete) {
        _arrivalFixCount++;
      } else {
        _arrivalFixCount = 0;
      }
    }

    if (_arrivalFixCount > 0 && _arrivalFixCount < 3) {
      _publish(NavigationSnapshot(
        state: NavigationState.arrivalCandidate,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        targetPoint: destination,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        heading: heading,
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
      ));
      return;
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
          progressMeters: target.progressMeters,
          remainingRouteMeters: target.remainingRouteMeters,
        ),
      );
      _isNavigating = false;
      _cancelPolicyAndSensorStreams();
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

    final bearing = target.routeBearing;
    if (bearing == null || !bearing.isFinite) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        heading: heading,
        errorMessage: 'The current route segment has no reliable bearing.',
      ));
      return;
    }

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

    final direction =
        _stabilizeDirection(rawDirection);

    // ------------------------------------------------------------
    // PUBLISH
    // ------------------------------------------------------------

    final nextState = target.remainingRouteMeters <= 20.0
        ? NavigationState.approaching
        : NavigationState.navigating;

    _publish(
      NavigationSnapshot(
        state: nextState,
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
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
      ),
    );
  }

  // ================================================================
  // DIRECTION STABILITY
  // ================================================================

  NavigationDirection? _stabilizeDirection(
    NavigationDirection candidate,
  ) {
    final now = DateTime.now();
    if (_confirmedDirection == null) {
      _confirmedDirection = candidate;
      _candidateDirection = null;
      _candidateDirectionCount = 0;
      _candidateDirectionSince = null;
      return candidate;
    }

    if (candidate == _confirmedDirection) {
      _candidateDirection = null;
      _candidateDirectionCount = 0;
      _candidateDirectionSince = null;
      return _confirmedDirection;
    }

    if (_candidateDirection != candidate) {
      _candidateDirection = candidate;
      _candidateDirectionCount = 1;
      _candidateDirectionSince = now;

      // Do not keep sending the previous direction while a turn is being
      // confirmed. STOP is safer than a stale haptic cue.
      return null;
    }

    // The policy runs at 2 Hz. Require both multiple policy observations
    // and a minimum dwell time before changing the active haptic direction.
    _candidateDirectionCount++;
    final since = _candidateDirectionSince;
    if (_candidateDirectionCount >= directionConfirmationSamples &&
        since != null &&
        now.difference(since) >= const Duration(milliseconds: 900)) {
      _confirmedDirection = candidate;
      _candidateDirection = null;
      _candidateDirectionCount = 0;
      _candidateDirectionSince = null;
      return _confirmedDirection;
    }

    return null;
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
    _activeRoutingService = null;
    _isCampusNavigation = false;
    _isRerouting = false;
    _offRouteSamples = 0;
    _lastCampusRerouteAt = null;

    _confirmedDirection = null;
    _candidateDirection = null;
    _candidateDirectionCount = 0;
    _candidateDirectionSince = null;
    _arrivalFixCount = 0;
    _lastArrivalFixTimestamp = null;
    _routeProgressService.reset();
    _policyTimer?.cancel();
    _policyTimer = null;
    _lastCompassAt = null;
    _gpsStreamHealthy = true;
    _compassStreamHealthy = true;

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
    _traceLogger.record('navigation_snapshot', fields: {
      'state': snapshot.state.name,
      'accuracy_m': snapshot.accuracyMeters,
      'distance_from_route_m': snapshot.distanceFromRouteMeters,
      'progress_m': snapshot.progressMeters,
      'remaining_route_m': snapshot.remainingRouteMeters,
      'heading_deg': snapshot.heading,
      'target_bearing_deg': snapshot.targetBearing,
      'relative_angle_deg': snapshot.relativeAngle,
      'direction': snapshot.direction?.name,
      'error': snapshot.errorMessage,
    });

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
    _policyTimer?.cancel();
    _policyTimer = null;

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