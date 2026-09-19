import '../../models/lat_lon.dart';
import '../../models/route_result.dart';

enum RoutingErrorType { networkError, noRouteFound, apiError, unknown }

class RoutingFailure implements Exception {
  const RoutingFailure(this.type, this.message);

  final RoutingErrorType type;
  final String message;

  @override
  String toString() => message;
}

/// Abstract interface for computing a walking route between two
/// points. Depends only on [LatLon] - never on Destination or any
/// other search/UI model (spec point #2: search and routing are
/// connected only by this coordinate contract).
abstract class RoutingService {
  Future<RouteResult> computeRoute({
    required LatLon origin,
    required LatLon destination,
  });
}
