
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

    final direction = snapshot.direction;

    if (direction == null) {
      return;
    }

    final command = _beltCommandFromDirection(direction);



await _beltConnectionService.sendCommand(command);
  }

  Future<void> _sendCurrentNavigationCommand() async {
    if (_disposed) {
      return;
    }

    final direction = _navigationService.snapshot.direction;

    if (direction == null) {
      return;
    }

    final command = _beltCommandFromDirection(direction);

    await _beltConnectionService.sendCommand(command);
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
