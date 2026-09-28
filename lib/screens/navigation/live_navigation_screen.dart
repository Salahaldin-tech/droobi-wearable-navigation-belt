
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../services/navigation/navigation_service.dart';
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
          title: const Text(
            'Live Navigation',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
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
                const SizedBox(height: 18),
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
    super.dispose();
  }
}

