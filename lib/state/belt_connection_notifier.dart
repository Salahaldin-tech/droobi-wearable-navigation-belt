import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums/belt_connection_state.dart';
import '../services/ble/belt_connection_service.dart';
import '../services/ble/flutter_blue_belt_service.dart';

/// The single BeltConnectionService instance for the app.
///
/// Only this provider knows the concrete implementation
/// (FlutterBlueBeltService). Everywhere else in the app should depend
/// on [BeltConnectionService] (the interface) via this provider, so
/// swapping the BLE package later means changing this one line.
final beltConnectionServiceProvider = Provider<BeltConnectionService>((ref) {
  final service = FlutterBlueBeltService();
  ref.onDispose(service.dispose);
  return service;
});

/// Current belt connection state, as a stream the UI can watch.
final beltConnectionStateProvider = StreamProvider<BeltConnectionState>((ref) {
  final service = ref.watch(beltConnectionServiceProvider);
  return service.connectionState;
});

/// Diagnostic log lines (connection events, write success/failure).
/// Used by the Stage 5 temporary test screen.
final beltLogProvider = StreamProvider<String>((ref) {
  final service = ref.watch(beltConnectionServiceProvider);
  return service.logs;
});
