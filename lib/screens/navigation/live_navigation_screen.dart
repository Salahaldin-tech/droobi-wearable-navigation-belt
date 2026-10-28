
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../../core/enums/belt_connection_state.dart';
import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../services/navigation/navigation_service.dart';
import '../../widgets/page_help_button.dart';
import '../../state/belt_connection_notifier.dart';
import '../../state/navigation_notifier.dart';

class LiveNavigationScreen extends ConsumerStatefulWidget {
  const LiveNavigationScreen({
    super.key,
    required this.destination,
  });

  final LatLon destination;

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
  bool _navigationHasStarted = false;
  bool _showContinue = false;
  bool _checkingReadiness = false;
  bool _requiresResume = false;
  bool _alarmActive = false;
  bool _wasBeltConnected = false;
  bool _gpsFailureAlerted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareNavigation();
    });
  }

  Future<void> _prepareNavigation() async {
    final ready = await _checkReadiness(showMessages: true);
    if (!mounted) return;
    if (ready) {
      await _startNavigation();
    } else {
      setState(() => _showContinue = true);
    }
  }

  Future<void> _continueNavigation() async {
    if (_checkingReadiness || _starting) return;
    final ready = await _checkReadiness(showMessages: true);
    if (!mounted) return;
    if (!ready) {
      setState(() => _showContinue = true);
      return;
    }
    if (_navigationHasStarted || _requiresResume) {
      await ref.read(navigationServiceProvider).stop();
    }
    setState(() {
      _showContinue = false;
      _requiresResume = false;
      _errorMessage = null;
      _gpsFailureAlerted = false;
    });
    await _startNavigation();
  }

  Future<bool> _checkReadiness({required bool showMessages}) async {
    if (_checkingReadiness) return false;
    _checkingReadiness = true;
    try {
      var locationPermission = await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'GPS permission required',
            'Droobi needs location permission to calculate and follow your route. Android will now ask for permission.',
          );
        }
        locationPermission = await Geolocator.requestPermission();
      }
      if (locationPermission == LocationPermission.deniedForever) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'GPS permission is blocked',
            'Location permission is blocked for Droobi. Open app settings and allow location, then tap CONTINUE.',
          );
        }
        await Geolocator.openAppSettings();
        return false;
      }
      if (locationPermission == LocationPermission.denied) return false;

      if (!await Geolocator.isLocationServiceEnabled()) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'GPS is turned off',
            'GPS/location services are off. Android will open Location Settings so you can turn them on. Return to Droobi and tap CONTINUE.',
          );
        }
        await Geolocator.openLocationSettings();
        return false;
      }

      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      if (!scanStatus.isGranted || !connectStatus.isGranted) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'Bluetooth permission required',
            'Droobi needs Bluetooth permissions to find and connect to the navigation belt. Android will now ask for permission.',
          );
        }
        final results = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        if (results.values.any((status) => !status.isGranted)) return false;
      }

      final beltService = ref.read(beltConnectionServiceProvider);
      var bluetoothEnabled = false;
      try {
        bluetoothEnabled = await beltService.isBluetoothEnabled();
      } catch (_) {
        bluetoothEnabled = false;
      }
      if (!bluetoothEnabled) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'Bluetooth is turned off',
            'Bluetooth is off. Droobi will ask Android to turn Bluetooth on. If Android does not enable it automatically, turn it on in Quick Settings and tap CONTINUE.',
          );
        }
        try { await beltService.requestEnableBluetooth(); } catch (_) {}
        return false;
      }

      if (beltService.currentState != BeltConnectionState.connected) {
        if (showMessages && mounted) {
          await _showRequirementDialog(
            'Navigation belt not connected',
            'Turn on the ESP32 belt and keep it nearby. Droobi will search for it; navigation will not start until the belt is connected.',
          );
        }
        try { await beltService.scanAndConnect(); } catch (_) {}
        if (beltService.currentState != BeltConnectionState.connected) return false;
      }
      return true;
    } finally {
      _checkingReadiness = false;
    }
  }

  Future<void> _showRequirementDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerFailureAlarm() async {
    if (_alarmActive) return;
    _alarmActive = true;
    try {
      // 2 s on, 1 s off, 2 s on, 1 s off, 2 s on = 8 seconds.
      await Vibration.vibrate(pattern: [0, 2000, 1000, 2000, 1000, 2000]);
    } catch (_) {
      // Keep navigation usable if device vibration is unavailable.
    } finally {
      _alarmActive = false;
    }
  }

  void _handleNavigationFailure(NavigationSnapshot snapshot) {
    final message = (snapshot.errorMessage ?? '').toLowerCase();
    final gpsFailure = snapshot.state == NavigationState.gpsUnavailable ||
        (snapshot.state == NavigationState.routeUnavailable &&
            (message.contains('gps') || message.contains('location') || message.contains('position')));
    if (gpsFailure && !_gpsFailureAlerted) {
      _gpsFailureAlerted = true;
      _requiresResume = true;
      _showContinue = true;
      _triggerFailureAlarm();
      if (mounted) setState(() {});
    }
  }

  Future<void> _startNavigation() async {
    if (_starting) return;
    final beltService = ref.read(beltConnectionServiceProvider);
    if (beltService.currentState != BeltConnectionState.connected) {
      if (mounted) {
        setState(() => _showContinue = true);
        await _showRequirementDialog(
          'Navigation belt not connected',
          'Navigation cannot start until the belt is connected. Connect the belt and tap CONTINUE.',
        );
      }
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
        _handleNavigationFailure(snapshot);
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
      );
      _navigationHasStarted = true;
      if (mounted) setState(() {});
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

    

    ref.listen<AsyncValue<BeltConnectionState>>(
      beltConnectionStateProvider,
      (previous, next) {
        final oldState = previous?.asData?.value;
        final newState = next.asData?.value;
        if (newState == BeltConnectionState.connected) {
          _wasBeltConnected = true;
          return;
        }
        final lostConnection = _wasBeltConnected &&
            oldState == BeltConnectionState.connected &&
            newState != null &&
            newState != BeltConnectionState.connected;
        if (lostConnection) {
          _requiresResume = true;
          _showContinue = true;
          _triggerFailureAlarm();
          if (mounted) setState(() {});
        }
      },
    );

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
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
                color: Color(0xFF2F80ED),
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
        color = Colors.green.shade700;
        icon = Icons.bluetooth_connected;
        break;
      case BeltConnectionState.scanning:
        title = 'Searching for belt';
        description = 'Keep the ESP32 powered on and nearby.';
        color = Colors.blue.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.connecting:
        title = 'Connecting to belt';
        description = 'Establishing the Bluetooth connection.';
        color = Colors.blue.shade700;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.reconnecting:
        title = 'Bluetooth connection lost';
        description =
            'Trying to reconnect. Belt vibration is unavailable until it reconnects.';
        color = Colors.orange.shade800;
        icon = Icons.bluetooth_searching;
        break;
      case BeltConnectionState.disconnected:
      case BeltConnectionState.scanFailed:
        title = 'Belt not connected';
        description =
            'Navigation should be resumed after the belt reconnects. Tap CONTINUE when ready.';
        color = Colors.red.shade700;
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
                    color: Colors.grey.shade800,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade50,
            ),
            child: Icon(
              Icons.navigation,
              color: Colors.blue.shade700,
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
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (_snapshot.accuracyMeters != null)
            Text(
              'GPS\n±${_snapshot.accuracyMeters!.round()} m',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
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
            color: Colors.grey.shade600,
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
              color: Colors.blue.shade50,
              border: Border.all(
                color: Colors.blue.shade100,
                width: 3,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 140,
                color: Colors.blue.shade600,
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
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_snapshot.relativeAngle != null)
          Text(
            'Direction angle: '
            '${_snapshot.relativeAngle!.toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 8),
        if (_snapshot.heading != null)
          Text(
            'Heading: '
            '${_snapshot.heading!.toStringAsFixed(0)}°',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
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
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'You have arrived',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
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
              color: Colors.red,
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
    if (_showContinue || !_navigationHasStarted || _requiresResume) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _checkingReadiness || _starting ? null : _continueNavigation,
          child: Text(_checkingReadiness || _starting ? 'CHECKING...' : 'CONTINUE'),
        ),
      );
    }
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
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
        ),
        child: const Text('STOP NAVIGATION'),
      ),
    );
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    Vibration.cancel();
    super.dispose();
  }
}

