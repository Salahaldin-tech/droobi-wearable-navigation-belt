
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/belt_connection_state.dart';
import '../services/ble/belt_connection_service.dart';
import '../services/ble/belt_navigation_bridge.dart';
import '../services/ble/flutter_blue_belt_service.dart';
import 'navigation_notifier.dart';

final beltConnectionServiceProvider = Provider<BeltConnectionService>((ref) {
  final service = FlutterBlueBeltService();

  ref.onDispose(service.dispose);

  return service;
});

final beltConnectionStateProvider = StreamProvider<BeltConnectionState>((ref) {
  final service = ref.watch(beltConnectionServiceProvider);

  return service.connectionState;
});

final beltLogProvider = StreamProvider<String>((ref) {
  final service = ref.watch(beltConnectionServiceProvider);

  return service.logs;
});

final beltNavigationBridgeProvider = Provider<BeltNavigationBridge>((ref) {
  final navigationService = ref.read(navigationServiceProvider);
  final beltConnectionService = ref.read(beltConnectionServiceProvider);

  final bridge = BeltNavigationBridge(
    navigationService: navigationService,
    beltConnectionService: beltConnectionService,
  );

  bridge.start();

  ref.onDispose(bridge.dispose);

  return bridge;
});

