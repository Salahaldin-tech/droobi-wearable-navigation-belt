import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/routing/osrm_routing_service.dart';
import '../services/routing/routing_service.dart';

final routingServiceProvider = Provider<RoutingService>((ref) {
  final service = OsrmRoutingService();

  ref.onDispose(service.dispose);

  return service;
});