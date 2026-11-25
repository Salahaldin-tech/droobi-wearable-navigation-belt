import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../core/enums/voice_language.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/destination_search_notifier.dart';
import '../../state/voice_language_notifier.dart';
import '../../widgets/connection_status_indicator.dart';
import '../../widgets/app_card.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';
import '../test/dev_test_menu.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const Color _blue = AppColors.brown;
  static const Color _red = AppColors.brown;
  static const Color _text = AppColors.brown;
  static const Color _muted = AppColors.brown;

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

    final appLanguage = ref.watch(appLanguageProvider);

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
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                // No top padding: the shared header starts at the top of the
                // safe area, at the same height as every other page title.
                padding: const EdgeInsets.fromLTRB(
                  24,
                  0,
                  24,
                  16,
                ),
                children: [
                  PageHeader(
                    horizontalPadding: 0,
                    title: context.tr('Settings', 'الإعدادات'),
                    help: const PageHelpButton(
                        title: 'Settings',
                        titleAr: 'الإعدادات',
                        description:
                'Settings is a vertically scrolling page. Its sections appear one below another in this order: App Language, Device, Voice Language, Search City, and Account.',
                        descriptionAr:
                'صفحة الإعدادات قابلة للتمرير عموديًا. تظهر أقسامها واحدًا تحت الآخر بهذا الترتيب: لغة التطبيق، ثم الجهاز، ثم لغة الصوت، ثم مدينة البحث، ثم الحساب.',
                        tips: [
                  'At the top, use the App Language section to choose العربية or English. The whole app switches immediately and keeps your choice after it is closed or the phone restarts.',
                  'Below it, find the Device section and read the connection status. Tap Connect / Reconnect Belt in the full-width button beneath the status; when connected, the button changes to Disconnect Belt.',
                  'Scroll down to Voice Language. On the right side of this section, tap EN or AR; the selected language option is highlighted.',
                  'Scroll farther down to Search City. Tap the dropdown control on the right, choose a city from the menu, and the selected city is shown in the control.',
                  'Scroll to the Account section near the bottom and tap Log Out to end the session. If location or Bluetooth permission is denied, open the phone’s system Settings, enable the permission, and return to Droobi.',
                ],
              tipsAr: [
                  'في الأعلى، استخدم قسم لغة التطبيق لاختيار العربية أو English. يتغير التطبيق بالكامل فورًا، ويحتفظ باختيارك بعد إغلاقه أو إعادة تشغيل الهاتف.',
                  'أسفله، ابحث عن قسم الجهاز واقرأ حالة الاتصال. اضغط زر «توصيل / إعادة توصيل الحزام» العريض أسفل الحالة؛ وعند الاتصال يتغير اسمه إلى «فصل الحزام».',
                  'مرّر إلى أسفل حتى قسم لغة الصوت. في الجهة اليسرى من القسم، اضغط «عربي» أو «إنجليزي»؛ ويظهر خيار اللغة المحدد بشكل مميز.',
                  'واصل التمرير إلى قسم مدينة البحث. اضغط القائمة المنسدلة في الجهة اليسرى، واختر مدينة من القائمة؛ وستظهر المدينة المحددة داخل عنصر الاختيار.',
                  'مرّر إلى قسم الحساب قرب الأسفل واضغط «تسجيل الخروج» لإنهاء الجلسة. إذا رُفض إذن الموقع أو البلوتوث، افتح إعدادات الهاتف، وفعّل الإذن، ثم ارجع إلى دروبي.',
                ],
                        color: _blue,
                      ),
                  ),

                  const SizedBox(height: 16),

                  // App language (interface text + layout direction)
                  _sectionLabel(
                    context,
                    context.tr('APP LANGUAGE', 'لغة التطبيق'),
                  ),

                  const SizedBox(height: 10),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.translate,
                          size: 22,
                          color: _muted,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            context.tr('Language', 'اللغة'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ),

                        Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.brown
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Each option is written in its own language.
                              _languageButton(
                                label: 'العربية',
                                semanticsLabel: 'العربية',
                                selected:
                                    appLanguage == AppLanguage.arabic,
                                onPressed: () {
                                  ref
                                      .read(appLanguageProvider.notifier)
                                      .setLanguage(AppLanguage.arabic);
                                },
                              ),

                              _languageButton(
                                label: 'English',
                                semanticsLabel: 'English',
                                selected:
                                    appLanguage == AppLanguage.english,
                                onPressed: () {
                                  ref
                                      .read(appLanguageProvider.notifier)
                                      .setLanguage(AppLanguage.english);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Device
                  _sectionLabel(context, context.tr('DEVICE', 'الجهاز')),

                  const SizedBox(height: 10),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),

                        Align(
                          alignment: AlignmentDirectional.centerStart,
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
                                  ? context.tr('Disconnect Belt', 'فصل الحزام')
                                  : context.tr(
                                      'Connect / Reconnect Belt',
                                      'توصيل / إعادة توصيل الحزام',
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  _sectionLabel(
                    context,
                    context.tr('VOICE LANGUAGE', 'لغة الصوت'),
                  ),

                  const SizedBox(height: 10),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language,
                          size: 22,
                          color: _muted,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            context.tr('Voice Language', 'لغة الأوامر الصوتية'),
                            style: const TextStyle(
                              fontSize: 15,
                              color: _text,
                            ),
                          ),
                        ),

                        Container(
                          height: 40,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.cream,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _languageButton(
                                label: context.tr('EN', 'إنجليزي'),
                                semanticsLabel: context.tr(
                                  'English voice',
                                  'الصوت بالإنجليزية',
                                ),
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
                                label: context.tr('AR', 'عربي'),
                                semanticsLabel: context.tr(
                                  'Arabic voice',
                                  'الصوت بالعربية',
                                ),
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
                  _sectionLabel(
                    context,
                    context.tr('SEARCH CITY', 'مدينة البحث'),
                  ),

                  const SizedBox(height: 10),

                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_city_outlined,
                          size: 22,
                          color: _muted,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            context.tr('Search City', 'مدينة البحث'),
                            style: const TextStyle(
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
                            color: AppColors.cream,
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.cream,
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
                                      context.cityName(city),
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
                  _sectionLabel(context, context.tr('ACCOUNT', 'الحساب')),

                  const SizedBox(height: 10),

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(16),
                        onTap: () async {
                          await ref
                              .read(authServiceProvider)
                              .signOut();

                          if (!context.mounted) return;

                          Navigator.of(context).popUntil(
                            (route) => route.isFirst,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.logout,
                                size: 21,
                                color: _red,
                              ),

                              const SizedBox(width: 12),

                              Text(
                                context.tr('Sign Out', 'تسجيل الخروج'),
                                style: const TextStyle(
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
                    _sectionLabel(context, context.tr('DEVELOPER', 'المطوّر')),

                    const SizedBox(height: 10),

                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const DevTestMenu(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.build_outlined,
                                  size: 21,
                                  color: _muted,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Text(
                                    context.tr(
                                      'Dev Test Menu',
                                      'قائمة اختبارات المطوّر',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: _text,
                                    ),
                                  ),
                                ),

                                const Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color:
                                      AppColors.brown,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.tr('Droobi v1.0.0', 'دروبي – الإصدار 1.0.0'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.brown,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          context.tr('دروبي', 'Droobi'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.brown,
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

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20, letterSpacing: context.letterSpacing(0.4)),
    );
  }

  Widget _languageButton({
    required String label,
    required String semanticsLabel,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minWidth: 48),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _blue : AppColors.cream,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.cream : _text,
            ),
          ),
        ),
      ),
    );
  }
}