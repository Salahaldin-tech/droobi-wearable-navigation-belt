import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location/gps_filter_service.dart';
import '../services/navigation/compass_service.dart';
import '../services/navigation/direction_calculator.dart';
import '../services/navigation/navigation_service.dart';
import '../services/navigation/route_progress_service.dart';
import '../services/routing/osrm_routing_service.dart';
import 'location_notifier.dart';
import 'routing_notifier.dart';

final navigationServiceProvider =
    Provider<NavigationService>((ref) {
  // Campus routing has its own client instance and configuration.
  // It uses the same public OSRM endpoint as general routing without
  // modifying the general routing provider or its lifecycle.
  final campusRoutingService = OsrmRoutingService(
    baseUrl: 'https://router.project-osrm.org',
    maxSnapRadiusMeters: 20,
  );
  ref.onDispose(campusRoutingService.dispose);

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