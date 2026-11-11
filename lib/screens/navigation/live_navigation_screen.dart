
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../services/navigation/navigation_service.dart';
import '../../widgets/page_help_button.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/navigation_notifier.dart';

import '../../core/theme/app_colors.dart';

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

  /// Alternative QGIS entrance points; the campus router chooses the
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

          final retainingGuidance =
              snapshot.state == NavigationState.navigating ||
              snapshot.state == NavigationState.approaching ||
              snapshot.state == NavigationState.recovering ||
              snapshot.state == NavigationState.positionUncertain ||
              snapshot.state == NavigationState.offRoute ||
              snapshot.state == NavigationState.arrivalCandidate;
          if (retainingGuidance) {
            _errorMessage = null;
          } else if (snapshot.errorMessage != null) {
            _errorMessage = snapshot.errorMessage;
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
        return 'FORWARD';

      case NavigationDirection.forwardRight:
        return 'FORWARD RIGHT';

      case NavigationDirection.right:
        return 'RIGHT';

      case NavigationDirection.backRight:
        return 'BACK RIGHT';

      case NavigationDirection.back:
        return 'BACK';

      case NavigationDirection.backLeft:
        return 'BACK LEFT';

      case NavigationDirection.left:
        return 'LEFT';

      case NavigationDirection.forwardLeft:
        return 'FORWARD LEFT';

      case null:
        return 'CALCULATING';
    }
  }

  String _stateText(NavigationState state) {
    switch (state) {
      case NavigationState.idle:
        return 'Ready';

      case NavigationState.starting:
        return 'Preparing route...';

      case NavigationState.navigating:
        return 'Navigation active';

      case NavigationState.positionUncertain:
        return 'Updating position — last direction retained';

      case NavigationState.offRoute:
        return 'Reconnecting to campus path';

      case NavigationState.approaching:
        return 'Approaching destination';

      case NavigationState.arrivalCandidate:
        return 'Confirming arrival...';

      case NavigationState.gpsUnavailable:
        return 'GPS unavailable';

      case NavigationState.routeUnavailable:
        return 'Route unavailable';

      case NavigationState.recovering:
        return 'Recovering...';

      case NavigationState.arrived:
        return 'You have arrived';

      case NavigationState.stopped:
        return 'Navigation stopped';
    }
  }

  String _formatDistance(double? distance) {
    if (distance == null) {
      return '--';
    }

    if (distance < 1000) {
      return '${distance.round()} m';
    }

    final kilometers = distance / 1000;

    return '${kilometers.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(beltNavigationBridgeProvider);

    

    final direction = _snapshot.direction;

    final isArrived =
        _snapshot.state == NavigationState.arrived;

    final isNavigating =
        _snapshot.state == NavigationState.navigating ||
        _snapshot.state == NavigationState.approaching ||
        _snapshot.state == NavigationState.recovering ||
        _snapshot.state == NavigationState.positionUncertain ||
        _snapshot.state == NavigationState.offRoute ||
        _snapshot.state == NavigationState.arrivalCandidate;

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
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Live Navigation',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              PageHelpButton(
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
                  'في أسفل الشاشة، اضغط STOP NAVIGATION لإيقاف الملاحة قبل الوصول. عند ظهور حالة الوصول يتغير الزر السفلي إلى DONE؛ اضغط DONE لإنهاء الملاحة ومغادرة الشاشة.',
                ],
                color: AppColors.brown,
              ),
            ],
          ),
          centerTitle: true,
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
                _buildStatusCard(),
                const SizedBox(height: 10),
                _buildBeltConnectionCard(
                  ref.watch(beltConnectionStateProvider).asData?.value ??
                      ref.read(beltConnectionServiceProvider).currentState,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildNavigationContent(
                    direction: direction,
                    isArrived: isArrived,
                    isNavigating: isNavigating,
                    isStarting: isStarting,
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
        title = 'Belt connected';
        description = 'Belt vibration guidance is available.';
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_connected;
        break;
      case BeltConnectionState.scanning:
        title = 'Searching for belt';
        description = 'Keep the ESP32 powered on and nearby.';
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.connecting:
        title = 'Connecting to belt';
        description = 'Establishing the Bluetooth connection.';
        color = AppColors.brown.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.reconnecting:
        title = 'Bluetooth connection lost';
        description =
            'Trying to reconnect. Belt vibration is unavailable until it reconnects.';
        color = AppColors.brown.shade800;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.disconnected:
      case BeltConnectionState.scanFailed:
        title = 'Belt not connected';
        description =
            'On-screen navigation may continue, but belt vibration is unavailable.';
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
    final routingMethod = widget.campusNavigation ? 'QGIS' : 'OSRM';

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
                  'Route distance: $distance',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.brown.shade700,
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 5),
                  Text(
                    'TEST ROUTING: $routingMethod',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: widget.campusNavigation
                          ? AppColors.brown.shade700
                          : AppColors.brown.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_snapshot.accuracyMeters != null)
            Text(
              'GPS\n±${_snapshot.accuracyMeters!.round()} m',
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

  Widget _buildNavigationContent({
    required NavigationDirection? direction,
    required bool isArrived,
    required bool isNavigating,
    required bool isStarting,
  }) {
    if (_errorMessage != null &&
        _snapshot.state != NavigationState.navigating &&
        _snapshot.state != NavigationState.approaching &&
        _snapshot.state != NavigationState.recovering &&
        _snapshot.state != NavigationState.positionUncertain &&
        _snapshot.state != NavigationState.offRoute &&
        _snapshot.state != NavigationState.arrivalCandidate) {
      return _buildErrorState();
    }

    if (isArrived) {
      return _buildArrivedState();
    }

    if (isStarting) {
      return _buildLoadingState();
    }

    // Keep the last confirmed direction visible during GPS/compass recovery
    // and arrival confirmation instead of replacing it with a spinner.
    if (_snapshot.state == NavigationState.recovering ||
        _snapshot.state == NavigationState.positionUncertain ||
        _snapshot.state == NavigationState.offRoute ||
        _snapshot.state == NavigationState.arrivalCandidate) {
      return _buildDirectionState(
        direction: direction,
        isNavigating: isNavigating,
      );
    }

    return _buildDirectionState(
      direction: direction,
      isNavigating: isNavigating,
    );
  }

  Widget _buildDirectionState({
    required NavigationDirection? direction,
    required bool isNavigating,
  }) {
    final icon = _directionIcon(direction);
    final text = _directionText(direction);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isNavigating
              ? 'NEXT DIRECTION'
              : 'WAITING FOR NAVIGATION',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.brown.shade600,
          ),
        ),
        const SizedBox(height: 24),
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
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brown.shade50,
              border: Border.all(
                color: AppColors.brown.shade100,
                width: 3,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 140,
                color: AppColors.brown.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
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
            'Direction angle: '
            '${_snapshot.relativeAngle!.toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.brown.shade600,
            ),
          ),
        const SizedBox(height: 8),
        if (_snapshot.heading != null)
          Text(
            'Heading: '
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 100,
            color: AppColors.brown,
          ),
          const SizedBox(height: 24),
          Text(
            'You have arrived',
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: AppColors.brown,
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Navigation error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls({
    required bool isArrived,
  }) {
    if (isArrived) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _stopNavigation,
          child: const Text('DONE'),
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
        child: const Text('STOP NAVIGATION'),
      ),
    );
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    super.dispose();
  }
}

