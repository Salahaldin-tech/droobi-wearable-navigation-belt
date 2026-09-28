import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location/gps_filter_service.dart';
import '../services/navigation/compass_service.dart';
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