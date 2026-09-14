import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/constants/ble_constants.dart';
import '../../core/enums/belt_command.dart';
import '../../core/enums/belt_connection_state.dart';
import 'belt_connection_service.dart';

/// Concrete BLE implementation using flutter_blue_plus.
///
/// This is the ONLY file in the project that imports flutter_blue_plus
/// directly. Everything else depends on [BeltConnectionService].
class FlutterBlueBeltService implements BeltConnectionService {
  FlutterBlueBeltService() {
    // Seed the state stream so early listeners have something to show
    // even before any scan has been attempted.
    _emitState(BeltConnectionState.disconnected);
  }

  final Guid _serviceGuid = Guid(BleConstants.serviceUuid);
  final Guid _characteristicGuid = Guid(BleConstants.commandCharacteristicUuid);

  final StreamController<BeltConnectionState> _stateController =
      StreamController<BeltConnectionState>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  BeltConnectionState _currentState = BeltConnectionState.disconnected;
  BeltCommand? _lastSentCommand;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;

  @override
  void Function()? onReconnected;

  @override
  Stream<BeltConnectionState> get connectionState => _stateController.stream;

  @override
  Stream<String> get logs => _logController.stream;

  @override
  BeltConnectionState get currentState => _currentState;

  @override
  BeltCommand? get lastSentCommand => _lastSentCommand;

  // ---------------------------------------------------------------
  // Scan + Connect
  // ---------------------------------------------------------------

  @override
  Future<void> scanAndConnect() async {
    if (_currentState == BeltConnectionState.connected ||
        _currentState == BeltConnectionState.connecting ||
        _currentState == BeltConnectionState.scanning) {
      return;
    }
    _cancelReconnectTimer();
    _reconnectAttempt = 0;
    await _scanOnce();
  }

  Future<void> _scanOnce() async {
    _emitState(BeltConnectionState.scanning);
    _log('Scanning for ${BleConstants.deviceName}...');

    bool matchFound = false;
    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      if (matchFound) return;
      for (final result in results) {
        final advertisedServices = result.advertisementData.serviceUuids;
        final nameMatches = result.device.platformName == BleConstants.deviceName;
        final serviceMatches = advertisedServices.contains(_serviceGuid);

        if (nameMatches || serviceMatches) {
          matchFound = true;
          await _scanSub?.cancel();
          await FlutterBluePlus.stopScan();
          await _connectToDevice(result.device, isReconnect: false);
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [_serviceGuid],
        timeout: BleConstants.scanTimeout,
      );
    } catch (e) {
      _log('Scan failed to start: $e');
    }

    // Wait out the scan window; startScan's own timeout stops the
    // underlying scan, but we wait here to know when to give up.
    await Future.delayed(BleConstants.scanTimeout);
    await _scanSub?.cancel();

    if (!matchFound && _currentState == BeltConnectionState.scanning) {
      _log('Scan finished: ${BleConstants.deviceName} not found.');
      _emitState(BeltConnectionState.scanFailed);
    }
  }

