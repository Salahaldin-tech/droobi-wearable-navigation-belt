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
    this.originSnapMeters,
    this.destinationSnapMeters,
  });

  /// Ordered list of points from origin to destination.
  final List<LatLon> polyline;

  final double distanceMeters;
  final double durationSeconds;

  /// How far the router moved the origin onto its network, when reported.
  final double? originSnapMeters;

  /// How far the router moved the destination onto its network, when
  /// reported. The route ends this far from the requested destination.
  final double? destinationSnapMeters;
}
