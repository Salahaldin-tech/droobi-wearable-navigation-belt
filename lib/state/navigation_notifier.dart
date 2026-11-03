import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location/gps_filter_service.dart';
import '../services/navigation/compass_service.dart';
import '../services/routing/campus_routing_service.dart';
import '../services/navigation/direction_calculator.dart';
import '../services/navigation/navigation_service.dart';
import '../services/navigation/route_progress_service.dart';
import 'location_notifier.dart';
import 'routing_notifier.dart';

final navigationServiceProvider =
    Provider<NavigationService>((ref) {
  final service = NavigationService(
    locationService:
        ref.read(locationServiceProvider),

    routingService:
        ref.read(routingServiceProvider),

    compassService:
        CompassService(),

    gpsFilterService:
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

/// Separate navigation engine for the university campus. It uses the
/// offline GPS Logger graph and stricter campus-specific positioning settings;
/// the normal navigation provider continues to use OSRM.
final campusNavigationServiceProvider = Provider<NavigationService>((ref) {
  final service = NavigationService(
    locationService: ref.read(locationServiceProvider),
    routingService: CampusRoutingService(),
    compassService: CompassService(),
    gpsFilterService: GpsFilterService(
      maxAccuracyMeters: 12.0,
      maxWalkingSpeedMetersPerSecond: 2.5,
    ),
    routeProgressService: RouteProgressService(
      defaultLookAheadMeters: 3.0,
      minimumLookAheadMeters: 1.5,
      maximumLookAheadMeters: 4.0,
      turnDetectionAngleDegrees: 25.0,
    ),
    directionCalculator: DirectionCalculator(),
    lookAheadMeters: null,
    arrivalDistanceMeters: 3.0,
    compassSampleCount: 3,
    minimumHeadingChangeDegrees: 4.0,
    directionConfirmationSamples: 2,
  );
  ref.onDispose(service.dispose);
  return service;
});
