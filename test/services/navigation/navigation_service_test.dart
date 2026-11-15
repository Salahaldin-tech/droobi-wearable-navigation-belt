import 'dart:async';

import 'package:droobi/core/geo/geo_math.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/location_fix.dart';
import 'package:droobi/models/navigation_direction.dart';
import 'package:droobi/models/route_result.dart';
import 'package:droobi/services/location/location_service.dart';
import 'package:droobi/services/navigation/compass_service.dart';
import 'package:droobi/services/navigation/heading_north_corrector.dart';
import 'package:droobi/services/navigation/navigation_service.dart';
import 'package:droobi/services/routing/routing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final _frame = LocalFrame(const LatLon(latitude: 32.41, longitude: 35.29));
LatLon _p(double east, double north) => _frame.toLatLon(east, north);
final _t0 = DateTime.utc(2026, 11, 15, 10);

class FakeLocationService extends LocationService {
  FakeLocationService(this.initialFix);

  LocationFix initialFix;
  final StreamController<LocationFix> controller =
      StreamController<LocationFix>.broadcast();
  Completer<void>? holdInitialFix;

  @override
  Future<LocationFix> getCurrentLocationFix() async {
    final hold = holdInitialFix;
    if (hold != null) await hold.future;
    return initialFix;
  }

  @override
  Stream<LocationFix> get locationFixStream => controller.stream;
}

class FakeRouter implements RoutingService {
  FakeRouter(this.routes);

  final List<RouteResult Function(LatLon origin, LatLon destination)> routes;
  final List<LatLon> origins = <LatLon>[];
  Completer<void>? hold;

  @override
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  }) async {
    origins.add(origin);
    final h = hold;
    if (h != null) await h.future;
    final index = origins.length - 1 < routes.length
        ? origins.length - 1
        : routes.length - 1;
    return routes[index](origin, destination);
  }
}

/// Emits compass samples continuously from mutable fields.
class FakeCompass {
  double heading = 0;
  double? accuracy = 15;
  bool enabled = true;
  late final Stream<CompassSample> stream = Stream<CompassSample>.periodic(
    const Duration(milliseconds: 20),
    (_) => CompassSample(
      rawHeadingDegrees: heading,
      accuracyDegrees: accuracy,
      timestamp: DateTime.now(),
    ),
  ).where((_) => enabled).asBroadcastStream();
}

RouteResult _northRoute(LatLon origin, LatLon destination) => RouteResult(
      polyline: [_p(0, 0), _p(0, 100)],
      distanceMeters: 100,
      durationSeconds: 80,
    );

LocationFix _fix(double east, double north, int second,
        {double accuracy = 4, double? speed, double? course}) =>
    LocationFix(
      position: _p(east, north),
      accuracyMeters: accuracy,
      timestamp: _t0.add(Duration(seconds: second)),
      speedMetersPerSecond: speed,
      courseDegrees: course,
    );

NavigationService _service(
  FakeLocationService location,
  FakeRouter router,
  FakeCompass compass, {
  RoutingService? campusRouter,
}) =>
    NavigationService(
      locationService: location,
      routingService: router,
      campusRoutingService: campusRouter,
      compassService: CompassService(sampleSource: compass.stream),
      headingNorthCorrector:
          HeadingNorthCorrector(platform: TargetPlatform.iOS),
      initialFixRetryDelay: const Duration(milliseconds: 10),
    );

