import 'package:flutter/material.dart';

import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/university/university_locations_screen.dart';

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
                begin: const Offset(0.03, 0),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, 4),
              color: Color(0x18000000),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Home',
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
              label: 'Favorites',
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
              label: 'University',
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
              label: 'Settings',
              active:
                  currentItem ==
                      DroobiNavItem.settings,
              onTap: () => _navigate(
                context,
                DroobiNavItem.settings,
              ),
            ),
          ],
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
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF2F80ED);
    const inactiveColor = Color(0xFF777777);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: active
                  ? activeColor.withValues(alpha: 0.10)
                  : Colors.transparent,
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
                  Text(
                    label,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}