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
  BeltCommand? _lastCommand;

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

    if (snapshot.state == NavigationState.arrived) {
      if (_lastCommand != BeltCommand.arrived) {
        await _beltConnectionService.sendCommand(BeltCommand.arrived);
        _lastCommand = BeltCommand.arrived;
      }
      return;
    }

    final direction = snapshot.direction;
    final guidanceAllowed =
        snapshot.state == NavigationState.navigating ||
        snapshot.state == NavigationState.approaching;

    if (!guidanceAllowed || direction == null) {
      if (_lastCommand != BeltCommand.stop) {
        await _beltConnectionService.sendCommand(BeltCommand.stop);
        _lastCommand = BeltCommand.stop;
      }
      return;
    }

    final command = _beltCommandFromDirection(direction);
    if (_lastCommand != command) {
      await _beltConnectionService.sendCommand(command);
      _lastCommand = command;
    }
  }

  Future<void> _sendCurrentNavigationCommand() async {
    if (_disposed) {
      return;
    }

    final snapshot = _navigationService.snapshot;
    final direction = snapshot.direction;

    // Do not replay an arrival pulse or stale direction on reconnect.
    // If there is no current navigation direction, explicitly stop.
    final canGuide = direction != null &&
        (snapshot.state == NavigationState.navigating ||
            snapshot.state == NavigationState.approaching);
    final command = canGuide
        ? _beltCommandFromDirection(direction)
        : BeltCommand.stop;
    await _beltConnectionService.sendCommand(command);
    _lastCommand = command;
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
