import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/enums/belt_connection_state.dart';
import '../../core/enums/voice_language.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/voice_language_notifier.dart';
import '../../widgets/connection_status_indicator.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../test/dev_test_menu.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Color _blue = Color(0xFF2F80ED);
  static const Color _green = Color(0xFF27AE60);
  static const Color _red = Color(0xFFEB5757);
  static const Color _text = Color(0xFF111111);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _card = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(
      beltConnectionStateProvider,
    );

    final beltService = ref.watch(
      beltConnectionServiceProvider,
    );

    // Use the actual state from the existing BLE system.
    final state =
        connectionAsync.value ?? beltService.currentState;

    final voiceLanguage = ref.watch(
      voiceLanguageProvider,
    );

    final isConnected =
        state == BeltConnectionState.connected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ============================================================
            // CONTENT
            // ============================================================

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  16,
                ),
                children: [
                  // ========================================================
                  // HEADER
                  // ========================================================

                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: _text,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'الإعدادات',
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // DEVICE
                  // ========================================================

                  _sectionLabel('DEVICE'),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // --------------------------------------------------
                        // DEVICE HEADER
                        // --------------------------------------------------

                        const SizedBox(height: 14),

                        // --------------------------------------------------
                        // REAL BLE STATUS
                        // --------------------------------------------------
                        //
                        // IMPORTANT:
                        // This is the existing status widget.
                        // It receives the actual BeltConnectionState.
                        //
                        // So if the BLE service changes:
                        //
                        // disconnected
                        //      ↓
                        // scanning
                        //      ↓
                        // connecting
                        //      ↓
                        // connected
                        //
                        // this widget reflects that state.
                        // --------------------------------------------------

                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConnectionStatusIndicator(
                            state: state,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // --------------------------------------------------
                        // ACTION BUTTON
                        // --------------------------------------------------

                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (isConnected) {
                                beltService.disconnect();
                              } else {
                                beltService.scanAndConnect();
                              }
                            },
                            icon: Icon(
                              isConnected
                                  ? Icons.bluetooth_disabled
                                  : Icons.bluetooth_searching,
                              size: 18,
                            ),
                            label: Text(
                              isConnected
                                  ? 'Disconnect Belt'
                                  : 'Connect / Reconnect Belt',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isConnected
                                  ? _red
                                  : _blue,
                              side: BorderSide(
                                color: (isConnected
                                        ? _red
                                        : _blue)
                                    .withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // VOICE LANGUAGE
                  // ========================================================

                  _sectionLabel('VOICE LANGUAGE'),

                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language,
                          size: 22,
                          color: _muted,
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            'Voice Language',
                            style: TextStyle(
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ),

                        Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFFE5E7EB,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _languageButton(
                                label: 'EN',
                                selected:
                                    voiceLanguage ==
                                        VoiceLanguage
                                            .english,
                                onPressed: () {
                                  ref
                                      .read(
                                        voiceLanguageProvider
                                            .notifier,
                                      )
                                      .setLanguage(
                                        VoiceLanguage
                                            .english,
                                      );
                                },
                              ),

                              _languageButton(
                                label: 'AR',
                                selected:
                                    voiceLanguage ==
                                        VoiceLanguage
                                            .arabic,
                                onPressed: () {
                                  ref
                                      .read(
                                        voiceLanguageProvider
                                            .notifier,
                                      )
                                      .setLanguage(
                                        VoiceLanguage
                                            .arabic,
                                      );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // ACCOUNT
                  // ========================================================

                  _sectionLabel('ACCOUNT'),

                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(12),
                        onTap: () async {
                          // Sign out only. The auth-gated app root watches
                          // authStateProvider and shows the sign-in screen
                          // by itself, so no SignInScreen is pushed here.
                          await ref
                              .read(authServiceProvider)
                              .signOut();

                          if (!context.mounted) return;

                          // Remove the screens pushed on top of the root
                          // (this Settings screen, etc.) so the root, which
                          // now shows the sign-in screen, becomes visible.
                          // The root itself stays in the navigator, so the
                          // next login is handled by the auth state again.
                          Navigator.of(context).popUntil(
                            (route) => route.isFirst,
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                size: 21,
                                color: _red,
                              ),

                              SizedBox(width: 12),

                              Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // DEVELOPER
                  // ========================================================

                  _sectionLabel('DEVELOPER'),

                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DevTestMenu(),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.build_outlined,
                                size: 21,
                                color: _muted,
                              ),

                              SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  'Dev Test Menu',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _text,
                                  ),
                                ),
                              ),

                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color:
                                    Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ========================================================
                  // APP INFO
                  // ========================================================

                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Droobi v1.0.0',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),

                        SizedBox(height: 4),

                        Text(
                          'دروبي -  ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ============================================================
            // BOTTOM NAVIGATION
            // ============================================================
            //
            // Exactly like the University screen:
            // no outer horizontal padding.
            // ============================================================

            const DroobiBottomNav(
              currentItem: DroobiNavItem.settings,
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SECTION LABEL
  // ========================================================================

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: _muted,
      ),
    );
  }

  // ========================================================================
  // LANGUAGE BUTTON
  // ========================================================================

  Widget _languageButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'EN'
          ? 'English'
          : 'العربية',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? _blue
                : Colors.white,
            borderRadius:
                BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected
                  ? Colors.white
                  : _text,
            ),
          ),
        ),
      ),
    );
  }
}