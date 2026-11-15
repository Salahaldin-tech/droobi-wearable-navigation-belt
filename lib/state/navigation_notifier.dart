import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location/gps_filter_service.dart';
import '../services/navigation/compass_service.dart';
import '../services/navigation/direction_calculator.dart';
import '../services/navigation/navigation_service.dart';

import '../services/navigation/route_progress_service.dart';
import '../services/routing/osrm_routing_service.dart';
import '../services/routing/routing_service.dart';
import 'location_notifier.dart';
import 'routing_notifier.dart';

final navigationServiceProvider =
    Provider<NavigationService>((ref) {
  // Campus routing needs an OSRM server built with the foot profile (see
  // docs/campus-mapping/OSM_OSRM_INTEGRATION_V4.md). Its URL is supplied at
  // build time:
  //   flutter run --dart-define=CAMPUS_OSRM_URL=http://<PC-LAN-IP>:5001
  // Responses that are not walking routes are rejected, so a car-profile
  // server can never silently guide a pedestrian along roads.
  const campusOsrmUrl = String.fromEnvironment('CAMPUS_OSRM_URL');
  final RoutingService campusRoutingService;
  if (campusOsrmUrl.isEmpty) {
    campusRoutingService = const UnconfiguredRoutingService(
      'Campus routing server is not configured. Build the app with '
      '--dart-define=CAMPUS_OSRM_URL=http://<server>:5001.',
    );
  } else {
    final osrm = OsrmRoutingService(
      baseUrl: campusOsrmUrl,
      maxSnapRadiusMeters: 20,
      requireWalkingMode: true,
    );
    ref.onDispose(osrm.dispose);
    campusRoutingService = osrm;
  }

  final service = NavigationService(
    locationService:
        ref.read(locationServiceProvider),

    routingService:
        ref.read(routingServiceProvider),

    campusRoutingService: campusRoutingService,

    compassService:
        CompassService(),


    gpsFilterService:
        GpsFilterService(),

    campusGpsFilterService:
        GpsFilterService(),

    routeProgressService:
        RouteProgressService(),

    directionCalculator:
        DirectionCalculator(),

    // Let RouteProgressService choose the adaptive
    // look-ahead distance automatically.
    //
    // It can use shorter distances near turns instead
    // of always forcing a fixed 10 meter target.
    lookAheadMeters: null,

    arrivalDistanceMeters: 8.0,
  );

  ref.onDispose(service.dispose);

  return service;
});