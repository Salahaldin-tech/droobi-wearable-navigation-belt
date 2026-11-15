import 'dart:async';
import 'dart:math' as math;

import '../../core/geo/geo_math.dart';
import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';
import '../../models/navigation_direction.dart';
import '../../models/route_result.dart';
import '../location/gps_filter_service.dart';
import '../location/location_service.dart';
import '../routing/routing_service.dart';
import 'compass_service.dart';
import 'course_offset_estimator.dart';
import 'direction_calculator.dart';
import 'heading_estimator.dart';
import 'heading_north_corrector.dart';
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

/// Where the heading used for the current cue came from.
enum HeadingSource {
  /// Phone compass with sensor-reported accuracy.
  compass,

  /// Phone compass whose sensor reports no accuracy; down-weighted.
  compassDegraded,

  /// GPS course over ground (compass unavailable, user walking).
  gpsCourse,
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
    this.headingSource,
    this.remainingMeters,
    this.distanceToNextTurnMeters,
    this.nextTurnAngleDegrees,
    this.isOffRoute = false,
    this.courseOffsetDegrees,
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

  final HeadingSource? headingSource;

  /// Distance left along the route.
  final double? remainingMeters;

  final double? distanceToNextTurnMeters;

  /// Signed angle of the next turn: positive = right.
  final double? nextTurnAngleDegrees;

  /// True while the user is beyond the off-route threshold.
  final bool isOffRoute;

  /// Learned compass-to-walking-direction correction, when calibrated.
  final double? courseOffsetDegrees;

  String? get command => direction?.command;
}

