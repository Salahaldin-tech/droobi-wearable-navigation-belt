import 'lat_lon.dart';

/// A calculated route, as returned by RoutingService.
///
/// Deliberately just a polyline + summary numbers - NOT turn-by-turn
/// text (spec point #1: OSRM/foot profile returns geometry, not
/// instructions). Direction is derived downstream by
/// DirectionCalculator from this polyline plus live position/heading,
/// not from anything in this model.
class RouteResult {
  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  /// Ordered list of points from origin to destination.
  final List<LatLon> polyline;

  final double distanceMeters;
  final double durationSeconds;
}
