import 'dart:async';

import 'package:droobi/core/enums/belt_command.dart';
import 'package:droobi/core/enums/belt_connection_state.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/location_fix.dart';
import 'package:droobi/models/route_result.dart';
import 'package:droobi/services/ble/belt_connection_service.dart';
import 'package:droobi/services/ble/belt_navigation_bridge.dart';
import 'package:droobi/services/location/location_service.dart';
import 'package:droobi/services/navigation/compass_service.dart';
import 'package:droobi/services/navigation/heading_north_corrector.dart';
import 'package:droobi/services/navigation/navigation_service.dart';
import 'package:droobi/services/routing/routing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBelt implements BeltConnectionService {
  final List<BeltCommand> sent = <BeltCommand>[];
  int _writes = 0;

  @override
  Future<bool> sendCommand(BeltCommand command) async {
    // Earlier writes take longer, so unchained writes would reorder.
    final delay = 30 - (_writes++ * 10);
    await Future<void>.delayed(Duration(milliseconds: delay < 0 ? 0 : delay));
    sent.add(command);
    return true;
  }

  @override
  void Function()? onReconnected;

  @override
  Stream<BeltConnectionState> get connectionState => const Stream.empty();
  @override
  BeltConnectionState get currentState => BeltConnectionState.connected;
  @override
  BeltCommand? get lastSentCommand => sent.isEmpty ? null : sent.last;
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Future<void> disconnect() async {}
  @override
  void dispose() {}
  @override
  Future<void> scanAndConnect() async {}
  @override
  Future<bool> sendHeartbeat() async => true;
}

class _Location extends LocationService {
  @override
  Future<LocationFix> getCurrentLocationFix() async => LocationFix(
        position: const LatLon(latitude: 32.41, longitude: 35.29),
        accuracyMeters: 4,
        timestamp: DateTime.utc(2026, 11, 15),
      );
  @override
  Stream<LocationFix> get locationFixStream => const Stream.empty();
}

class _Router implements RoutingService {
  @override
  Future<RouteResult> computeRoute(
          {required LatLon origin, required LatLon destination}) async =>
      RouteResult(
          polyline: [origin, destination],
          distanceMeters: 100,
          durationSeconds: 80);
}

NavigationService _navigation() => NavigationService(
      locationService: _Location(),
      routingService: _Router(),
      compassService: CompassService(
        sampleSource: Stream<CompassSample>.periodic(
          const Duration(milliseconds: 20),
          (_) => CompassSample(
            rawHeadingDegrees: 0,
            accuracyDegrees: 15,
            timestamp: DateTime.now(),
          ),
        ).asBroadcastStream(),
      ),
      headingNorthCorrector: HeadingNorthCorrector(platform: TargetPlatform.iOS),
    );

void main() {
  test('collapses repeated STOP snapshots', () async {
    final belt = _RecordingBelt();
    final navigation = _navigation();
    final bridge = BeltNavigationBridge(
      navigationService: navigation,
      beltConnectionService: belt,
    )..start();

    for (var i = 0; i < 5; i++) {
      await navigation.stop();
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(belt.sent.where((c) => c == BeltCommand.stop), hasLength(1));
    await bridge.dispose();
    await navigation.dispose();
  });

  test('delivers commands in snapshot order', () async {
    final belt = _RecordingBelt();
    final navigation = _navigation();
    final bridge = BeltNavigationBridge(
      navigationService: navigation,
      beltConnectionService: belt,
    )..start();

    await navigation.start(
        destination: const LatLon(latitude: 32.4109, longitude: 35.29));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // starting → STOP, then the live forward cue; the cue must be last.
    expect(belt.sent.first, BeltCommand.stop);
    expect(belt.sent.last, BeltCommand.front);
    await bridge.dispose();
    await navigation.dispose();
  });
}
