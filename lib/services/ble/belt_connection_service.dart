import '../../core/enums/belt_command.dart';
import '../../core/enums/belt_connection_state.dart';

/// Abstract interface for belt BLE communication.
///
/// The rest of the app depends ONLY on this interface, never on the
/// underlying BLE package directly. This is what lets us swap
/// flutter_blue_plus for a different package later without touching
/// any other layer (state notifiers, screens, future NavigationService).
abstract class BeltConnectionService {
  /// Emits every time the connection lifecycle state changes.
  Stream<BeltConnectionState> get connectionState;

  /// Emits human-readable log lines (connection events, write
  /// success/failure) for diagnostics - used by the Stage 5 test screen.
  Stream<String> get logs;

  /// Synchronous snapshot of the current state, useful for initial UI
  /// render before the first stream event arrives.
  BeltConnectionState get currentState;

  /// The last navigation command actually written to the belt.
  /// Null if nothing has been sent yet (e.g. fresh connection).
  BeltCommand? get lastSentCommand;

  /// Called once after a successful connection or reconnection
  /// (manual or automatic-backoff). The app layer should use this
  /// hook to (re)send the freshly computed current navigation
  /// command - per the "never resend a stale queued command" rule.
  set onReconnected(void Function()? callback);

  /// Starts scanning for a device advertising [BleConstants.serviceUuid]
  /// and connects to it if found. No-op if already connected/connecting.
  Future<void> scanAndConnect();

  /// User-initiated disconnect. Cancels any in-progress reconnection
  /// attempts and stops the heartbeat.
  Future<void> disconnect();

  /// Sends a navigation command.
  ///
  /// Enforces send-on-change: if [command] equals [lastSentCommand],
  /// the write is skipped (returns true - this is expected behavior,
  /// not an error). BeltCommand.stop always bypasses this dedup and
  /// is always transmitted.
  ///
  /// Returns false (and never queues) if not currently connected.
  Future<bool> sendCommand(BeltCommand command);

  /// Sends the heartbeat payload. Never affects [lastSentCommand] and
  /// never subject to dedup - always attempted while connected.
  Future<bool> sendHeartbeat();

  /// Releases all resources (timers, subscriptions, BLE connections).
  void dispose();
}
