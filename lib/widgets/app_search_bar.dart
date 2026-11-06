import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Shared cream-and-brown search field used by Home and the campus guide.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    this.onTap,
    this.onSubmitted,
    this.readOnly = false,
    this.showSearchIcon = false,
  });

  final TextEditingController? controller;
  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;
  final bool showSearchIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brown, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.brown.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 14, color: AppColors.brown),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.brown.withValues(alpha: 0.6),
              ),
              prefixIcon: showSearchIcon
                  ? const Icon(Icons.search, size: 20, color: AppColors.brown)
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
