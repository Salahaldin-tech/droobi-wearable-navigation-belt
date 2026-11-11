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
import 'navigation_trace_logger.dart';
import 'route_progress_service.dart';
import 'wmm2025/magnetic_declination.dart';

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
            directionCalculator ?? DirectionCalculator();

  final LocationService _locationService;

  final RoutingService _routingService;

  final RoutingService? _campusRoutingService;

  RoutingService? _activeRoutingService;

  bool _isCampusNavigation = false;
  bool _isRerouting = false;
  int _offRouteSamples = 0;
  DateTime? _lastCampusRerouteAt;

  static const double _minimumOffRouteThresholdMeters = 8.0;
  static const double _maximumOffRouteThresholdMeters = 18.0;
  static const int _campusOffRouteSamplesRequired = 2;
  static const Duration _campusRerouteCooldown = Duration(seconds: 5);

  final CompassService _compassService;

  final GpsFilterService _gpsFilterService;

  final RouteProgressService _routeProgressService;

  final DirectionCalculator _directionCalculator;
  final NavigationTraceLogger _traceLogger = NavigationTraceLogger();

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
  static const Duration _policyInterval = Duration(milliseconds: 500);

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
  DateTime? _lastAcceptedGpsTimestamp;
  RouteTarget? _lastRouteTarget;
  DateTime? _lastRouteTargetFixTimestamp;

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
  DateTime? _lastCountedArrivalFixTimestamp;
  int _arrivalFixCount = 0;

  static const Duration _minimumArrivalFixSpacing =
      Duration(seconds: 1);
  static const Duration _maximumArrivalConfirmationGap =
      Duration(seconds: 20);
  static const double _maximumArrivalOvershootMeters = 20.0;

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
      _lastAcceptedGpsTimestamp = filteredFix.timestamp;
      _traceLogger.record('gps_initial_fix', fields: {
        'accuracy_m': filteredFix.accuracyMeters,
        'speed_mps': filteredFix.speedMetersPerSecond,
        'course_deg': filteredFix.courseDegrees,
        'course_accuracy_deg': filteredFix.courseAccuracyDegrees,
      });

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
      _lastRouteTarget = null;
      _lastRouteTargetFixTimestamp = null;
      _traceLogger.record('route_selected', fields: {
        'campus_navigation': campusNavigation,
        'distance_m': route.distanceMeters,
        'point_count': route.polyline.length,
        'alternative_entrance_selected': selectedDestination != destination,
      });

      // ------------------------------------------------------------
      // 3. LOCAL MAGNETIC DECLINATION (WMM2025)
      // ------------------------------------------------------------
      //
      // flutter_compass reports magnetic heading. Convert it to true north
      // using the offline WMM2025 model at the accepted GPS fix. This uses
      // no additional sensor, network request, or hard-coded +5 degree bias.

      final declinationField = MagneticDeclination.field(
        latitude: filteredFix.position.latitude,
        longitude: filteredFix.position.longitude,
        altitudeMeters: 0,
        date: DateTime.now().toUtc(),
      );
      if (!declinationField.isWithinValidity ||
          !declinationField.declination.isFinite) {
        throw const NavigationFailure(
          'The bundled WMM2025 magnetic model is outside its validity window. '
          'Update the model before starting compass-guided navigation.',
        );
      }
      _compassService.updateHeadingCorrection(
        declinationField.declination,
      );
      _traceLogger.record('magnetic_declination_applied', fields: {
        'model': 'WMM2025',
        'declination_deg': declinationField.declination,
        'inclination_deg': declinationField.inclination,
        'horizontal_intensity_nt': declinationField.horizontalIntensity,
        'model_valid': declinationField.isWithinValidity,
      });

      // ------------------------------------------------------------
      // 4. INITIAL COMPASS
      // ------------------------------------------------------------

      final initialHeading =
          await _compassService.getStableHeading();

      _traceLogger.record('compass_initial_stability', fields: {
        'resultant_vector': _compassService.lastStabilityResultantVector,
        'reported_accuracy_deg':
            _compassService.lastReportedAccuracyDegrees,
        'sample_count': _compassService.lastStabilitySampleCount,
        'sampling_window_ms':
            _compassService.lastStabilitySamplingWindow?.inMilliseconds,
      });

      _resetCompassSmoothing();

      final smoothedInitialHeading =
          _addCompassSample(
                initialHeading,
                forcePublish: true,
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

      _lastCompassAt = DateTime.now();
      _compassStreamHealthy = true;
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

        // Keep the last accepted fix through a transient stream error.
        _traceLogger.record('gps_stream_error', fields: {
          'error': error.toString(),
          'retaining_last_fix': _lastAcceptedFix != null,
        });
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

    final previousGpsTimestamp = _lastAcceptedGpsTimestamp;
    final gpsInterval = previousGpsTimestamp == null
        ? null
        : filteredFix.timestamp.difference(previousGpsTimestamp);
    _lastAcceptedFix = filteredFix;
    _lastAcceptedGpsTimestamp = filteredFix.timestamp;
    _traceLogger.record('gps_accepted', fields: {
      'interval_ms': gpsInterval?.inMilliseconds,
      'accuracy_m': filteredFix.accuracyMeters,
      'speed_mps': filteredFix.speedMetersPerSecond,
      'course_deg': filteredFix.courseDegrees,
      'course_accuracy_deg': filteredFix.courseAccuracyDegrees,
    });

    if (_isCampusNavigation) {
      await _maybeRerouteCampus(filteredFix);
      if (!_isNavigating) return;
    }

    // GPS callbacks refresh data; the fixed policy timer owns direction decisions.
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
      lookAheadMeters: lookAheadMeters,
      speedMetersPerSecond: fix.speedMetersPerSecond,
      horizontalAccuracyMeters: fix.accuracyMeters,
    );
    _lastRouteTarget = progress;
    _lastRouteTargetFixTimestamp = fix.timestamp;
    final offRouteThreshold = _offRouteThresholdFor(fix);

    if (progress.progressJumpDetected ||
        progress.distanceFromRouteMeters > offRouteThreshold) {
      _offRouteSamples++;
      _publish(NavigationSnapshot(
        state: progress.progressJumpDetected
            ? NavigationState.positionUncertain
            : NavigationState.offRoute,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: progress.distanceFromRouteMeters,
        heading: _latestHeading,
        progressMeters: progress.progressMeters,
        remainingRouteMeters: progress.remainingRouteMeters,
        direction: _confirmedDirection,
        errorMessage: 'Campus position is being rematched to mapped paths. Keeping the last confirmed guidance cue.',
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
    _traceLogger.record('campus_reroute_started', fields: {
      'cross_track_m': progress.distanceFromRouteMeters,
      'progress_jump': progress.progressJumpDetected,
      'accuracy_m': fix.accuracyMeters,
    });
    _publish(NavigationSnapshot(
      state: NavigationState.recovering,
      currentPosition: fix.position,
      accuracyMeters: fix.accuracyMeters,
      route: route,
      heading: _latestHeading,
      errorMessage: 'Reconnecting to a mapped pedestrian path.',
    ));
    try {
      // CampusGraphRoutingService snaps this fresh GPS fix to the nearest
      // QGIS edge and runs shortest-path routing to the original destination.
      final replacement = await router.computeRoute(
        origin: fix.position,
        destination: destination,
      );
      if (!_isNavigating || replacement.polyline.isEmpty) return;
      _route = replacement;
      _lastRouteTarget = null;
      _lastRouteTargetFixTimestamp = null;
      _traceLogger.record('campus_reroute_completed', fields: {
        'distance_m': replacement.distanceMeters,
        'point_count': replacement.polyline.length,
      });
      _offRouteSamples = 0;
      // A replacement route starts a new arrival evaluation window.
      _arrivalFixCount = 0;
      _lastArrivalFixTimestamp = null;
      _lastCountedArrivalFixTimestamp = null;
      _confirmedDirection = null;
      _candidateDirection = null;
      _candidateDirectionCount = 0;
    } catch (error) {
      // A failed reroute is logged, but does not shut down navigation.
      // Retain the active route and last confirmed guidance cue.
      _traceLogger.record('campus_reroute_failed', fields: {
        'error': error.toString(),
        'retaining_active_route': _route != null,
      });
      _publish(NavigationSnapshot(
        state: NavigationState.recovering,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: _route,
        heading: _latestHeading,
        direction: _confirmedDirection,
        errorMessage: 'Could not calculate a replacement path. Keeping the last confirmed guidance cue.',
      ));
    } finally {
      _isRerouting = false;
    }
  }

  // ================================================================
  // COMPASS STREAM
  // ================================================================

  void _startPolicyTimer() {
    _policyTimer?.cancel();
    _policyTimer = Timer.periodic(_policyInterval, (_) => _runPolicyTick());
  }

  double _offRouteThresholdFor(LocationFix fix) {
    return math.max(
      _minimumOffRouteThresholdMeters,
      math.min(_maximumOffRouteThresholdMeters, fix.accuracyMeters * 0.75),
    ).toDouble();
  }

  void _cancelPolicyAndSensorStreams() {
    _policyTimer?.cancel();
    _policyTimer = null;
    final location = _locationSubscription;
    _locationSubscription = null;
    if (location != null) unawaited(location.cancel());
    final compass = _compassSubscription;
    _compassSubscription = null;
    if (compass != null) unawaited(compass.cancel());
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
        direction: _confirmedDirection,
      ));
      return;
    }

    final route = _route;
    final fix = _lastAcceptedFix;
    final heading = _latestHeading;
    if (route == null || fix == null || heading == null) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix?.position,
        accuracyMeters: fix?.accuracyMeters,
        route: route,
        heading: heading,
        direction: _confirmedDirection,
        errorMessage: 'Waiting for the initial GPS position and compass heading.',
      ));
      return;
    }

    // Once navigation has started, delayed or temporarily inaccurate sensor
    // updates do not pause the belt. Keep using the last accepted GPS fix
    // and last valid heading until newer readings arrive.
    _updateNavigation(fix, heading);
  }

  void _startCompassStream() {
    _compassSubscription?.cancel();

    _compassSubscription =
        _compassService.headingStream.listen(
      _handleCompassHeading,
      onError: (Object error) {
        if (!_isNavigating) {
          return;
        }

        // Retain the last valid heading and confirmed belt cue.
        _traceLogger.record('compass_stream_error', fields: {
          'error': error.toString(),
          'retaining_last_heading': _latestHeading != null,
        });
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
    _traceLogger.record('compass_heading', fields: {
      'heading_deg': smoothedHeading,
      'reported_accuracy_deg':
          _compassService.lastReportedAccuracyDegrees,
    });
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

  bool _isWithinArrivalOvershoot(
    LatLon position,
    RouteResult route, {
    required double maximumOvershootMeters,
    required double maximumCrossTrackMeters,
  }) {
    if (route.polyline.length < 2) return false;
    final previous = route.polyline[route.polyline.length - 2];
    final endpoint = route.polyline.last;
    const metersPerDegree = 111320.0;
    final latitudeRadians = endpoint.latitude * math.pi / 180.0;
    final scaleX = metersPerDegree * math.cos(latitudeRadians);

    final routeX =
        (endpoint.longitude - previous.longitude) * scaleX;
    final routeY =
        (endpoint.latitude - previous.latitude) * metersPerDegree;
    final routeLength = math.sqrt(routeX * routeX + routeY * routeY);
    if (!routeLength.isFinite || routeLength < 0.1) return false;

    final userX = (position.longitude - endpoint.longitude) * scaleX;
    final userY =
        (position.latitude - endpoint.latitude) * metersPerDegree;
    final unitX = routeX / routeLength;
    final unitY = routeY / routeLength;
    final alongTrack = userX * unitX + userY * unitY;
    final crossTrack = (userX * unitY - userY * unitX).abs();

    return alongTrack >= 0 &&
        alongTrack <= maximumOvershootMeters &&
        crossTrack <= maximumCrossTrackMeters;
  }

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

    // Route projection/progress is evaluated once per distinct GPS fix.
    // The 500ms policy tick may refresh the compass-relative cue, but it must
    // not repeatedly rematch the same stale coordinate against the route.
    if (_lastRouteTarget == null ||
        _lastRouteTargetFixTimestamp != fix.timestamp) {
      _lastRouteTarget = _routeProgressService.getNextTarget(
        currentPosition: fix.position,
        route: route,
        lookAheadMeters: lookAheadMeters,
        speedMetersPerSecond: fix.speedMetersPerSecond,
        horizontalAccuracyMeters: fix.accuracyMeters,
      );
      _lastRouteTargetFixTimestamp = fix.timestamp;
    }
    final target = _lastRouteTarget!;

    final offRouteThreshold = _offRouteThresholdFor(fix);
    final nearRouteEnd =
        target.remainingRouteMeters <= math.max(20.0, fix.accuracyMeters);
    if ((target.progressJumpDetected ||
            target.distanceFromRouteMeters > offRouteThreshold) &&
        !nearRouteEnd) {
      // A transient GPS jump must not silence a previously confirmed cue.
      _publish(NavigationSnapshot(
        state: NavigationState.recovering,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        heading: heading,
        direction: _confirmedDirection,
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
        errorMessage: 'Matching your position to the campus paths. Keeping the last confirmed guidance cue.',
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

    // Arrival evidence is GPS-fix based, not compass-tick based. The
    // confirmation window is time-aware so slow GPS cadence does not make
    // the user walk indefinitely past the mapped entrance.
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
      final passedDestination = _isWithinArrivalOvershoot(
        fix.position,
        route,
        maximumOvershootMeters: _maximumArrivalOvershootMeters,
        maximumCrossTrackMeters: arrivalRadius,
      );
      final routeNearlyComplete = remainingRoute <=
              math.max(10.0, fix.accuracyMeters * 0.75) ||
          passedDestination;
      final arrivalEvidence =
          (nearDestination || passedDestination) && routeNearlyComplete;

      if (arrivalEvidence) {
        final previousCountedFix = _lastCountedArrivalFixTimestamp;
        if (_arrivalFixCount == 0 || previousCountedFix == null) {
          _arrivalFixCount = 1;
          _lastCountedArrivalFixTimestamp = fix.timestamp;
        } else {
          final spacing = fix.timestamp.difference(previousCountedFix);
          if (spacing > _maximumArrivalConfirmationGap) {
            _arrivalFixCount = 1;
            _lastCountedArrivalFixTimestamp = fix.timestamp;
          } else if (spacing >= _minimumArrivalFixSpacing) {
            _arrivalFixCount++;
            _lastCountedArrivalFixTimestamp = fix.timestamp;
          }
        }
      } else {
        _arrivalFixCount = 0;
        _lastCountedArrivalFixTimestamp = null;
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
        errorMessage: 'The active mapped path has no reliable route bearing.',
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

    if (direction == null) {
      _publish(NavigationSnapshot(
        state: NavigationState.positionUncertain,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: route,
        targetPoint: target.point,
        distanceFromRouteMeters: target.distanceFromRouteMeters,
        targetBearing: bearing,
        heading: heading,
        relativeAngle: relativeAngle,
        progressMeters: target.progressMeters,
        remainingRouteMeters: target.remainingRouteMeters,
        errorMessage: 'Direction change is being confirmed. The belt is paused.',
      ));
      return;
    }

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
      return _confirmedDirection;
    }
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
    // Keep the previous confirmed cue while a new direction is being
    // verified, avoiding a silent belt gap during rapid heading changes.
    return _confirmedDirection;
  }

  // ================================================================
  // STOP
  // ================================================================

  Future<void> stop() async {
    _isNavigating = false;
    _policyTimer?.cancel();
    _policyTimer = null;

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _compassSubscription?.cancel();
    _compassSubscription = null;

    _gpsFilterService.reset();

    _lastAcceptedFix = null;
    _lastAcceptedGpsTimestamp = null;
    _latestHeading = null;

    _route = null;
    _lastRouteTarget = null;
    _lastRouteTargetFixTimestamp = null;
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
    _lastCountedArrivalFixTimestamp = null;
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
      'cross_track_m': snapshot.distanceFromRouteMeters,
      'progress_m': snapshot.progressMeters,
      'remaining_route_m': snapshot.remainingRouteMeters,
      'heading_deg': snapshot.heading,
      'route_bearing_deg': snapshot.targetBearing,
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