/// The Droobi navigation engine.
///
/// Pipeline per GPS fix: filter → map-match → (calibrate compass from GPS
/// course) → arrival → off-route / reroute → guidance.
/// Pipeline per compass sample: true-north correction → course offset →
/// smoothing → guidance against the last matched route target.
///
/// The session never stops itself except on confirmed arrival. GPS loss,
/// compass loss and routing failures pause or degrade guidance and recover
/// automatically.
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
    HeadingNorthCorrector? headingNorthCorrector,
    DateTime Function()? clock,
    this.lookAheadMeters,
    this.arrivalDistanceMeters = 8.0,
    this.compassSampleCount = 5,
    this.minimumHeadingChangeDegrees = 8.0,
    this.directionConfirmationSamples = 3,
    this.initialFixTimeout = const Duration(seconds: 30),
    this.initialFixRetryDelay = const Duration(seconds: 1),
  })  : _locationService = locationService,
        _routingService = routingService,
        _campusRoutingService = campusRoutingService,
        _compassService = compassService,
        _gpsFilterService = gpsFilterService ?? GpsFilterService(),
        _campusGpsFilterService = campusGpsFilterService ?? GpsFilterService(),
        _routeProgressService = routeProgressService ?? RouteProgressService(),
        _directionCalculator = directionCalculator ?? DirectionCalculator(),
        _headingNorthCorrector =
            headingNorthCorrector ?? HeadingNorthCorrector(),
        _clock = clock ?? DateTime.now;

  final LocationService _locationService;
  final RoutingService _routingService;
  final RoutingService? _campusRoutingService;
  final CompassService _compassService;
  final GpsFilterService _gpsFilterService;
  final GpsFilterService _campusGpsFilterService;
  final RouteProgressService _routeProgressService;
  final DirectionCalculator _directionCalculator;
  final HeadingNorthCorrector _headingNorthCorrector;
  final DateTime Function() _clock;

  // ================================================================
  // SETTINGS
  // ================================================================

  /// Optional fixed look-ahead; null lets RouteProgressService adapt it.
  final double? lookAheadMeters;

  final double arrivalDistanceMeters;

  final int compassSampleCount;

  /// Retained for API compatibility; smoothing is time-constant based.
  final double minimumHeadingChangeDegrees;

  /// Retained for API compatibility; confirmation is time based.
  final int directionConfirmationSamples;

  final Duration initialFixTimeout;
  final Duration initialFixRetryDelay;

  // Off-route policy per mode.
  static const double _campusOffRouteMinimumMeters = 12.0;
  static const double _standardOffRouteMinimumMeters = 20.0;
  static const int _campusOffRouteSamplesRequired = 2;
  static const int _standardOffRouteSamplesRequired = 3;
  static const Duration _campusRerouteCooldown = Duration(seconds: 5);
  static const Duration _standardRerouteCooldown = Duration(seconds: 10);

  /// Compass silent for longer than this → GPS course may stand in.
  static const Duration _compassStaleAfter = Duration(seconds: 3);

  /// Compass samples with unknown accuracy are smoothed like Android's
  /// MEDIUM accuracy: many devices simply never report accuracy for the
  /// rotation-vector sensor. They are never used for course calibration.
  static const double _unknownAccuracyDegrees = 30.0;

  static const double _maximumCompassAccuracyDegrees = 45.0;

  /// Compass-driven republishing is limited unless the cue changes.
  static const Duration _compassPublishInterval = Duration(milliseconds: 200);

  // ================================================================
  // STREAMS
  // ================================================================

  StreamSubscription<LocationFix>? _locationSubscription;
  StreamSubscription<CompassSample>? _compassSubscription;

  final StreamController<NavigationSnapshot> _snapshotController =
      StreamController<NavigationSnapshot>.broadcast();

  // ================================================================
  // ENGINES
  // ================================================================

  final HeadingEstimator _headingEstimator = HeadingEstimator();
  final RelativeDirectionEngine _relativeDirectionEngine =
      RelativeDirectionEngine();
  final CourseOffsetEstimator _courseOffset = CourseOffsetEstimator();

  // ================================================================
  // STATE
  // ================================================================

  NavigationSnapshot _snapshot =
      const NavigationSnapshot(state: NavigationState.idle);

  /// Incremented by every start/stop; async work from an older session is
  /// discarded when it resumes.
  int _session = 0;

  bool _isStarting = false;
  bool _isNavigating = false;
  bool _isDisposed = false;
  bool _isCampusNavigation = false;

  RoutingService? _activeRoutingService;
  GpsFilterService? _activeGpsFilterService;

  RouteResult? _route;
  LatLon? _destination;
  LocationFix? _lastAcceptedFix;
  RouteTarget? _lastTarget;

  double? _latestHeading;
  HeadingSource? _headingSource;
  DateTime? _lastCompassHeadingAt;
  DateTime? _lastCompassPublishAt;
  final List<_TimedHeading> _recentCompass = <_TimedHeading>[];
  final List<double> _recentCourses = <double>[];

  bool _isRerouting = false;
  int _offRouteSamples = 0;
  DateTime? _lastRerouteAt;

  DateTime? _lastArrivalFixTimestamp;
  int _arrivalFixCount = 0;

  // ================================================================
  // PUBLIC
  // ================================================================

  Stream<NavigationSnapshot> get snapshots => _snapshotController.stream;

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
      throw StateError('NavigationService has been disposed.');
    }
    // A new start supersedes any running or still-starting session; the
    // older start notices the session change at its next await and exits.
    final session = ++_session;
    _isStarting = true;
    try {
      await _teardown();
      _checkSession(session);

      _isCampusNavigation = campusNavigation;
      _activeGpsFilterService =
          campusNavigation ? _campusGpsFilterService : _gpsFilterService;
      _activeRoutingService =
          campusNavigation ? _campusRoutingService : _routingService;
      _destination = destination;

      _publish(const NavigationSnapshot(state: NavigationState.starting));

      if (_activeRoutingService == null) {
        throw const NavigationFailure('Campus routing service is unavailable.');
      }

      // 1. Initial GPS fix accepted by the quality filter.
      final fix = await _waitForGoodInitialFix(session);
      _lastAcceptedFix = fix;

      // 2. Route (best of the candidate entrances for campus navigation).
      final route = await _computeInitialRoute(
        session: session,
        origin: fix.position,
        destination: destination,
        candidates: destinationCandidates,
        campusNavigation: campusNavigation,
      );
      _checkSession(session);
      _route = route;

      // 3. Initial heading. A compass that cannot settle is not fatal: the
      //    session starts and waits for a compass or GPS-course heading.
      String? headingWarning;
      try {
        final sample = await _compassService.getStableCompassSample(
          sampleCount: compassSampleCount,
          allowUnknownAccuracyFallback: true,
        );
        _checkSession(session);
        _acceptCompassSample(sample, fix.position);
      } on NavigationFailure {
        rethrow;
      } catch (error) {
        headingWarning = error.toString();
      }
      _checkSession(session);

      // 4. Live streams.
      _isNavigating = true;
      _startCompassStream(session);
      _startLocationStream(session);

      // 5. First guidance.
      _lastTarget = _matchRoute(fix);
      if (_latestHeading == null) {
        _publishWaitingForHeading(fix, headingWarning);
      } else {
        _publishGuidance(force: true);
      }
    } on _SessionCancelled {
      // stop() or a newer start() took over; nothing to report.
    } catch (error) {
      _isNavigating = false;
      _publish(NavigationSnapshot(
        state: NavigationState.routeUnavailable,
        errorMessage: error.toString(),
      ));
      rethrow;
    } finally {
      if (session == _session) _isStarting = false;
    }
  }

  /// True while a start() is still acquiring GPS, route and heading.
  bool get isStarting => _isStarting;

  void _checkSession(int session) {
    if (session != _session || _isDisposed) throw const _SessionCancelled();
  }

  Future<LocationFix> _waitForGoodInitialFix(int session) async {
    final deadline = _clock().add(initialFixTimeout);
    Object? lastError;
    while (_clock().isBefore(deadline)) {
      _checkSession(session);
      try {
        final rawFix = await _locationService.getCurrentLocationFix();
        _checkSession(session);
        final filtered = _activeGpsFilterService!.process(rawFix);
        if (filtered != null) return filtered;
      } on _SessionCancelled {
        rethrow;
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(initialFixRetryDelay);
    }
    _checkSession(session);
    if (lastError is LocationFailure &&
        lastError.type != LocationErrorType.unavailable) {
      throw NavigationFailure(lastError.message);
    }
    throw const NavigationFailure(
      'Could not get a good GPS fix. Move to an open area and try again.',
    );
  }

  Future<RouteResult> _computeInitialRoute({
    required int session,
    required LatLon origin,
    required LatLon destination,
    required List<LatLon>? candidates,
    required bool campusNavigation,
  }) async {
    final router = _activeRoutingService!;
    final validCandidates = candidates
            ?.where((p) => p.latitude != 0 && p.longitude != 0)
            .toList() ??
        const <LatLon>[];

    if (!campusNavigation || validCandidates.isEmpty) {
      final route =
          await router.computeRoute(origin: origin, destination: destination);
      _checkSession(session);
      if (route.polyline.isEmpty) {
        throw const NavigationFailure('The routing service returned no path.');
      }
      return route;
    }

    // Route to every mapped entrance and keep the shortest. Requests are
    // sequential to respect the public OSRM server's fair-use policy.
    final results = <_CandidateRoute>[];
    for (final candidate in validCandidates) {
      try {
        final route =
            await router.computeRoute(origin: origin, destination: candidate);
        results.add(_CandidateRoute(candidate, route, null));
      } catch (error) {
        results.add(_CandidateRoute(candidate, null, error));
      }
      _checkSession(session);
    }

    _CandidateRoute? best;
    Object? lastError;
    for (final result in results) {
      final route = result.route;
      if (route == null || route.polyline.isEmpty) {
        lastError = result.error ?? lastError;
        continue;
      }
      if (best == null || route.distanceMeters < best.route!.distanceMeters) {
        best = result;
      }
    }
    if (best == null) {
      if (lastError != null) throw lastError;
      throw const NavigationFailure(
        'No reachable OSM pedestrian route was found for this destination.',
      );
    }
    // The chosen entrance is the arrival and reroute target.
    _destination = best.destination;
    return best.route!;
  }

  // ================================================================
  // GPS
  // ================================================================

  void _startLocationStream(int session) {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.locationFixStream.listen(
      (fix) => _handleLocationFix(fix, session),
      onError: (Object error) {
        if (!_isNavigating || session != _session) return;
        _publish(NavigationSnapshot(
          state: NavigationState.gpsUnavailable,
          currentPosition: _lastAcceptedFix?.position,
          accuracyMeters: _lastAcceptedFix?.accuracyMeters,
          route: _route,
          heading: _latestHeading,
          headingSource: _headingSource,
          errorMessage: error.toString(),
        ));
      },
    );
  }

  Future<void> _handleLocationFix(LocationFix rawFix, int session) async {
    if (!_isNavigating || session != _session || _route == null) return;

    final fix = _activeGpsFilterService!.process(rawFix);
    if (fix == null) return; // Rejected: keep the last accepted state.
    _lastAcceptedFix = fix;

    var target = _matchRoute(fix);
    _lastTarget = target;

    _calibrateFromCourse(fix, target);
    _maybeUseCourseAsHeading(fix);

    if (_evaluateArrival(fix, target)) return;

    if (_shouldReroute(fix, target)) {
      final rerouted = await _reroute(fix, session);
      if (!_isNavigating || session != _session) return;
      if (!rerouted) return; // Recovery snapshot already published.
      target = _matchRoute(fix);
      _lastTarget = target;
    }

    if (_latestHeading == null) {
      _publishWaitingForHeading(fix, null);
      return;
    }
    _publishGuidance(force: true);
  }

  RouteTarget _matchRoute(LocationFix fix) =>
      _routeProgressService.getNextTarget(
        currentPosition: fix.position,
        route: _route!,
        lookAheadMeters: lookAheadMeters,
        accuracyMeters: fix.accuracyMeters,
      );

  // ================================================================
  // ARRIVAL
  // ================================================================

  /// Arrival needs three distinct fixes that are both close to the endpoint
  /// and nearly at the end of the route. Returns true once arrived.
  bool _evaluateArrival(LocationFix fix, RouteTarget target) {
    final route = _route!;
    final destination = _destination!;
    if (_lastArrivalFixTimestamp != fix.timestamp) {
      _lastArrivalFixTimestamp = fix.timestamp;
      final endpoint = route.polyline.last;
      final distanceToEndpoint = GeoMath.distance(fix.position, endpoint);
      final distanceToDestination = GeoMath.distance(fix.position, destination);
      final arrivalRadius = math.max(
        arrivalDistanceMeters,
        math.min(12.0, fix.accuracyMeters * 0.75),
      );
      final remaining = target.remainingMeters;
      final near = distanceToDestination <= arrivalRadius ||
          distanceToEndpoint <= arrivalRadius;
      final nearlyComplete =
          remaining <= math.max(10.0, fix.accuracyMeters * 0.75);
      final passedEndpoint = remaining <= 2.0 && distanceToEndpoint > arrivalRadius;

      if (passedEndpoint) {
        _arrivalFixCount = 0;
      } else if (near && nearlyComplete) {
        _arrivalFixCount++;
      } else {
        _arrivalFixCount = 0;
      }
    }

    if (_arrivalFixCount < 3) return false;

    _isNavigating = false;
    _publish(NavigationSnapshot(
      state: NavigationState.arrived,
      currentPosition: fix.position,
      accuracyMeters: fix.accuracyMeters,
      route: route,
      targetPoint: destination,
      distanceFromRouteMeters: target.distanceFromRouteMeters,
      heading: _latestHeading,
      headingSource: _headingSource,
      remainingMeters: 0,
    ));
    // The session is complete; release the sensors.
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
    return true;
  }

  // ================================================================
  // OFF-ROUTE AND REROUTING (both modes)
  // ================================================================

  double _offRouteThreshold(LocationFix fix) => math.max(
        _isCampusNavigation
            ? _campusOffRouteMinimumMeters
            : _standardOffRouteMinimumMeters,
        fix.accuracyMeters * 1.5,
      );

  bool _shouldReroute(LocationFix fix, RouteTarget target) {
    if (_isRerouting) return false;

    // Walking past the endpoint is not a reason to route backwards.
    final distanceToEndpoint =
        GeoMath.distance(fix.position, _route!.polyline.last);
    if (target.remainingMeters <= 2.0 &&
        distanceToEndpoint > math.max(12.0, fix.accuracyMeters * 1.5)) {
      _offRouteSamples = 0;
      return false;
    }

    if (target.distanceFromRouteMeters <= _offRouteThreshold(fix)) {
      _offRouteSamples = 0;
      return false;
    }
    _offRouteSamples++;

    final required = _isCampusNavigation
        ? _campusOffRouteSamplesRequired
        : _standardOffRouteSamplesRequired;
    if (_offRouteSamples < required) return false;

    final cooldown =
        _isCampusNavigation ? _campusRerouteCooldown : _standardRerouteCooldown;
    final now = _clock();
    if (_lastRerouteAt != null && now.difference(_lastRerouteAt!) < cooldown) {
      return false;
    }
    return true;
  }

  /// Returns true when a replacement route is active.
  Future<bool> _reroute(LocationFix fix, int session) async {
    final router = _activeRoutingService;
    final destination = _destination;
    if (router == null || destination == null) return false;

    _isRerouting = true;
    _lastRerouteAt = _clock();
    try {
      final replacement =
          await router.computeRoute(origin: fix.position, destination: destination);
      if (!_isNavigating || session != _session) return false;
      if (replacement.polyline.isEmpty) {
        throw const NavigationFailure('The routing service returned no path.');
      }
      _route = replacement;
      _offRouteSamples = 0;
      _arrivalFixCount = 0;
      _lastArrivalFixTimestamp = null;
      return true;
    } catch (error) {
      if (!_isNavigating || session != _session) return false;
      // A failed reroute never ends the session. Guidance continues toward
      // the old route on later fixes; the next attempt follows the cooldown.
      _offRouteSamples = 0;
      _publish(NavigationSnapshot(
        state: NavigationState.recovering,
        currentPosition: fix.position,
        accuracyMeters: fix.accuracyMeters,
        route: _route,
        heading: _latestHeading,
        headingSource: _headingSource,
        isOffRoute: true,
        errorMessage: 'Route recovery is temporarily unavailable: $error',
      ));
      return false;
    } finally {
      if (session == _session) _isRerouting = false;
    }
  }

  // ================================================================
  // COMPASS
  // ================================================================

  void _startCompassStream(int session) {
    _compassSubscription?.cancel();
    _compassSubscription = _compassService.sampleStream.listen(
      (sample) {
        if (!_isNavigating || session != _session) return;
        final position = _lastAcceptedFix?.position;
        if (position == null) return;
        if (_acceptCompassSample(sample, position)) {
          _publishGuidance(force: false);
        }
      },
      // A compass error never interrupts the route: the last heading is held
      // briefly and GPS course takes over while the user walks.
      onError: (Object _) {},
    );
  }

  /// Applies true-north and course corrections, then smoothing.
  /// Returns true when the heading was updated.
  bool _acceptCompassSample(CompassSample sample, LatLon position) {
    final raw = sample.rawHeadingDegrees;
    if (!raw.isFinite) return false;

    final reported = sample.accuracyDegrees;
    final bool degraded;
    final double accuracy;
    if (reported == null) {
      // Android reports no accuracy until the sensor's first accuracy
      // callback; some devices never send one. Down-weight, don't freeze.
      degraded = true;
      accuracy = _unknownAccuracyDegrees;
    } else if (!reported.isFinite ||
        reported < 0 ||
        reported > _maximumCompassAccuracyDegrees) {
      return false;
    } else {
      degraded = false;
      accuracy = reported;
    }

    final double trueHeading;
    try {
      trueHeading = HeadingNorthCorrector.apply(
        raw,
        _headingNorthCorrector.correctionDegrees(position),
      );
    } on CompassNorthCorrectionFailure {
      return false;
    }

    final now = _clock();
    _recentCompass.add(_TimedHeading(now, trueHeading, !degraded && accuracy <= 30));
    _recentCompass.removeWhere(
      (h) => now.difference(h.at) > const Duration(seconds: 2),
    );

    final offset = _courseOffset.offsetDegrees ?? 0.0;
    final smoothed = _headingEstimator.update(
      GeoMath.normalize360(trueHeading + offset),
      accuracyDegrees: accuracy,
      timestamp: sample.timestamp,
    );
    if (smoothed == null) return false;

    _latestHeading = smoothed;
    _lastCompassHeadingAt = now;
    _headingSource = degraded ? HeadingSource.compassDegraded : HeadingSource.compass;
    return true;
  }

  /// Learns the compass-to-walking-direction offset while the user walks
  /// straight along the route with a trustworthy GPS course.
  void _calibrateFromCourse(LocationFix fix, RouteTarget target) {
    final course = fix.courseDegrees;
    final speed = fix.speedMetersPerSecond;
    if (course == null || speed == null || speed < 0.8) {
      _recentCourses.clear();
      return;
    }
    _recentCourses.add(course);
    if (_recentCourses.length > 3) _recentCourses.removeAt(0);

    if (fix.accuracyMeters > 12) return;
    final courseAccuracy = fix.courseAccuracyDegrees;
    if (courseAccuracy != null && courseAccuracy > 15) return;
    if (_recentCourses.length < 3) return;
    if (GeoMath.resultantLength(_recentCourses) < math.cos(15 * math.pi / 180)) {
      return; // Still turning.
    }
    if (target.isNearTurn) return;
    if (target.distanceFromRouteMeters > _offRouteThreshold(fix)) return;

    final accurate = _recentCompass.where((h) => h.accurate).toList();
    if (accurate.length < 3) return;
    final values = accurate.map((h) => h.heading).toList();
    if (GeoMath.resultantLength(values) < math.cos(10 * math.pi / 180)) {
      return; // Phone is moving relative to the body.
    }
    final compassMean = GeoMath.circularMean(values);
    if (compassMean == null) return;

    _courseOffset.addSample(
      courseTrueDegrees: course,
      phoneTrueHeadingDegrees: compassMean,
    );
  }

  /// With no recent compass heading, a walking user's GPS course is the
  /// best available direction.
  void _maybeUseCourseAsHeading(LocationFix fix) {
    final last = _lastCompassHeadingAt;
    final compassStale =
        last == null || _clock().difference(last) > _compassStaleAfter;
    if (!compassStale) return;
    final course = fix.courseDegrees;
    final speed = fix.speedMetersPerSecond;
    if (course == null || speed == null || speed < 0.7) return;
    _latestHeading = GeoMath.normalize360(course);
    _headingSource = HeadingSource.gpsCourse;
  }

  // ================================================================
  // GUIDANCE
  // ================================================================

  void _publishGuidance({required bool force}) {
    final fix = _lastAcceptedFix;
    final target = _lastTarget;
    final heading = _latestHeading;
    final route = _route;
    if (!_isNavigating || fix == null || target == null || heading == null ||
        route == null) {
      return;
    }

    // Normally follow the route direction (immune to lateral GPS noise).
    // Once clearly off the route, aim at the route target to rejoin it.
    final offRoute = target.distanceFromRouteMeters > _offRouteThreshold(fix);
    final bearing = offRoute
        ? GeoMath.bearing(fix.position, target.point)
        : (target.guidanceBearing ??
            _directionCalculator.calculateBearing(
              from: fix.position,
              to: target.point,
            ));

    final relativeAngle = _directionCalculator.normalizeAngle(bearing - heading);
    final previousDirection = _snapshot.direction;
    final direction = _relativeDirectionEngine.update(
      relativeAngle,
      timestamp: _clock(),
      routeTurnContext: target.isNearTurn,
    );

    final now = _clock();
    if (!force &&
        direction == previousDirection &&
        _snapshot.state == NavigationState.navigating &&
        _lastCompassPublishAt != null &&
        now.difference(_lastCompassPublishAt!) < _compassPublishInterval) {
      return;
    }
    _lastCompassPublishAt = now;

    _publish(NavigationSnapshot(
      state: NavigationState.navigating,
      currentPosition: fix.position,
      accuracyMeters: fix.accuracyMeters,
      route: route,
      targetPoint: target.point,
      distanceFromRouteMeters: target.distanceFromRouteMeters,
      targetBearing: bearing,
      heading: heading,
      relativeAngle: relativeAngle,
      direction: direction,
      headingSource: _headingSource,
      remainingMeters: target.remainingMeters,
      distanceToNextTurnMeters: target.distanceToNextTurnMeters,
      nextTurnAngleDegrees: target.nextTurnAngleDegrees,
      isOffRoute: offRoute,
      courseOffsetDegrees: _courseOffset.offsetDegrees,
    ));
  }

  void _publishWaitingForHeading(LocationFix fix, String? reason) {
    _publish(NavigationSnapshot(
      state: NavigationState.recovering,
      currentPosition: fix.position,
      accuracyMeters: fix.accuracyMeters,
      route: _route,
      remainingMeters: _lastTarget?.remainingMeters,
      errorMessage: reason == null
          ? 'Waiting for compass heading. Hold the phone flat or start walking.'
          : 'Waiting for compass heading ($reason). '
              'Hold the phone flat or start walking.',
    ));
  }

  // ================================================================
  // STOP / DISPOSE
  // ================================================================

  Future<void> stop() async {
    _session++;
    _isStarting = false;
    await _teardown();
    if (!_isDisposed) {
      _publish(const NavigationSnapshot(state: NavigationState.stopped));
    }
  }

  Future<void> _teardown() async {
    _isNavigating = false;

    final location = _locationSubscription;
    final compass = _compassSubscription;
    _locationSubscription = null;
    _compassSubscription = null;
    await location?.cancel();
    await compass?.cancel();

    _gpsFilterService.reset();
    _campusGpsFilterService.reset();
    _activeGpsFilterService = null;
    _activeRoutingService = null;
    _isCampusNavigation = false;

    _route = null;
    _destination = null;
    _lastAcceptedFix = null;
    _lastTarget = null;

    _latestHeading = null;
    _headingSource = null;
    _lastCompassHeadingAt = null;
    _lastCompassPublishAt = null;
    _recentCompass.clear();
    _recentCourses.clear();
    _headingEstimator.reset();
    _courseOffset.reset();

    _isRerouting = false;
    _offRouteSamples = 0;
    _lastRerouteAt = null;

    _relativeDirectionEngine.reset();
    _arrivalFixCount = 0;
    _lastArrivalFixTimestamp = null;
    _routeProgressService.reset();
  }

  void _publish(NavigationSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _session++;
    _isStarting = false;
    _isDisposed = true;
    await _teardown();
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

class _SessionCancelled implements Exception {
  const _SessionCancelled();
}

class _CandidateRoute {
  const _CandidateRoute(this.destination, this.route, this.error);
  final LatLon destination;
  final RouteResult? route;
  final Object? error;
}

class _TimedHeading {
  const _TimedHeading(this.at, this.heading, this.accurate);
  final DateTime at;
  final double heading;
  final bool accurate;
}
