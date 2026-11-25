import 'package:flutter/material.dart';

import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/university/university_locations_screen.dart';

import '../core/theme/app_colors.dart';
import '../l10n/l10n.dart';

enum DroobiNavItem {
  home,
  favorites,
  university,
  settings,
}

class DroobiBottomNav extends StatelessWidget {
  const DroobiBottomNav({
    super.key,
    required this.currentItem,
  });

  final DroobiNavItem currentItem;

  void _navigate(
    BuildContext context,
    DroobiNavItem item,
  ) {
    if (item == currentItem) return;

    final Widget page;

    switch (item) {
      case DroobiNavItem.home:
        page = const HomeScreen();
        break;
      case DroobiNavItem.favorites:
        page = const FavoritesScreen();
        break;
      case DroobiNavItem.university:
        page = const UniversityLocationsScreen();
        break;
      case DroobiNavItem.settings:
        page = const SettingsScreen();
        break;
    }

    // Slide in from the trailing edge in both LTR and RTL.
    final slideFrom =
        Directionality.of(context) == TextDirection.rtl ? -0.03 : 0.03;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration:
            const Duration(milliseconds: 220),
        reverseTransitionDuration:
            const Duration(milliseconds: 180),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) =>
            page,
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(slideFrom, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The item order and positions of the main navigation bar are fixed
    // and must not be mirrored in Arabic, so the row is always laid out
    // LTR. Only the labels follow the app language and direction.
    final labelDirection = Directionality.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),
        // Floating bar: a soft, wide ambient shadow plus a tighter contact
        // shadow give gentle elevation above the background.
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 10),
              color: AppColors.brown.withValues(alpha: 0.16),
            ),
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 2),
              color: AppColors.brown.withValues(alpha: 0.10),
            ),
          ],
        ),
        // Thin brand frame. Drawn as a foreground decoration so it adds no
        // padding: the items keep exactly the same size and positions.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.brown.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // On narrow phones (< 320px for the row) the item padding
          // tightens and labels may scale down slightly, so the bar never
          // overflows. Wider phones keep the original spacing unchanged.
          child: LayoutBuilder(
            builder: (context, constraints) {
          final compact = constraints.maxWidth < 320;
          return Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              compact: compact,
              label: context.tr('Home', 'الرئيسية'),
              labelDirection: labelDirection,
              active:
                  currentItem == DroobiNavItem.home,
              onTap: () => _navigate(
                context,
                DroobiNavItem.home,
              ),
            ),
            _NavItem(
              icon: Icons.star_outline,
              activeIcon: Icons.star,
              compact: compact,
              label: context.tr('Favorites', 'المفضلة'),
              labelDirection: labelDirection,
              active:
                  currentItem ==
                      DroobiNavItem.favorites,
              onTap: () => _navigate(
                context,
                DroobiNavItem.favorites,
              ),
            ),
            _NavItem(
              icon: Icons.school_outlined,
              activeIcon: Icons.school,
              compact: compact,
              label: context.tr('University', 'الجامعة'),
              labelDirection: labelDirection,
              active:
                  currentItem ==
                      DroobiNavItem.university,
              onTap: () => _navigate(
                context,
                DroobiNavItem.university,
              ),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              compact: compact,
              label: context.tr('Settings', 'الإعدادات'),
              labelDirection: labelDirection,
              active:
                  currentItem ==
                      DroobiNavItem.settings,
              onTap: () => _navigate(
                context,
                DroobiNavItem.settings,
              ),
            ),
          ],
          );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.labelDirection,
    required this.compact,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final TextDirection labelDirection;
  final bool compact;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.brown;
    const inactiveColor = AppColors.brown;

    final item = Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 10,
            vertical: 4,
          ),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: active
                  ? activeColor.withValues(alpha: 0.12)
                  : AppColors.cream,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration:
                  const Duration(milliseconds: 180),
              transitionBuilder:
                  (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(active),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? activeIcon : icon,
                    size: 24,
                    color: active
                        ? activeColor
                        : inactiveColor,
                  ),
                  const SizedBox(height: 3),
                  _maybeScaleDown(
                    Text(
                    label,
                    textDirection: labelDirection,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: active
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: active
                          ? activeColor
                          : inactiveColor,
                    ),
                  ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Regular widths keep the original, natural-size layout. Only on narrow
    // rows do items share the width (and labels scale down if needed).
    return compact ? Flexible(child: item) : item;
  }

  Widget _maybeScaleDown(Widget label) =>
      compact ? FittedBox(fit: BoxFit.scaleDown, child: label) : label;
}