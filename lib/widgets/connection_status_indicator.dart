import 'package:flutter/material.dart';

import '../core/enums/belt_connection_state.dart';

import '../core/theme/app_colors.dart';

/// Displays belt connection status via text + icon + color together,
/// never color alone (Stage 2/4 accessibility requirement). Marked as
/// a live region so screen readers announce changes automatically.
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key, required this.state});

  final BeltConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (state) {
      BeltConnectionState.disconnected => (
          'Belt disconnected',
          AppColors.brown.shade700,
          Icons.bluetooth_disabled,
        ),
      BeltConnectionState.scanning => (
          'Searching for belt...',
          AppColors.brown,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.connecting => (
          'Connecting to belt...',
          AppColors.brown,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.connected => (
          'Belt connected',
          AppColors.brown.shade700,
          Icons.bluetooth_connected,
        ),
      BeltConnectionState.reconnecting => (
          'Reconnecting to belt...',
          AppColors.brown.shade800,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.scanFailed => (
          'Belt not found',
          AppColors.brown.shade700,
          Icons.bluetooth_disabled,
        ),
    };

    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
