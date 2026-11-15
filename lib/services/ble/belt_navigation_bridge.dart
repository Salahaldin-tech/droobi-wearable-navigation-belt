import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/enums/belt_command.dart';
import '../../models/navigation_direction.dart';
import '../navigation/navigation_service.dart';
import 'belt_connection_service.dart';

class BeltNavigationBridge {
  BeltNavigationBridge({
    required NavigationService navigationService,
    required BeltConnectionService beltConnectionService,
  })  : _navigationService = navigationService,
        _beltConnectionService = beltConnectionService;

  final NavigationService _navigationService;
  final BeltConnectionService _beltConnectionService;

  StreamSubscription<NavigationSnapshot>? _navigationSubscription;

  bool _started = false;
  bool _disposed = false;

  /// Writes are chained so commands reach the belt in snapshot order even
  /// though each BLE write is asynchronous.
  Future<void> _sendChain = Future<void>.value();

  BeltCommand? _lastRequested;
  DateTime? _lastStopAt;

  /// STOP bypasses the connection service's dedup by design. Recovery states
  /// can publish many consecutive snapshots, so identical STOPs are collapsed
  /// here; one is still re-sent periodically as a safety refresh.
  static const Duration _stopRefreshInterval = Duration(seconds: 2);

  void start() {
    debugPrint('[BLE BRIDGE] Started');

    if (_started || _disposed) {
      return;
    }

    _started = true;

    _navigationSubscription =
        _navigationService.snapshots.listen(_handleNavigationSnapshot);

    _beltConnectionService.onReconnected =
        _sendCurrentNavigationCommand;
  }

  Future<void> _handleNavigationSnapshot(
    NavigationSnapshot snapshot,
  ) async {
    if (_disposed) {
      return;
    }

    // Destination reached: pulse all four belt motors together.
    // This is a one-shot firmware pattern, not a navigation direction.
    if (snapshot.state == NavigationState.arrived) {
      await _enqueue(BeltCommand.arrived);
      return;
    }

    final direction = snapshot.direction;

    // Fail safe for GPS errors, recovery states, or any snapshot
    // without a valid direction: never leave an old pattern running.
    if (direction == null ||
        snapshot.state == NavigationState.gpsUnavailable ||
        snapshot.state == NavigationState.routeUnavailable) {
      await _enqueue(BeltCommand.stop);
      return;
    }

    await _enqueue(_beltCommandFromDirection(direction));
  }

  Future<void> _enqueue(BeltCommand command, {bool force = false}) {
    if (!force && command == BeltCommand.stop && _lastRequested == BeltCommand.stop) {
      final last = _lastStopAt;
      if (last != null && DateTime.now().difference(last) < _stopRefreshInterval) {
        return _sendChain;
      }
    }
    _lastRequested = command;
    if (command == BeltCommand.stop) _lastStopAt = DateTime.now();

    final next = _sendChain.then((_) async {
      if (_disposed) return;
      try {
        await _beltConnectionService.sendCommand(command);
      } catch (error) {
        debugPrint('[BLE BRIDGE] Failed to send ${command.wireValue}: $error');
      }
    });
    _sendChain = next;
    return next;
  }

  Future<void> _sendCurrentNavigationCommand() async {
    if (_disposed) {
      return;
    }

    final snapshot = _navigationService.snapshot;
    final direction = snapshot.direction;

    // Do not replay an arrival pulse or stale direction on reconnect.
    // If there is no current navigation direction, explicitly stop.
    final command = direction == null ||
            snapshot.state != NavigationState.navigating
        ? BeltCommand.stop
        : _beltCommandFromDirection(direction);

    await _enqueue(command, force: true);
  }

  BeltCommand _beltCommandFromDirection(
    NavigationDirection direction,
  ) {
    switch (direction) {
      case NavigationDirection.forward:
        return BeltCommand.front;
      case NavigationDirection.back:
        return BeltCommand.back;
      case NavigationDirection.left:
        return BeltCommand.left;
      case NavigationDirection.right:
        return BeltCommand.right;
      case NavigationDirection.backLeft:
        return BeltCommand.backLeft;
      case NavigationDirection.backRight:
        return BeltCommand.backRight;
      case NavigationDirection.forwardLeft:
        return BeltCommand.frontLeft;
      case NavigationDirection.forwardRight:
        return BeltCommand.frontRight;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _navigationSubscription?.cancel();
    _navigationSubscription = null;

    _beltConnectionService.onReconnected = null;
  }
}
