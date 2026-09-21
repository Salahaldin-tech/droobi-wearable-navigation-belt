import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../core/enums/voice_command_state.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/voice_command_notifier.dart';
import '../../widgets/connection_status_indicator.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/voice_command_button.dart';
import '../destination/destination_search_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import '../university/university_locations_screen.dart';

/// Droobi Home Screen.
///
/// Light and airy design on top of the original map background:
/// - soft animated gradient over the map
/// - fade/slide-in entrance for the header, search bar and belt card
/// - frosted-glass search bar and belt card
/// - animated belt status dot
/// - side menu with a welcome header and slide-in animation
///
/// The microphone, its press-and-hold wiring, the voice-to-search
/// navigation and the bottom navigation are unchanged.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  static const Color _blue = Color(0xFF2F80ED);
  static const Color _green = Color(0xFF27AE60);
  static const Color _grey = Color(0xFF9CA3AF);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);

  late final AnimationController _entranceController;
  late final AnimationController _backgroundController;

  late final Animation<double> _headerAnimation;
  late final Animation<double> _searchAnimation;
  late final Animation<double> _beltAnimation;

  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _headerAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );

    _searchAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.70, curve: Curves.easeOutCubic),
    );

    _beltAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.30, 0.85, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the system "remove animations" setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) {
      _entranceController.value = 1.0;
      _backgroundController.stop();
    } else {
      if (!_entranceStarted) {
        _entranceStarted = true;
        _entranceController.forward();
      }

      if (!_backgroundController.isAnimating) {
        _backgroundController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  void _handleMicPress() {
    ref.read(voiceCommandProvider.notifier).onMicPress();
  }

  void _handleMicRelease() {
    ref.read(voiceCommandProvider.notifier).onMicRelease();
  }

  /// Name of the signed-in user, or an empty string if it is not known.
  String _currentUserName() {
    final user = ref.read(authStateProvider).value;
    final String? rawName = user?.displayName;

    return (rawName ?? '').trim();
  }

  /// Fade + small upward slide, driven by one of the entrance animations.
  Widget _fadeSlide(Animation<double> animation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ),
        ),
        child: child,
      ),
    );
  }

  /// Frosted-glass container: blurred map behind a translucent white layer.
  Widget _glassCard({
    required Widget child,
    double radius = 12,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(beltConnectionStateProvider);
    final beltService = ref.watch(beltConnectionServiceProvider);

    final beltState =
        connectionAsync.value ?? beltService.currentState;

    final isBeltConnected =
        beltState == BeltConnectionState.connected;

    final voiceState = ref.watch(voiceCommandProvider);

    // ------------------------------------------------------------------
    // VOICE RESULT -> DESTINATION SEARCH SCREEN
    //
    // The notifier runs the search when the 2.5 second confirmation
    // window ends (phase: recognized -> processing). At that moment the
    // Destination Search screen is opened so the user sees the same
    // query and results as if they had typed the text themselves.
    // ------------------------------------------------------------------
    ref.listen<VoiceCommandState>(voiceCommandProvider, (previous, next) {
      final searchStarted =
          previous?.phase == VoiceCommandPhase.recognized &&
              next.phase == VoiceCommandPhase.processing;

      if (!searchStarted) {
        return;
      }

      // Do nothing if another screen is already on top of Home.
      if (ModalRoute.of(context)?.isCurrent != true) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DestinationSearchScreen(),
        ),
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ================================================================
          // MAP BACKGROUND
          // ================================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/home_bg.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (
                  context,
                  error,
                  stackTrace,
                  ) {
                return const SizedBox.shrink();
              },
            ),
          ),

          // ================================================================
          // WHITE OVERLAY
          // Keeps the map visible but subtle.
          // ================================================================

          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(
                alpha: 0.10,
              ),
            ),
          ),

          // ================================================================
          // SOFT ANIMATED GRADIENT
          // Very light blue and mint tints that drift slowly.
          // ================================================================

          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _backgroundController,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(
                      _backgroundController.value,
                    );

                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.lerp(
                            Alignment.topLeft,
                            Alignment.topRight,
                            t,
                          )!,
                          end: Alignment.lerp(
                            Alignment.bottomRight,
                            Alignment.bottomLeft,
                            t,
                          )!,
                          colors: [
                            const Color(0xFFDCEBFF)
                                .withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.10),
                            const Color(0xFFD9F5EA)
                                .withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ================================================================
          // HOME UI
          // ================================================================

          SafeArea(
            child: Column(
              children: [
                // ==========================================================
                // HEADER
                // ==========================================================

                _fadeSlide(
                  _headerAnimation,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      16,
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        // --------------------------------------------------
                        // APP NAME
                        // --------------------------------------------------

                        const Text(
                          'Droobi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: _text,
                          ),
                        ),

                        // --------------------------------------------------
                        // MENU BUTTON
                        // --------------------------------------------------

                        Semantics(
                          button: true,
                          label: 'Open menu',
                          child: Material(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(10),
                            elevation: 3,
                            child: InkWell(
                              borderRadius:
                              BorderRadius.circular(10),
                              onTap: () {
                                _showMenu(context);
                              },
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(
                                  Icons.menu,
                                  size: 24,
                                  color: _text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================================
                // SEARCH DESTINATION (frosted glass)
                // ==========================================================

                _fadeSlide(
                  _searchAnimation,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                    ),
                    child: Semantics(
                      button: true,
                      label: 'Search destination',
                      hint: 'Open destination search',
                      child: _glassCard(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius:
                            BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const DestinationSearchScreen(),
                                ),
                              );
                            },
                            child: Container(
                              height: 52,
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 22,
                                    color: Color(0xFF777777),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Search destination...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // BELT CONNECTION STATUS (frosted glass + animated dot)
                // ==========================================================

                _fadeSlide(
                  _beltAnimation,
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: _glassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment:
                                  Alignment.centerLeft,
                                  child: ConnectionStatusIndicator(
                                    state: beltState,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Decorative: the indicator above already
                              // describes the state to screen readers.
                              ExcludeSemantics(
                                child: _StatusDot(
                                  color: isBeltConnected
                                      ? _green
                                      : _grey,
                                  pulse: isBeltConnected,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ==========================================================
                // MAIN CONTENT
                // ==========================================================

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      // ----------------------------------------------------
                      // MICROPHONE
                      // ----------------------------------------------------

                      VoiceCommandButton(
                        state: voiceState,
                        onPressStart: () {
                          _handleMicPress();
                        },
                        onPressEnd: () {
                          _handleMicRelease();
                        },
                      ),

                      const SizedBox(height: 16),

                      // ----------------------------------------------------
                      // RECOGNIZED TEXT
                      // ----------------------------------------------------

                      if (voiceState.phase ==
                          VoiceCommandPhase.recognized)
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          child: Text(
                            'Heard: "${voiceState.recognizedText}"',
                            textAlign: TextAlign.center,
                            style:
                            Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),

                      // ----------------------------------------------------
                      // ERROR
                      // ----------------------------------------------------

                      if (voiceState.phase ==
                          VoiceCommandPhase.error)
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          child: Text(
                            voiceState.errorMessage ?? '',
                            textAlign: TextAlign.center,
                            style:
                            const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ==========================================================
                // SHARED BOTTOM NAVIGATION
                // ==========================================================

                const DroobiBottomNav(
                  currentItem:
                  DroobiNavItem.home,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SIDE MENU
  // ===========================================================================

  void _showMenu(BuildContext context) {
    final userName = _currentUserName();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black.withValues(
        alpha: 0.50,
      ),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
          ) {
        // Slide in from the left instead of the default fade.
        return SlideTransition(
          position: animation
              .drive(CurveTween(curve: Curves.easeOutCubic))
              .drive(
            Tween<Offset>(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );
      },
      pageBuilder: (
          context,
          animation,
          secondaryAnimation,
          ) {
        final topInset = MediaQuery.of(context).padding.top;

        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.white,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(24),
            ),
            child: SizedBox(
              width: 300,
              height: double.infinity,
              child: Column(
                children: [
                  // ========================================================
                  // MENU HEADER: logo + welcome
                  // ========================================================

                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      topInset + 20,
                      12,
                      24,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFEAF3FF),
                          Color(0xFFDDF3EA),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                    color: Color(0x18000000),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/app_logo.png',
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                    ) {
                                  return const Icon(
                                    Icons.explore,
                                    color: _blue,
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close menu',
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pop();
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        if (userName.isNotEmpty) ...[
                          const Text(
                            'Welcome,',
                            style: TextStyle(
                              fontSize: 14,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                          ),
                        ] else
                          const Text(
                            'Welcome to Droobi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ========================================================
                  // MENU ITEMS
                  // ========================================================

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        16,
                      ),
                      children: [
                        // ==================================================
                        // HOME
                        // ==================================================

                        _MenuItem(
                          icon: Icons.home,
                          label: 'Home',
                          active: true,
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();
                          },
                        ),

                        // ==================================================
                        // FAVORITES
                        // ==================================================

                        _MenuItem(
                          icon: Icons.star,
                          label: 'Favorites',
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const FavoritesScreen(),
                              ),
                            );
                          },
                        ),

                        // ==================================================
                        // UNIVERSITY
                        // ==================================================

                        _MenuItem(
                          icon: Icons.school,
                          label: 'University',
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const UniversityLocationsScreen(),
                              ),
                            );
                          },
                        ),

                        // ==================================================
                        // SETTINGS
                        // ==================================================

                        _MenuItem(
                          icon: Icons.settings,
                          label: 'Settings',
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// BELT STATUS DOT
// A small dot; when [pulse] is true a soft ring expands and fades around it.
// ============================================================================

class _StatusDot extends StatefulWidget {
  const _StatusDot({
    required this.color,
    required this.pulse,
  });

  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (widget.pulse && !reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                Container(
                  width: 10 + 12 * t,
                  height: 10 + 12 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(
                      alpha: 0.35 * (1 - t),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// SIDE MENU ITEM
// ============================================================================

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2F80ED);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: active
              ? blue.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: blue,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: active
                          ? blue
                          : const Color(0xFF111111),
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