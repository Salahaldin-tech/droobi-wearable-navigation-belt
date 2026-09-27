
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

    // --------------------------------------------------------------
    // ROUTE FOLLOWING
    // --------------------------------------------------------------

    this.lookAheadMeters = 8.0,

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
        _compassService = compassService,
        _gpsFilterService =
            gpsFilterService ??
                GpsFilterService(),
        _routeProgressService =
            routeProgressService ??
                RouteProgressService(),
        _directionCalculator =
            directionCalculator ??
                DirectionCalculator();

  final LocationService _locationService;

  final RoutingService _routingService;

  final CompassService _compassService;

  final GpsFilterService _gpsFilterService;

  final RouteProgressService _routeProgressService;

  final DirectionCalculator _directionCalculator;

  // ================================================================
  // SETTINGS
  // ================================================================

  /// Fallback look-ahead.
  ///
  /// RouteProgressService can reduce this near turns.
  final double lookAheadMeters;

  final double arrivalDistanceMeters;

  final int compassSampleCount;

  final double minimumHeadingChangeDegrees;

  final int directionConfirmationSamples;

  // ================================================================
  // STREAMS
  // ================================================================

  StreamSubscription<LocationFix>?
      _locationSubscription;

  StreamSubscription<double>?
      _compassSubscription;

  final StreamController<
          NavigationSnapshot>
      _snapshotController =
      StreamController<
          NavigationSnapshot>.broadcast();

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

  // ================================================================
  // PUBLIC
  // ================================================================

  Stream<NavigationSnapshot>
      get snapshots =>
          _snapshotController.stream;

  NavigationSnapshot get snapshot =>
      _snapshot;

  bool get isNavigating =>
      _isNavigating;

  // ================================================================
  // START
  // ================================================================

  Future<void> start({
    required LatLon destination,
  }) async {
    if (_isDisposed) {
      throw StateError(
        'NavigationService has been disposed.',
      );
    }

    if (_isStarting ||
        _isNavigating) {
      return;
    }

    _isStarting = true;

    await stop();

    _destination =
        destination;

    _publish(
      const NavigationSnapshot(
        state:
            NavigationState.starting,
      ),
    );

    try {
      // ------------------------------------------------------------
      // 1. INITIAL GPS
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

      _lastAcceptedFix =
          filteredFix;

      // ------------------------------------------------------------
      // 2. ROUTE
      // ------------------------------------------------------------

      final route =
          await _routingService
              .computeRoute(
        origin:
            filteredFix.position,
        destination:
            destination,
      );

      if (route.polyline.isEmpty) {
        throw const NavigationFailure(
          'The routing service returned an empty route.',
        );
      }

      _route = route;

      // ------------------------------------------------------------
      // 3. INITIAL COMPASS
      // ------------------------------------------------------------

      final initialHeading =
          await _compassService
              .getCurrentHeading();

      _resetCompassSmoothing();

      final smoothedInitialHeading =
          _addCompassSample(
                initialHeading,
                forcePublish: true,
              ) ??
              initialHeading;

      _latestHeading =
          smoothedInitialHeading;

      // ------------------------------------------------------------
      // 4. START LIVE NAVIGATION
      // ------------------------------------------------------------

      _isNavigating = true;

      _publish(
        NavigationSnapshot(
          state:
              NavigationState.navigating,
          currentPosition:
              filteredFix.position,
          accuracyMeters:
              filteredFix
                  .accuracyMeters,
          route: route,
          heading:
              smoothedInitialHeading,
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
          state:
              NavigationState.routeUnavailable,
          errorMessage:
              e.toString(),
        ),
      );

      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  // ================================================================
  // GPS STREAM
  // ================================================================

  void _startLocationStream() {
    _locationSubscription
        ?.cancel();

    _locationSubscription =
        _locationService
            .locationFixStream
            .listen(
      _handleLocationFix,
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        _publish(
          NavigationSnapshot(
            state:
                NavigationState
                    .gpsUnavailable,
            currentPosition:
                _lastAcceptedFix
                    ?.position,
            accuracyMeters:
                _lastAcceptedFix
                    ?.accuracyMeters,
            route: _route,
            heading:
                _latestHeading,
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
    if (!_isNavigating ||
        _route == null) {
      return;
    }

    final filteredFix =
        _gpsFilterService
            .process(rawFix);

    if (filteredFix == null) {
      return;
    }

    _lastAcceptedFix =
        filteredFix;

    final heading =
        _latestHeading;

    if (heading == null) {
      _publish(
        NavigationSnapshot(
          state:
              NavigationState
                  .recovering,
          currentPosition:
              filteredFix.position,
          accuracyMeters:
              filteredFix
                  .accuracyMeters,
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
  // COMPASS STREAM
  // ================================================================

  void _startCompassStream() {
    _compassSubscription
        ?.cancel();

    _compassSubscription =
        _compassService
            .headingStream
            .listen(
      _handleCompassHeading,
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        _publish(
          NavigationSnapshot(
            state:
                NavigationState
                    .recovering,
            currentPosition:
                _lastAcceptedFix
                    ?.position,
            accuracyMeters:
                _lastAcceptedFix
                    ?.accuracyMeters,
            route: _route,
            heading:
                _latestHeading,
            errorMessage:
                'Compass error: $error',
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
        _addCompassSample(
      rawHeading,
    );

    if (smoothedHeading == null) {
      return;
    }

    _latestHeading =
        smoothedHeading;

    _updateNavigation(
      _lastAcceptedFix!,
      smoothedHeading,
    );
  }

  // ================================================================
  // COMPASS SMOOTHING
  // ================================================================

  double? _addCompassSample(
    double heading, {
    bool forcePublish = false,
  }) {
    final normalized =
        _normalizeHeading(
      heading,
    );

    _headingSamples.add(
      normalized,
    );

    while (_headingSamples.length >
        compassSampleCount) {
      _headingSamples.removeAt(0);
    }

    final smoothed =
        _circularMean(
      _headingSamples,
    );

    if (forcePublish ||
        _lastPublishedHeading ==
            null) {
      _lastPublishedHeading =
          smoothed;

      return smoothed;
    }

    final change =
        _angularDifference(
      smoothed,
      _lastPublishedHeading!,
    );

    // Ignore small compass fluctuations.
    if (change <
        minimumHeadingChangeDegrees) {
      return _lastPublishedHeading;
    }

    _lastPublishedHeading =
        smoothed;

    return smoothed;
  }

  double _circularMean(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return 0;
    }

    double sinSum = 0;

    double cosSum = 0;

    for (final value
        in values) {
      final radians =
          value *
              math.pi /
              180.0;

      sinSum +=
          math.sin(radians);

      cosSum +=
          math.cos(radians);
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
    var normalized =
        heading % 360;

    if (normalized < 0) {
      normalized += 360;
    }

    return normalized;
  }

  void _resetCompassSmoothing() {
    _headingSamples.clear();

    _lastPublishedHeading =
        null;

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

    final destination =
        _destination;

    if (route == null ||
        destination == null) {
      return;
    }

    // ------------------------------------------------------------
    // GET ADAPTIVE ROUTE TARGET
    // ------------------------------------------------------------

    final target =
        _routeProgressService
            .getNextTarget(
      currentPosition:
          fix.position,
      route: route,
      lookAheadMeters:
          lookAheadMeters,
    );

    // ------------------------------------------------------------
    // ARRIVAL
    // ------------------------------------------------------------

    final distanceToDestination =
        _routeProgressService
            .distanceBetween(
      fix.position,
      destination,
    );

    if (distanceToDestination <=
        arrivalDistanceMeters) {
      _publish(
        NavigationSnapshot(
          state:
              NavigationState.arrived,
          currentPosition:
              fix.position,
          accuracyMeters:
              fix.accuracyMeters,
          route: route,
          targetPoint:
              destination,
          distanceFromRouteMeters:
              target
                  .distanceFromRouteMeters,
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
    // rather than calculating:
    //
    //     GPS -> target point
    //
    // This prevents GPS being slightly left/right of the road
    // from producing a false instruction to cross the road.
    //
    // The route itself determines the direction of travel.
    // ------------------------------------------------------------

    final bearing =
        target.routeBearing ??
            _directionCalculator
                .calculateBearing(
              from: fix.position,
              to: target.point,
            );

    // ------------------------------------------------------------
    // RELATIVE ANGLE
    // ------------------------------------------------------------

    final relativeAngle =
        _directionCalculator
            .normalizeAngle(
      bearing - heading,
    );

    // ------------------------------------------------------------
    // RAW DIRECTION
    // ------------------------------------------------------------

    final rawDirection =
        _directionCalculator
            .directionFromAngle(
      relativeAngle,
    );

    // ------------------------------------------------------------
    // STABILIZED DIRECTION
    // ------------------------------------------------------------

    final direction =
        _stabilizeDirection(
      rawDirection,
    );

    // ------------------------------------------------------------
    // PUBLISH
    // ------------------------------------------------------------

    _publish(
      NavigationSnapshot(
        state:
            NavigationState.navigating,
        currentPosition:
            fix.position,
        accuracyMeters:
            fix.accuracyMeters,
        route: route,
        targetPoint:
            target.point,
        distanceFromRouteMeters:
            target
                .distanceFromRouteMeters,
        targetBearing:
            bearing,
        heading:
            heading,
        relativeAngle:
            relativeAngle,
        direction:
            direction,
      ),
    );
  }

  // ================================================================
  // DIRECTION STABILITY
  // ================================================================

  NavigationDirection
      _stabilizeDirection(
    NavigationDirection candidate,
  ) {
    // First direction.
    if (_confirmedDirection ==
        null) {
      _confirmedDirection =
          candidate;

      _candidateDirection =
          null;

      _candidateDirectionCount =
          0;

      return _confirmedDirection!;
    }

    // Same direction.
    if (candidate ==
        _confirmedDirection) {
      _candidateDirection =
          null;

      _candidateDirectionCount =
          0;

      return _confirmedDirection!;
    }

    // New candidate.
    if (_candidateDirection !=
        candidate) {
      _candidateDirection =
          candidate;

      _candidateDirectionCount =
          1;

      return _confirmedDirection!;
    }

    _candidateDirectionCount++;

    if (_candidateDirectionCount >=
        directionConfirmationSamples) {
      _confirmedDirection =
          _candidateDirection;

      _candidateDirection =
          null;

      _candidateDirectionCount =
          0;
    }

    return _confirmedDirection!;
  }

  // ================================================================
  // STOP
  // ================================================================

  Future<void> stop() async {
    _isNavigating = false;

    await _locationSubscription
        ?.cancel();

    _locationSubscription =
        null;

    await _compassSubscription
        ?.cancel();

    _compassSubscription =
        null;

    _gpsFilterService.reset();

    _lastAcceptedFix =
        null;

    _latestHeading =
        null;

    _route = null;

    _destination = null;

    _confirmedDirection =
        null;

    _candidateDirection =
        null;

    _candidateDirectionCount =
        0;

    _resetCompassSmoothing();

    if (!_isDisposed) {
      _publish(
        const NavigationSnapshot(
          state:
              NavigationState.stopped,
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
    _snapshot =
        snapshot;

    if (!_snapshotController
        .isClosed) {
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

    await _locationSubscription
        ?.cancel();

    await _compassSubscription
        ?.cancel();

    if (!_snapshotController
        .isClosed) {
      await _snapshotController.close();
    }
  }
}

class NavigationFailure
    implements Exception {
  const NavigationFailure(
    this.message,
  );

  final String message;

  @override
  String toString() =>
      message;
}

