import 'package:flutter/material.dart';

import '../core/theme/accessible_theme.dart';

/// Shared button used throughout Droobi so every interactive element
/// gets the same semantics/touch-target treatment automatically,
/// rather than each screen remembering to apply it (Stage 2 rule).
class AccessibleButton extends StatelessWidget {
  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.hint,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? hint;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final button = SizedBox(
      width: fullWidth ? double.infinity : null,
      height: AccessibleTheme.minTouchTargetSize,
      child: ElevatedButton(
        onPressed: onPressed,
        child: child,
      ),
    );

    return Semantics(
      button: true,
      label: label,
      hint: hint,
      enabled: onPressed != null,
      child: button,
    );
  }
}
