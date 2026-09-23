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

    lookAheadMeters: 10.0,

    arrivalDistanceMeters: 8.0,
  );

  ref.onDispose(service.dispose);

  return service;
});