import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_command.dart';
import '../../core/enums/belt_connection_state.dart';
import '../../services/ble/belt_connection_service.dart';
import '../../state/belt_connection_notifier.dart';

/// TEMPORARY screen for Stage 5 validation only.
///
/// Purpose: prove the Flutter-side BLE layer can reliably scan,
/// connect, send commands, observe connection state changes, and
/// maintain the heartbeat against the real ESP32 - before any real
/// UI, GPS, routing, Firebase, or voice input exists.
///
/// This screen is NOT part of the final Droobi UI and should be
/// removed/replaced once Stage 5's real screens are built.
class BleTestScreen extends ConsumerStatefulWidget {
  const BleTestScreen({super.key});

  @override
  ConsumerState<BleTestScreen> createState() => _BleTestScreenState();
}

class _BleTestScreenState extends ConsumerState<BleTestScreen> {
  final ListQueue<String> _logLines = ListQueue<String>();
  static const int _maxLogLines = 100;

  BeltCommand? _lastUserSelectedCommand;

  @override
  void initState() {
    super.initState();

    // Hook the "resend fresh current command after reconnection" rule.
    // In the real app this hook belongs to the future NavigationController;
    // here we simulate "current direction" as whatever button the tester
    // last pressed, purely to demonstrate/validate the behavior.
    final service = ref.read(beltConnectionServiceProvider);
    service.onReconnected = () {
      final current = _lastUserSelectedCommand;
      if (current != null) {
        service.sendCommand(current);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(beltConnectionStateProvider);
    final service = ref.watch(beltConnectionServiceProvider);

    // Fall back to the service's synchronous snapshot before the
    // stream emits its first event.
    final BeltConnectionState state =
        connectionAsync.value ?? service.currentState;

    ref.listen<AsyncValue<String>>(beltLogProvider, (previous, next) {
      final line = next.value;
      if (line == null) return;
      setState(() {
        _logLines.addFirst(line);
        while (_logLines.length > _maxLogLines) {
          _logLines.removeLast();
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Droobi - BLE Test (Stage 5)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBanner(state: state),
            const SizedBox(height: 12),
            _ConnectionControls(service: service, state: state),
            const SizedBox(height: 16),
            Text(
              'Navigation commands (send-on-change; STOP always sent)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            _CommandGrid(
              enabled: state == BeltConnectionState.connected,
              onCommandPressed: (command) {
                _lastUserSelectedCommand = command;
                service.sendCommand(command);
              },
              onHeartbeatPressed: () => service.sendHeartbeat(),
            ),
            const SizedBox(height: 16),
            Text('Log', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Expanded(child: _LogView(lines: _logLines)),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final BeltConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      BeltConnectionState.disconnected => ('Disconnected', Colors.grey),
      BeltConnectionState.scanning => ('Scanning...', Colors.blue),
      BeltConnectionState.connecting => ('Connecting...', Colors.blue),
      BeltConnectionState.connected => ('Connected', Colors.green),
      BeltConnectionState.reconnecting => ('Reconnecting...', Colors.orange),
      BeltConnectionState.scanFailed => ('Belt not found', Colors.red),
    };

    // Status is communicated via text label (screen-reader visible)
    // AND color/icon - never color alone, consistent with the
    // project's accessibility requirements even in this test screen.
    return Semantics(
      liveRegion: true,
      label: 'Belt connection status: $label',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          children: [
            Icon(Icons.bluetooth, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionControls extends StatelessWidget {
  const _ConnectionControls({required this.service, required this.state});

  final BeltConnectionService service;
  final BeltConnectionState state;

  @override
  Widget build(BuildContext context) {
    final isBusy = state == BeltConnectionState.scanning ||
        state == BeltConnectionState.connecting ||
        state == BeltConnectionState.reconnecting;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isBusy || state == BeltConnectionState.connected
                ? null
                : () => service.scanAndConnect(),
            child: const Text('Scan & Connect'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: state == BeltConnectionState.connected ||
                    state == BeltConnectionState.reconnecting
                ? () => service.disconnect()
                : null,
            child: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }
}

class _CommandGrid extends StatelessWidget {
  const _CommandGrid({
    required this.enabled,
    required this.onCommandPressed,
    required this.onHeartbeatPressed,
  });

  final bool enabled;
  final void Function(BeltCommand command) onCommandPressed;
  final VoidCallback onHeartbeatPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final command in BeltCommand.values)
          _CommandButton(
            label: command.label,
            isStop: command == BeltCommand.stop,
            onPressed: enabled ? () => onCommandPressed(command) : null,
          ),
        _CommandButton(
          label: 'HB (manual)',
          isStop: false,
          onPressed: enabled ? onHeartbeatPressed : null,
        ),
      ],
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({
    required this.label,
    required this.isStop,
    required this.onPressed,
  });

  final String label;
  final bool isStop;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 56, // meets the >=48dp accessible touch target minimum
      child: Semantics(
        button: true,
        label: 'Send command $label',
        child: ElevatedButton(
          style: isStop
              ? ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  const _LogView({required this.lines});

  final Iterable<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: ListView(
        children: [
          for (final line in lines)
            Text(
              line,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
        ],
      ),
    );
  }
}
