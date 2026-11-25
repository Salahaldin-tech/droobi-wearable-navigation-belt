import 'package:flutter/material.dart';

import '../core/enums/belt_connection_state.dart';

import '../core/theme/app_colors.dart';
import '../l10n/l10n.dart';

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
          context.tr('Belt disconnected', 'الحزام غير متصل'),
          AppColors.brown.shade700,
          Icons.bluetooth_disabled,
        ),
      BeltConnectionState.scanning => (
          context.tr('Searching for belt...', 'جارٍ البحث عن الحزام...'),
          AppColors.brown,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.connecting => (
          context.tr('Connecting to belt...', 'جارٍ الاتصال بالحزام...'),
          AppColors.brown,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.connected => (
          context.tr('Belt connected', 'الحزام متصل'),
          AppColors.brown.shade700,
          Icons.bluetooth_connected,
        ),
      BeltConnectionState.reconnecting => (
          context.tr('Reconnecting to belt...', 'جارٍ إعادة الاتصال بالحزام...'),
          AppColors.brown.shade800,
          Icons.bluetooth_searching,
        ),
      BeltConnectionState.scanFailed => (
          context.tr('Belt not found', 'لم يُعثر على الحزام'),
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