  Future<void> _connectToDevice(
    BluetoothDevice device, {
    required bool isReconnect,
  }) async {
    _device = device;
    if (!isReconnect) {
      _emitState(BeltConnectionState.connecting);
    }
    _log(isReconnect ? 'Reconnecting to belt...' : 'Connecting to belt...');

    try {
      await device.connect(timeout: BleConstants.connectTimeout);

      await _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleUnexpectedDisconnect();
        }
      });

      final services = await device.discoverServices();
      final beltService = services.firstWhere(
        (s) => s.uuid == _serviceGuid,
        orElse: () => throw Exception('Belt service UUID not found on device'),
      );
      final characteristic = beltService.characteristics.firstWhere(
        (c) => c.uuid == _characteristicGuid,
        orElse: () =>
            throw Exception('Command characteristic UUID not found'),
      );

      _commandCharacteristic = characteristic;
      _reconnectAttempt = 0;
      _cancelReconnectTimer();
      _emitState(BeltConnectionState.connected);
      _log(isReconnect ? 'Belt connected again.' : 'Connected to belt. Ready.');

      _startHeartbeat();

      if (isReconnect) {
        // Per Stage 3/4: after reconnection, the app must send the
        // fresh current direction - never a stale queued one. We
        // don't know "current direction" at this layer (that lives
        // in the future NavigationController); we just fire the hook
        // so whoever owns that state can act on it.
        onReconnected?.call();
      }
    } catch (e) {
      _log('${isReconnect ? "Reconnect" : "Connect"} attempt failed: $e');
      if (isReconnect) {
        _attemptReconnect();
      } else {
        _emitState(BeltConnectionState.scanFailed);
      }
    }
  }

  // ---------------------------------------------------------------
  // Disconnect handling + reconnection backoff
  // ---------------------------------------------------------------

  void _handleUnexpectedDisconnect() {
    if (_currentState == BeltConnectionState.disconnected) {
      return; // already handled (e.g. user-initiated disconnect)
    }
    _stopHeartbeat();
    _commandCharacteristic = null;
    _log('Belt disconnected.');
    _emitState(BeltConnectionState.reconnecting);
    _reconnectAttempt = 0;
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_device == null) {
      _emitState(BeltConnectionState.disconnected);
      return;
    }
    if (_reconnectAttempt >= BleConstants.reconnectBackoff.length) {
      _log(
        'Reconnection failed after '
        '${BleConstants.reconnectBackoff.length} attempts.',
      );
      _emitState(BeltConnectionState.disconnected);
      return;
    }

    final delay = BleConstants.reconnectBackoff[_reconnectAttempt];
    final attemptNumber = _reconnectAttempt + 1;
    _reconnectAttempt++;

    // Deliberately not logging/announcing every single retry per the
    // "do not repeatedly announce" requirement - one log line here is
    // for developer diagnostics on the test screen only, not a TTS
    // announcement (that policy belongs to the future NavigationAnnouncer).
    _log('Reconnect attempt $attemptNumber scheduled in ${delay.inSeconds}s.');

    _reconnectTimer = Timer(delay, () {
      _connectToDevice(_device!, isReconnect: true);
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  @override
  Future<void> disconnect() async {
    _cancelReconnectTimer();
    _stopHeartbeat();
    _reconnectAttempt = 0;

    await _connectionSub?.cancel();
    _connectionSub = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (e) {
        _log('Error during manual disconnect: $e');
      }
    }

    _commandCharacteristic = null;
    _lastSentCommand = null;
    _log('Disconnected (user requested).');
    _emitState(BeltConnectionState.disconnected);
  }

  // ---------------------------------------------------------------
  // Command transmission
  // ---------------------------------------------------------------

  @override
  Future<bool> sendCommand(BeltCommand command) async {
    if (_currentState != BeltConnectionState.connected ||
        _commandCharacteristic == null) {
      _log(
        'Cannot send ${command.wireValue}: not connected. '
        'Command dropped, not queued.',
      );
      return false;
    }

    // Send-on-change dedup, with STOP always bypassing it (safety-critical).
    if (command != BeltCommand.stop && command == _lastSentCommand) {
      _log('Skipped ${command.wireValue}: unchanged from last sent command.');
      return true;
    }

    final success = await _writeRaw(command.wireValue);
    if (success) {
      _lastSentCommand = command;
    }
    return success;
  }

  @override
  Future<bool> sendHeartbeat() async {
    if (_currentState != BeltConnectionState.connected ||
        _commandCharacteristic == null) {
      return false;
    }
    // Heartbeat never touches _lastSentCommand and is never deduped.
    return _writeRaw(BleConstants.heartbeatCommand);
  }

  Future<bool> _writeRaw(String value) async {
    try {
      await _commandCharacteristic!.write(
        utf8.encode(value),
        withoutResponse: false, // write WITH response, per Stage 3
      );
      _log('Sent "$value" - success.');
      return true;
    } catch (e) {
      _log('Sent "$value" - FAILED: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Heartbeat timer
  // ---------------------------------------------------------------

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      BleConstants.heartbeatInterval,
      (_) => sendHeartbeat(),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  void _emitState(BeltConnectionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void _log(String message) {
    _logController.add(message);
  }

  @override
  void dispose() {
    _cancelReconnectTimer();
    _stopHeartbeat();
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _stateController.close();
    _logController.close();
  }
}
