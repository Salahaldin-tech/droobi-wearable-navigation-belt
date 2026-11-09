import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Reusable cream surface for list items and grouped settings content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: radius,
          border: Border.all(
            color: AppColors.brown.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brown.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: AppColors.cream,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