Future<void> _settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('guides forward along the route and confirms arrival', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final router = FakeRouter([_northRoute]);
    final compass = FakeCompass();
    final service = _service(location, router, compass);
    final states = <NavigationState>[];
    service.snapshots.listen((s) => states.add(s.state));

    await service.start(destination: _p(0, 100));
    expect(service.isNavigating, isTrue);
    expect(service.snapshot.direction, NavigationDirection.forward);

    for (var i = 1; i <= 75; i++) {
      location.controller.add(_fix(0, i * 1.35, i));
      await _settle(2);
    }
    await _settle();
    expect(service.snapshot.state, NavigationState.arrived);
    expect(service.isNavigating, isFalse);
    expect(states.where((s) => s == NavigationState.arrived), hasLength(1));
    await service.dispose();
  });

  test('turning the phone right produces a left cue', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final compass = FakeCompass();
    final service = _service(location, FakeRouter([_northRoute]), compass);
    await service.start(destination: _p(0, 100));
    compass.heading = 90;
    await _settle(2500);
    expect(service.snapshot.direction, NavigationDirection.left);
    await service.dispose();
  });

  test('unknown compass accuracy updates the heading instead of freezing it',
      () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final compass = FakeCompass()..accuracy = null;
    final service = _service(location, FakeRouter([_northRoute]), compass);
    // Startup falls back to unknown-accuracy samples after the timeout.
    await service.start(destination: _p(0, 100));
    expect(service.isNavigating, isTrue);
    expect(service.snapshot.headingSource, HeadingSource.compassDegraded);
    compass.heading = 270;
    await _settle(3000);
    expect(GeoMath.wrap180(service.snapshot.heading! - 270).abs(), lessThan(20));
    expect(service.snapshot.direction, NavigationDirection.right);
    await service.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('stop() during route calculation cancels the session', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final router = FakeRouter([_northRoute])..hold = Completer<void>();
    final compass = FakeCompass();
    final service = _service(location, router, compass);
    final starting = service.start(destination: _p(0, 100));
    await _settle();
    await service.stop();
    router.hold!.complete();
    await starting;
    await _settle();
    expect(service.isNavigating, isFalse);
    expect(service.isStarting, isFalse);
    expect(service.snapshot.state, NavigationState.stopped);

    // The service can start again afterwards.
    router.hold = null;
    await service.start(destination: _p(0, 100));
    expect(service.isNavigating, isTrue);
    await service.dispose();
  });

  test('missing campus router fails cleanly and does not wedge start()',
      () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final service =
        _service(location, FakeRouter([_northRoute]), FakeCompass());
    await expectLater(
      service.start(destination: _p(0, 100), campusNavigation: true),
      throwsA(isA<NavigationFailure>()),
    );
    expect(service.isStarting, isFalse);
    await service.start(destination: _p(0, 100));
    expect(service.isNavigating, isTrue);
    await service.dispose();
  });

  test('reroutes in standard mode after leaving the route', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final router = FakeRouter([
      _northRoute,
      (origin, destination) => RouteResult(
            polyline: [origin, _p(30, 100), destination],
            distanceMeters: 110,
            durationSeconds: 90,
          ),
    ]);
    final service = _service(location, router, FakeCompass());
    await service.start(destination: _p(0, 100));

    // Walk east, away from the north-bound route.
    for (var i = 1; i <= 20; i++) {
      location.controller.add(_fix(i * 1.6, 0, i));
      await _settle(5);
    }
    await _settle();
    expect(router.origins.length, greaterThanOrEqualTo(2));
    expect(service.isNavigating, isTrue);
    expect(service.snapshot.distanceFromRouteMeters!, lessThan(20));
    await service.dispose();
  });

  test('a failed reroute never ends the session', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final router = FakeRouter([
      _northRoute,
      (origin, destination) => throw const RoutingFailure(
          RoutingErrorType.networkError, 'offline'),
    ]);
    final service = _service(location, router, FakeCompass());
    final states = <NavigationState>[];
    service.snapshots.listen((s) => states.add(s.state));
    await service.start(destination: _p(0, 100));

    for (var i = 1; i <= 25; i++) {
      location.controller.add(_fix(i * 1.6, 0, i));
      await _settle(5);
    }
    await _settle(1500);
    expect(states, contains(NavigationState.recovering));
    expect(service.isNavigating, isTrue);
    // Off route: the cue aims back toward the route, i.e. not forward.
    expect(service.snapshot.isOffRoute, isTrue);
    expect(service.snapshot.direction, isNot(NavigationDirection.forward));
    await service.dispose();
  });

  test('without compass, a walking user is guided by GPS course', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final compass = FakeCompass()..enabled = false;
    final service = _service(location, FakeRouter([_northRoute]), compass);
    await service.start(destination: _p(0, 100));
    expect(service.isNavigating, isTrue);
    expect(service.snapshot.state, NavigationState.recovering);

    for (var i = 1; i <= 4; i++) {
      location.controller.add(_fix(0, i * 1.3, i, speed: 1.3, course: 2));
      await _settle(5);
    }
    await _settle();
    expect(service.snapshot.state, NavigationState.navigating);
    expect(service.snapshot.headingSource, HeadingSource.gpsCourse);
    expect(service.snapshot.direction, NavigationDirection.forward);
    await service.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('learns the compass offset from GPS course while walking straight',
      () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    // Phone compass reads 20° left of the true walking direction.
    final compass = FakeCompass()..heading = 340;
    final service = _service(location, FakeRouter([_northRoute]), compass);
    await service.start(destination: _p(0, 100));

    for (var i = 1; i <= 20; i++) {
      location.controller.add(_fix(0, i * 1.3, i, speed: 1.3, course: 0));
      await _settle(40);
    }
    await _settle(1500);
    expect(service.snapshot.courseOffsetDegrees, isNotNull);
    expect(service.snapshot.courseOffsetDegrees!, closeTo(20, 3));
    expect(GeoMath.wrap180(service.snapshot.heading!).abs(), lessThan(5));
    expect(service.snapshot.direction, NavigationDirection.forward);
    await service.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('campus navigation picks the shortest candidate entrance', () async {
    final location = FakeLocationService(_fix(0, 0, 0));
    final campus = FakeRouter([
      (o, d) => RouteResult(
          polyline: [o, d], distanceMeters: 150, durationSeconds: 1),
      (o, d) => RouteResult(
          polyline: [o, d], distanceMeters: 60, durationSeconds: 1),
    ]);
    final service = _service(
      location,
      FakeRouter([_northRoute]),
      FakeCompass(),
      campusRouter: campus,
    );
    await service.start(
      destination: _p(0, 100),
      destinationCandidates: [_p(0, 150), _p(0, 60)],
      campusNavigation: true,
    );
    expect(service.snapshot.route!.distanceMeters, 60);
    await service.dispose();
  });
}
