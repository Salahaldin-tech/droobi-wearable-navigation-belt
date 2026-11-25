
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../services/navigation/navigation_service.dart';
import '../../widgets/page_header.dart';
import '../../widgets/page_help_button.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/navigation_notifier.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/l10n.dart';

class LiveNavigationScreen extends ConsumerStatefulWidget {
  const LiveNavigationScreen({
    super.key,
    required this.destination,
    this.campusNavigation = false,
    this.destinationCandidates,
  });

  final LatLon destination;

  /// True only when navigation was launched from the University screen.
  final bool campusNavigation;

  /// Alternative OSM entrance nodes; the campus router chooses the
  /// reachable entrance with the shortest pedestrian route.
  final List<LatLon>? destinationCandidates;

  @override
  ConsumerState<LiveNavigationScreen> createState() =>
      _LiveNavigationScreenState();
}

class _LiveNavigationScreenState
    extends ConsumerState<LiveNavigationScreen> {
  StreamSubscription<NavigationSnapshot>? _navigationSubscription;

  NavigationSnapshot _snapshot = const NavigationSnapshot(
    state: NavigationState.idle,
  );

  bool _starting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNavigation();
    });
  }

  Future<void> _startNavigation() async {
    if (_starting) {
      return;
    }

    _starting = true;

    final navigationService =
        ref.read(navigationServiceProvider);

    _navigationSubscription?.cancel();

    _navigationSubscription =
        navigationService.snapshots.listen(
      (snapshot) {
        if (!mounted) {
          return;
        }

        setState(() {
          _snapshot = snapshot;

          if (snapshot.errorMessage != null) {
            _errorMessage = snapshot.errorMessage;
          } else if (snapshot.state ==
              NavigationState.navigating) {
            _errorMessage = null;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage = error.toString();
        });
      },
    );

    try {
      await navigationService.start(
        destination: widget.destination,
        destinationCandidates: widget.destinationCandidates,
        campusNavigation: widget.campusNavigation,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      _starting = false;
    }
  }

  Future<void> _stopNavigation() async {
    final navigationService =
        ref.read(navigationServiceProvider);

    await navigationService.stop();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<bool> _handleBack() async {
    final navigationService =
        ref.read(navigationServiceProvider);

    await navigationService.stop();

    return true;
  }

  IconData _directionIcon(
    NavigationDirection? direction,
  ) {
    switch (direction) {
      case NavigationDirection.forward:
        return Icons.arrow_upward;

      case NavigationDirection.forwardRight:
        return Icons.north_east;

      case NavigationDirection.right:
        return Icons.arrow_forward;

      case NavigationDirection.backRight:
        return Icons.south_east;

      case NavigationDirection.back:
        return Icons.arrow_downward;

      case NavigationDirection.backLeft:
        return Icons.south_west;

      case NavigationDirection.left:
        return Icons.arrow_back;

      case NavigationDirection.forwardLeft:
        return Icons.north_west;

      case null:
        return Icons.navigation;
    }
  }

  String _directionText(
    NavigationDirection? direction,
  ) {
    switch (direction) {
      case NavigationDirection.forward:
        return context.tr('FORWARD', 'إلى الأمام');

      case NavigationDirection.forwardRight:
        return context.tr('FORWARD RIGHT', 'إلى الأمام يمينًا');

      case NavigationDirection.right:
        return context.tr('RIGHT', 'يمينًا');

      case NavigationDirection.backRight:
        return context.tr('BACK RIGHT', 'إلى الخلف يمينًا');

      case NavigationDirection.back:
        return context.tr('BACK', 'إلى الخلف');

      case NavigationDirection.backLeft:
        return context.tr('BACK LEFT', 'إلى الخلف يسارًا');

      case NavigationDirection.left:
        return context.tr('LEFT', 'يسارًا');

      case NavigationDirection.forwardLeft:
        return context.tr('FORWARD LEFT', 'إلى الأمام يسارًا');

      case null:
        return context.tr('CALCULATING', 'جارٍ الحساب');
    }
  }

  String _stateText(NavigationState state) {
    switch (state) {
      case NavigationState.idle:
        return context.tr('Ready', 'جاهز');

      case NavigationState.starting:
        return context.tr('Preparing route...', 'جارٍ تجهيز المسار...');

      case NavigationState.navigating:
        return context.tr('Navigation active', 'الملاحة نشطة');

      case NavigationState.gpsUnavailable:
        return context.tr('GPS unavailable', 'إشارة GPS غير متاحة');

      case NavigationState.routeUnavailable:
        return context.tr('Route unavailable', 'المسار غير متاح');

      case NavigationState.recovering:
        return context.tr('Recovering...', 'جارٍ استعادة المسار...');

      case NavigationState.arrived:
        return context.tr('You have arrived', 'لقد وصلت');

      case NavigationState.stopped:
        return context.tr('Navigation stopped', 'توقفت الملاحة');
    }
  }

  String _formatDistance(double? distance) => context.formatDistance(distance);

  @override
  Widget build(BuildContext context) {
    ref.watch(beltNavigationBridgeProvider);

    

    final direction = _snapshot.direction;

    final isArrived =
        _snapshot.state == NavigationState.arrived;

    final isNavigating =
        _snapshot.state == NavigationState.navigating;

    final isStarting =
        _snapshot.state == NavigationState.starting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final shouldLeave = await _handleBack();

        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.brown,
          // Shared page title; it wraps instead of overflowing on narrow
          // screens or with large accessibility text sizes.
          titleSpacing: pageTitleSpacing(context),
          title: AppBarPageTitle(
            title: context.tr('Live Navigation', 'الملاحة المباشرة'),
            help: const PageHelpButton(
                title: 'Live Navigation',
                titleAr: 'الملاحة المباشرة',
                description:
                'A status card appears near the top. The main guidance is centered in the middle of the screen, with a large direction arrow and instruction text. A full-width action button sits at the bottom.',
                descriptionAr:
                'تظهر بطاقة الحالة قرب أعلى الشاشة. وتظهر الإرشادات الرئيسية في منتصف الشاشة، مع سهم اتجاه كبير ونص يوضح الاتجاه. يوجد زر إجراء بعرض الشاشة في الأسفل.',
                tips: [
                  'At the top, read the status card to check whether navigation is starting, active, or complete. The main direction arrow and instruction appear in the center; the distance/heading information may appear around the instruction.',
                  'Follow the large arrow and direction text in the center, and use the belt’s vibration cues if the belt is connected. If a status/error message appears instead, resolve the stated issue before relying on guidance.',
                  'At the bottom, tap STOP NAVIGATION to stop before arrival. When the arrival state is shown, the bottom button changes to DONE; tap DONE to finish and leave the navigation screen.',
                ],
              tipsAr: [
                  'في أعلى الشاشة، اقرأ بطاقة الحالة لمعرفة ما إذا كانت الملاحة تبدأ أو نشطة أو مكتملة. يظهر سهم الاتجاه الكبير ونص الإرشاد في المنتصف، وقد تظهر معلومات المسافة أو الاتجاه حول النص.',
                  'اتبع السهم الكبير ونص الاتجاه في منتصف الشاشة، واستخدم اهتزازات الحزام إذا كان متصلًا. إذا ظهرت رسالة حالة أو خطأ بدلًا من الإرشادات، عالج المشكلة المذكورة قبل الاعتماد على الملاحة.',
                  'في أسفل الشاشة، اضغط «إيقاف الملاحة» لإيقافها قبل الوصول. عند ظهور حالة الوصول يتغير الزر السفلي إلى «تم»؛ اضغط «تم» لإنهاء الملاحة ومغادرة الشاشة.',
                ],
                color: AppColors.brown,
              ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              20,
            ),
            child: Column(
              children: [
                // Layout fix for the RenderFlex overflow on campus ("Uni")
                // navigation: the status cards and the guidance used to sit
                // in a fixed Column whose guidance had a fixed 220px circle.
                // On shorter screens (and with the extra campus status
                // lines) that Column overflowed. The guidance now sizes
                // itself to the space actually left below the cards, and the
                // area scrolls instead of clipping if a very small screen or
                // large text still needs more room. The stop button stays
                // pinned at the bottom.
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildStatusCard()),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: _buildBeltConnectionCard(
                          ref.watch(beltConnectionStateProvider).asData?.value ??
                              ref.read(beltConnectionServiceProvider).currentState,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverLayoutBuilder(
                        builder: (context, constraints) {
                          // Height left for the guidance when scrolled to
                          // the top (stable while the user scrolls).
                          final availableHeight = (constraints
                                      .viewportMainAxisExtent -
                                  constraints.precedingScrollExtent)
                              .clamp(0.0, double.infinity);

                          return SliverToBoxAdapter(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: availableHeight,
                              ),
                              child: Center(
                                child: _buildNavigationContent(
                                  direction: direction,
                                  isArrived: isArrived,
                                  isNavigating: isNavigating,
                                  isStarting: isStarting,
                                  availableHeight: availableHeight,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildBottomControls(
                  isArrived: isArrived,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeltConnectionCard(BeltConnectionState state) {
    late final String title;
    late final String description;
    late final Color color;
    late final IconData icon;

    switch (state) {
      case BeltConnectionState.connected:
        title = context.tr('Belt connected', 'الحزام متصل');
        description = context.tr(
          'Belt vibration guidance is available.',
          'الإرشاد بالاهتزاز عبر الحزام متاح.',
        );
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_connected;
        break;
      case BeltConnectionState.scanning:
        title = context.tr('Searching for belt', 'جارٍ البحث عن الحزام');
        description = context.tr(
          'Keep the ESP32 powered on and nearby.',
          'أبقِ وحدة ESP32 قيد التشغيل وقريبة منك.',
        );
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.connecting:
        title = context.tr('Connecting to belt', 'جارٍ الاتصال بالحزام');
        description = context.tr(
          'Establishing the Bluetooth connection.',
          'جارٍ إنشاء اتصال البلوتوث.',
        );
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.reconnecting:
        title = context.tr('Bluetooth connection lost', 'انقطع اتصال البلوتوث');
        description = context.tr(
          'Trying to reconnect. Belt vibration is unavailable until it reconnects.',
          'جارٍ إعادة الاتصال. اهتزاز الحزام غير متاح حتى يعود الاتصال.',
        );
        color = AppColors.brown.shade800;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.disconnected:
      case BeltConnectionState.scanFailed:
        title = context.tr('Belt not connected', 'الحزام غير متصل');
        description = context.tr(
          'On-screen navigation may continue, but belt vibration is unavailable.',
          'يمكن متابعة الملاحة على الشاشة، لكن اهتزاز الحزام غير متاح.',
        );
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_disabled;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.brown.shade800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final distance =
        _formatDistance(
      _snapshot.distanceFromRouteMeters,
    );

    final state =
        _stateText(_snapshot.state);
    final routingMethod =
        widget.campusNavigation ? 'OSM + campus OSRM (foot)' : 'OSRM';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.brown.shade100,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brown.shade50,
            ),
            child: Icon(
              Icons.navigation,
              color: AppColors.brown.shade700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  state,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Route distance: $distance',
                    'البعد عن المسار: $distance',
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.brown.shade700,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 5),
                  Text(
                    'TEST ROUTING: $routingMethod',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: widget.campusNavigation
                          ? AppColors.brown.shade700
                          : AppColors.brown.shade700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _engineDebugLine(),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.brown.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_snapshot.accuracyMeters != null)
            Text(
              'GPS\n±${_snapshot.accuracyMeters!.round()} ${context.metersUnit}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brown.shade600,
              ),
            ),
        ],
      ),
    );
  }

  /// Field-test diagnostics for the V5 engine (debug builds only).
  String _engineDebugLine() {
    final s = _snapshot;
    final parts = <String>[
      if (s.remainingMeters != null)
        'left ${s.remainingMeters!.round()} m',
      if (s.distanceToNextTurnMeters != null && s.nextTurnAngleDegrees != null)
        'turn ${s.nextTurnAngleDegrees! > 0 ? 'R' : 'L'}'
            '${s.nextTurnAngleDegrees!.abs().round()}° in '
            '${s.distanceToNextTurnMeters!.round()} m',
      if (s.headingSource != null) 'hdg ${s.headingSource!.name}',
      if (s.courseOffsetDegrees != null)
        'cal ${s.courseOffsetDegrees!.toStringAsFixed(0)}°',
      if (s.route?.destinationSnapMeters != null)
        'end snap ${s.route!.destinationSnapMeters!.toStringAsFixed(1)} m',
      if (s.isOffRoute) 'OFF ROUTE',
    ];
    return parts.isEmpty ? 'engine: waiting' : parts.join(' · ');
  }

  Widget _buildNavigationContent({
    required NavigationDirection? direction,
    required bool isArrived,
    required bool isNavigating,
    required bool isStarting,
    required double availableHeight,
  }) {
    if (_errorMessage != null &&
        _snapshot.state != NavigationState.navigating) {
      return _buildErrorState();
    }

    if (isArrived) {
      return _buildArrivedState();
    }

    if (isStarting ||
        _snapshot.state == NavigationState.recovering) {
      return _buildLoadingState();
    }

    return _buildDirectionState(
      direction: direction,
      isNavigating: isNavigating,
      availableHeight: availableHeight,
    );
  }

  Widget _buildDirectionState({
    required NavigationDirection? direction,
    required bool isNavigating,
    required double availableHeight,
  }) {
    final icon = _directionIcon(direction);
    final text = _directionText(direction);

    // Size the direction circle to the space available instead of a fixed
    // 220px: keep room for the text lines (which grow with the system text
    // size) and the gaps, then clamp between a legible minimum and the
    // original maximum. Narrow screens are limited by width as well.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = availableHeight < 420;
    final gap = compact ? 12.0 : 24.0;
    final reservedForText = 150 * textScale + 2 * gap + 20;
    final maxByWidth = MediaQuery.sizeOf(context).width * 0.6;
    final circleSize = (availableHeight - reservedForText)
        .clamp(96.0, 220.0)
        .clamp(96.0, maxByWidth < 96 ? 96.0 : maxByWidth)
        .toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isNavigating
              ? context.tr('NEXT DIRECTION', 'الاتجاه التالي')
              : context.tr('WAITING FOR NAVIGATION', 'بانتظار بدء الملاحة'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: context.letterSpacing(1.4),
            color: AppColors.brown.shade600,
          ),
        ),
        SizedBox(height: gap),
        AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 300,
          ),
          transitionBuilder: (
            Widget child,
            Animation<double> animation,
          ) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: Container(
            key: ValueKey(direction),
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brown.shade50,
              border: Border.all(
                color: AppColors.brown.shade100,
                width: 3,
              ),
            ),
            // The arrow shows a physical direction (left/right of the
            // walker), so it must never be mirrored by the RTL layout.
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  icon,
                  size: circleSize * 140 / 220,
                  color: AppColors.brown.shade600,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 250,
          ),
          child: Text(
            text,
            key: ValueKey(text),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
          ),
        ),
        const SizedBox(height: 12),
        if (_snapshot.relativeAngle != null)
          Text(
            context.tr('Direction angle: ', 'زاوية الاتجاه: ') +
                '${_snapshot.relativeAngle!.toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.brown.shade600,
            ),
          ),
        const SizedBox(height: 8),
        if (_snapshot.heading != null)
          Text(
            context.tr('Heading: ', 'الاتجاه الحالي: ') +
                '${_snapshot.heading!.toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.brown.shade500,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildArrivedState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 100,
            color: AppColors.brown,
          ),
          const SizedBox(height: 24),
          Text(
            context.tr('You have arrived', 'لقد وصلت'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.brown,
            ),
            const SizedBox(height: 20),
            ..._errorTexts(_errorMessage ?? 'Navigation error'),
          ],
        ),
      ),
    );
  }

  /// Error text in the active language. Known service messages are
  /// translated; an unknown technical message in Arabic mode gets a clear
  /// Arabic summary with the original detail shown underneath.
  List<Widget> _errorTexts(String message) {
    const mainStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
    final translated = context.localizeMessage(message);
    if (!context.isArabic || translated != message) {
      return [
        Text(translated, textAlign: TextAlign.center, style: mainStyle),
      ];
    }
    return [
      const Text(
        'تعذّرت متابعة الملاحة.',
        textAlign: TextAlign.center,
        style: mainStyle,
      ),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: TextStyle(fontSize: 13, color: AppColors.brown.shade700),
      ),
    ];
  }

  Widget _buildBottomControls({
    required bool isArrived,
  }) {
    if (isArrived) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _stopNavigation,
          child: Text(context.tr('DONE', 'تم')),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _stopNavigation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brown.shade50,
          foregroundColor: AppColors.brown.shade700,
        ),
        child: Text(context.tr('STOP NAVIGATION', 'إيقاف الملاحة')),
      ),
    );
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }
}

