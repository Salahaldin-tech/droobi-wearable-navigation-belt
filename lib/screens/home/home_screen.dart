import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/voice_command_state.dart';
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
/// Preserves the original Home Screen visual design while using
/// the new press-and-hold voice interaction:
///
/// Press and hold microphone
///       ↓
/// Start recording
///       ↓
/// Release microphone
///       ↓
/// Stop recording
///       ↓
/// Local Whisper transcription
///       ↓
/// 2.5 second confirmation window
///       ↓
/// Automatic destination search
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _handleMicPress(WidgetRef ref) {
    ref.read(voiceCommandProvider.notifier).onMicPress();
  }

  void _handleMicRelease(WidgetRef ref) {
    ref.read(voiceCommandProvider.notifier).onMicRelease();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(beltConnectionStateProvider);
    final beltService = ref.watch(beltConnectionServiceProvider);

    final beltState =
        connectionAsync.value ?? beltService.currentState;

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
                alpha: 0.35,
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
                      // ----------------------------------------------------
                      // APP NAME
                      // ----------------------------------------------------

                      const Text(
                        'Droobi',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111111),
                        ),
                      ),

                      // ----------------------------------------------------
                      // MENU BUTTON
                      // ----------------------------------------------------

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
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================================
                // SEARCH DESTINATION
                // ==========================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: Semantics(
                    button: true,
                    label: 'Search destination',
                    hint: 'Open destination search',
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
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 12,
                                offset: Offset(0, 4),
                                color: Color(0x18000000),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 22,
                                color: Color(0xFF999999),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Search destination...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF777777),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ==========================================================
                // BELT CONNECTION STATUS
                // ==========================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(16),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          offset: Offset(0, 4),
                          color: Color(0x18000000),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ConnectionStatusIndicator(
                          state: beltState,
                        ),
                      ],
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
                          _handleMicPress(ref);
                        },
                        onPressEnd: () {
                          _handleMicRelease(ref);
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor:
          Colors.black.withValues(
        alpha: 0.50,
      ),
      transitionDuration:
          const Duration(milliseconds: 250),
      pageBuilder: (
        context,
        animation,
        secondaryAnimation,
      ) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: 288,
                height: double.infinity,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    24,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ====================================================
                      // MENU HEADER
                      // ====================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Menu',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.w500,
                              color:
                                  Color(0xFF111111),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                'Close menu',
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pop();
                            },
                            icon: const Icon(
                              Icons.close,
                              color:
                                  Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ====================================================
                      // HOME
                      // ====================================================

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

                      // ====================================================
                      // FAVORITES
                      // ====================================================

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

                      // ====================================================
                      // UNIVERSITY
                      // ====================================================

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

                      // ====================================================
                      // SETTINGS
                      // ====================================================

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
              ),
            ),
          ),
        );
      },
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
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFF5F5F5)
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    const Color(0xFF2F80ED),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w500,
                  color:
                      Color(0xFF111111),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}