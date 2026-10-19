import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../core/enums/voice_language.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/destination_search_notifier.dart';
import '../../state/voice_language_notifier.dart';
import '../../widgets/connection_status_indicator.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/page_help_button.dart';
import '../test/dev_test_menu.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Color _blue = Color(0xFF2F80ED);
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

    final state =
        connectionAsync.value ?? beltService.currentState;

    final voiceLanguage = ref.watch(
      voiceLanguageProvider,
    );

    final searchState = ref.watch(
      destinationSearchProvider,
    );

    final currentUser = ref.watch(authStateProvider).maybeWhen(
          data: (user) => user,
          orElse: () => null,
        );

    final isAdmin = currentUser?.isAdmin ?? false;

    final isConnected =
        state == BeltConnectionState.connected;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  16,
                ),
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _text,
                        ),
                      ),
                      SizedBox(width: 4),
                      PageHelpButton(
                        title: 'Settings',
                        titleAr: 'الإعدادات',
                        description:
                'Settings is a vertically scrolling page. Its sections appear one below another in this order: Device, Voice Language, Search City, and Account.',
                        descriptionAr:
                'صفحة الإعدادات قابلة للتمرير عموديًا. تظهر أقسامها واحدًا تحت الآخر بهذا الترتيب: Device ثم Voice Language ثم Search City ثم Account.',
                        tips: [
                  'Near the top, find the Device section and read the connection status. Tap Connect / Reconnect Belt in the full-width button beneath the status; when connected, the button changes to Disconnect Belt.',
                  'Scroll down to Voice Language. On the right side of this section, tap EN or AR; the selected language option is highlighted.',
                  'Scroll farther down to Search City. Tap the dropdown control on the right, choose a city from the menu, and the selected city is shown in the control.',
                  'Scroll to the Account section near the bottom and tap Log Out to end the session. If location or Bluetooth permission is denied, open the phone’s system Settings, enable the permission, and return to Droobi.',
                ],
              tipsAr: [
                  'قرب أعلى الشاشة، ابحث عن قسم Device واقرأ حالة الاتصال. اضغط زر Connect / Reconnect Belt العريض أسفل الحالة؛ وعند الاتصال يتغير اسمه إلى Disconnect Belt.',
                  'مرّر إلى أسفل حتى قسم Voice Language. في الجهة اليمنى من القسم، اضغط EN أو AR؛ ويظهر خيار اللغة المحدد بشكل مميز.',
                  'واصل التمرير إلى قسم Search City. اضغط القائمة المنسدلة على اليمين، واختر مدينة من القائمة؛ وستظهر المدينة المحددة داخل عنصر الاختيار.',
                  'مرّر إلى قسم Account قرب الأسفل واضغط Log Out لإنهاء الجلسة. إذا رُفض إذن الموقع أو البلوتوث، افتح إعدادات الهاتف، وفعّل الإذن، ثم ارجع إلى دروبي.',
                ],
                        color: _blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  const SizedBox(height: 28),

                  // Device
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
                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConnectionStatusIndicator(
                            state: state,
                          ),
                        ),

                        const SizedBox(height: 14),

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
                              foregroundColor:
                                  isConnected ? _red : _blue,
                              side: BorderSide(
                                color: (isConnected
                                        ? _red
                                        : _blue)
                                    .withValues(alpha: 0.35),
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

                  // Voice language
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
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _languageButton(
                                label: 'EN',
                                selected:
                                    voiceLanguage ==
                                        VoiceLanguage.english,
                                onPressed: () {
                                  ref
                                      .read(
                                        voiceLanguageProvider
                                            .notifier,
                                      )
                                      .setLanguage(
                                        VoiceLanguage.english,
                                      );
                                },
                              ),

                              _languageButton(
                                label: 'AR',
                                selected:
                                    voiceLanguage ==
                                        VoiceLanguage.arabic,
                                onPressed: () {
                                  ref
                                      .read(
                                        voiceLanguageProvider
                                            .notifier,
                                      )
                                      .setLanguage(
                                        VoiceLanguage.arabic,
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

                  // Search city
                  _sectionLabel('SEARCH CITY'),

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
                          Icons.location_city_outlined,
                          size: 22,
                          color: _muted,
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            'Search City',
                            style: TextStyle(
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ),

                        Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: searchState.selectedCity,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                                color: _muted,
                              ),
                              borderRadius:
                                  BorderRadius.circular(10),
                              items: searchCities.map(
                                (city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(
                                      city,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: _text,
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                              onChanged: (city) {
                                if (city == null) return;

                                ref
                                    .read(
                                      destinationSearchProvider
                                          .notifier,
                                    )
                                    .setCity(city);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Account
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
                          await ref
                              .read(authServiceProvider)
                              .signOut();

                          if (!context.mounted) return;

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

                  if (isAdmin) ...[
                    const SizedBox(height: 28),

                    // Developer tools
                    _sectionLabel('DEVELOPER'),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius:
                            BorderRadius.circular(12),
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
                  ],

                  const SizedBox(height: 16),

                  // App info
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
                          'دروبي',
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

            const DroobiBottomNav(
              currentItem: DroobiNavItem.settings,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _languageButton({
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'EN' ? 'English' : 'العربية',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : _text,
            ),
          ),
        ),
      ),
    );
  }
}