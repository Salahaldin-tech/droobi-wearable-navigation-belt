import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';
import '../../core/enums/voice_command_state.dart';
import '../../state/auth_state_notifier.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/voice_command_notifier.dart';
import '../../widgets/connection_status_indicator.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';
import '../../widgets/droobi_bottom_nav.dart';
import '../../widgets/voice_command_button.dart';
import '../destination/destination_search_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import '../university/university_locations_screen.dart';
import 'AboutUsScreen.dart';

/// Droobi Home Screen.
///
/// Minimal home screen on the brand cream background:
/// - fade/slide-in entrance for the header, search bar and belt card
/// - soft cream search bar and belt card
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
  static const Color _blue = AppColors.brown;
  static const Color _green = AppColors.brown;
  static const Color _grey = AppColors.brown;
  static const Color _text = AppColors.brown;
  static const Color _muted = AppColors.brown;

  late final AnimationController _entranceController;
  late final Animation<double> _headerAnimation;
  late final Animation<double> _searchAnimation;
  late final Animation<double> _beltAnimation;

  bool _entranceStarted = false;

  static const String _welcomeCompletedKey = 'droobi_welcome_completed_v1';
  bool _welcomeCheckStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeDialogIfNeeded();
    });

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    } else {
      if (!_entranceStarted) {
        _entranceStarted = true;
        _entranceController.forward();
      }

    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _showWelcomeDialogIfNeeded() async {
    if (_welcomeCheckStarted) return;
    _welcomeCheckStarted = true;

    final preferences = await SharedPreferences.getInstance();
    if (!mounted || preferences.getBool(_welcomeCompletedKey) == true) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.accessibility_new_rounded,
            color: _blue,
            size: 34,
          ),
          title: Text(
            dialogContext.tr('Welcome to Droobi!', 'مرحبًا بك في دروبي!'),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeFeature(
                  icon: Icons.mic_none_rounded,
                  title: dialogContext.tr('Voice Search', 'البحث الصوتي'),
                  description: dialogContext.tr(
                    'Use the microphone to search for a destination, such as a university college, gate, or facility.',
                    'استخدم الميكروفون للبحث عن وجهة، مثل كلية أو بوابة أو مرفق في الجامعة.',
                  ),
                ),
                const SizedBox(height: 16),
                _WelcomeFeature(
                  icon: Icons.vibration_rounded,
                  title: dialogContext.tr(
                    'Smart Navigation Belt',
                    'حزام الملاحة الذكي',
                  ),
                  description: dialogContext.tr(
                    'When the belt is connected and navigation is running, vibration signals can help guide you.',
                    'عندما يكون الحزام متصلًا والملاحة قيد التشغيل، ترشدك إشارات الاهتزاز إلى الاتجاه الصحيح.',
                  ),
                ),
                const SizedBox(height: 16),
                _WelcomeFeature(
                  icon: Icons.help_outline_rounded,
                  title: dialogContext.tr(
                    'Help on Every Page',
                    'مساعدة في كل صفحة',
                  ),
                  description: dialogContext.tr(
                    'Look for the (?) help button at the top of a page to hear how that page and its options work.',
                    'ابحث عن زر المساعدة (؟) أعلى كل صفحة لتتعرّف على طريقة عمل الصفحة وخياراتها.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  dialogContext.tr(
                    'To use navigation, Droobi will next ask for location and Bluetooth access. Your phone may also ask you to turn these services on.',
                    'لاستخدام الملاحة، سيطلب دروبي بعد ذلك إذن الوصول إلى الموقع والبلوتوث، وقد يطلب منك هاتفك أيضًا تشغيل هذه الخدمات.',
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await preferences.setBool(_welcomeCompletedKey, true);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  await _requestStartupPermissions();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: AppColors.cream,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(dialogContext.tr("Let's Get Started", 'لنبدأ')),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Requests the permissions needed for location-based navigation and BLE.
  /// The OS remains responsible for granting permissions and enabling services.
  Future<void> _requestStartupPermissions() async {
    // Request location permission first.
    try {
      var locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Keep startup resilient if the platform permission API is unavailable.
    }

    // Request Android 12+ BLE runtime permissions. On iOS, a short BLE scan
    // triggers Apple's Bluetooth authorization prompt when one is needed.
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 1),
        );
        await Future.delayed(const Duration(milliseconds: 1100));
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore cleanup errors if Bluetooth is unavailable.
      }
    }

    // Android can show a system confirmation to turn Bluetooth on.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
        }
      } catch (_) {
        // The user may deny the request or the device may not support BLE.
      }
    }

    // Location permission does not automatically enable the device's GPS.
    // If the service is off, send the user to the OS location settings.
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      }
    } catch (_) {
      // Do not block access to Home if settings cannot be opened.
    }
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

  /// Soft cream container with a subtle brand-colour border and shadow.
  Widget _glassCard({
    required Widget child,
    double radius = 12,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 6),
            color: AppColors.brown.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(radius),
              // Clear brand border, matching the app's other search fields.
              border: Border.all(
                color: AppColors.brown,
                width: 1.5,
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

    final beltState = connectionAsync.value ?? beltService.currentState;

    final isBeltConnected = beltState == BeltConnectionState.connected;

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
      final searchStarted = previous?.phase == VoiceCommandPhase.recognized &&
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
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // Decorative cream-and-brown background. It is excluded from
          // semantics and sits behind every control, so it never takes input.
          Positioned.fill(
            child: Image.asset(
              'assets/home_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
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
                    padding: const EdgeInsets.only(bottom: 12),
                    // App name in the shared page-title style (LyonArabic),
                    // help next to it, menu button at the opposite edge.
                    child: PageHeader(
                      title: context.tr('Droobi', 'دروبي'),
                      help: const PageHelpButton(
                              title: 'Home',
                              titleAr: 'الرئيسية',
                              description:
                'The Home screen is arranged vertically: the app name and menu are at the top, the destination search field is below them, the belt status card sits beneath the search field, the microphone is around the center, and the app navigation bar is at the bottom.',
                              descriptionAr:
                'ترتيب الصفحة الرئيسية عمودي: اسم التطبيق وزر المساعدة في أعلى اليمين وزر القائمة في أعلى اليسار، وأسفلهما حقل البحث عن وجهة، ثم بطاقة حالة الحزام، والميكروفون قرب منتصف الشاشة، وشريط التنقل في أسفلها.',
                              tips: [
                  'At the top-right, tap the ☰ menu button to open the side menu. The menu items appear in a vertical list; tap Favorites, University, Settings, or About Us to open that page.',
                  'Below the app name near the top, tap the wide Search destination field. The Search Destination page opens, with a search field at the top and matching results arranged as vertical rows below it.',
                  'Near the center of Home, press and hold the microphone button, say the destination, then release it. When speech is recognized, the recognized text appears beneath the microphone; the app then opens destination search.',
                  'Below the destination search field, read the belt status card. To connect the belt, open the top-right menu, choose Settings, and use the Connect / Reconnect Belt button in the Device section.',
                ],
              tipsAr: [
                  'في أعلى يسار الشاشة، اضغط زر القائمة لفتح القائمة الجانبية من جهة اليمين. تظهر خياراتها في قائمة عمودية؛ اضغط المفضلة أو الجامعة أو الإعدادات أو من نحن لفتح الصفحة المطلوبة.',
                  'أسفل اسم التطبيق قرب أعلى الشاشة، اضغط حقل «ابحث عن وجهة» العريض. ستفتح صفحة البحث عن وجهة، وفي أعلاها حقل البحث وتظهر النتائج المطابقة تحته على شكل صفوف عمودية.',
                  'قرب منتصف الصفحة الرئيسية، اضغط مطولًا على زر الميكروفون واذكر الوجهة ثم ارفع إصبعك. عند التعرّف على الكلام، يظهر النص أسفل الميكروفون، ثم يفتح التطبيق شاشة البحث عن الوجهة.',
                  'أسفل حقل البحث عن الوجهة، اقرأ بطاقة حالة الحزام. لتوصيل الحزام، افتح القائمة من أعلى اليسار، واختر الإعدادات، ثم اضغط «توصيل / إعادة توصيل الحزام» في قسم الجهاز.',
                ],
                              color: _blue,
                            ),
                      trailing: Semantics(
                          button: true,
                          label: context.tr('Open menu', 'فتح القائمة'),
                          child: Material(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(10),
                            elevation: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
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
                      label: context.tr('Search destination', 'ابحث عن وجهة'),
                      hint: context.tr(
                        'Open destination search',
                        'فتح صفحة البحث عن وجهة',
                      ),
                      child: _glassCard(
                        // Rounded to the border's inner edge (12 - 1.5) so the
                        // fill no longer paints over the border's corners.
                        child: Material(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(10.5),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10.5),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 22,
                                    color: AppColors.brown,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      context.tr(
                                        'Search destination...',
                                        'ابحث عن وجهة...',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.brown,
                                      ),
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
                                  alignment: AlignmentDirectional.centerStart,
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
                                  color: isBeltConnected ? _green : _grey,
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
                    mainAxisAlignment: MainAxisAlignment.center,
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

                      if (voiceState.phase == VoiceCommandPhase.recognized)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          child: Text(
                            context.tr(
                              'Heard: "${voiceState.recognizedText}"',
                              'سمعت: «${voiceState.recognizedText}»',
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),

                      // ----------------------------------------------------
                      // ERROR
                      // ----------------------------------------------------

                      if (voiceState.phase == VoiceCommandPhase.error)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          child: Text(
                            context.localizeMessage(
                              voiceState.errorMessage ?? '',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.brown,
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
                  currentItem: DroobiNavItem.home,
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

    // The side menu opens from the leading edge: left in English,
    // right in Arabic.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final closeMenuLabel = context.tr('Close menu', 'إغلاق القائمة');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: closeMenuLabel,
      barrierColor: AppColors.brown.withValues(
        alpha: 0.50,
      ),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        // Slide in from the leading edge instead of the default fade.
        return SlideTransition(
          position:
              animation.drive(CurveTween(curve: Curves.easeOutCubic)).drive(
                    Tween<Offset>(
                      begin: Offset(isRtl ? 1 : -1, 0),
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
          alignment: AlignmentDirectional.centerStart,
          child: Material(
            color: AppColors.cream,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadiusDirectional.horizontal(
              end: Radius.circular(24),
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
                    padding: EdgeInsetsDirectional.fromSTEB(
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
                          AppColors.cream,
                          AppColors.cream,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                    color: AppColors.brown.withValues(alpha: 0.09),
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
                              tooltip: closeMenuLabel,
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pop();
                              },
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.brown,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (userName.isNotEmpty) ...[
                          Text(
                            context.tr('Welcome,', 'أهلًا،'),
                            style: const TextStyle(
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
                          Text(
                            context.tr('Welcome to Droobi', 'مرحبًا بك في دروبي'),
                            style: const TextStyle(
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
                          label: context.tr('Home', 'الرئيسية'),
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
                          label: context.tr('Favorites', 'المفضلة'),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) => const FavoritesScreen(),
                              ),
                            );
                          },
                        ),

                        // ==================================================
                        // UNIVERSITY
                        // ==================================================

                        _MenuItem(
                          icon: Icons.school,
                          label: context.tr('University', 'الجامعة'),
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
                          label: context.tr('Settings', 'الإعدادات'),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        )
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 15,
                      bottom: 30,
                    ),
                    child: _MenuItem(
                      icon: Icons.info_outline,
                      label: context.tr('About Us', 'من نحن'),
                      onTap: () {
                            Navigator.of(
                              context,
                            ).pop();

                            Navigator.of(
                              context,
                            ).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutUsScreen(),
                              ),
                            );
                          },
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

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icon, color: AppColors.brown, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
    const blue = AppColors.brown;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: active ? blue.withValues(alpha: 0.08) : AppColors.cream,
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
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? blue : AppColors.brown,
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
  }
}
