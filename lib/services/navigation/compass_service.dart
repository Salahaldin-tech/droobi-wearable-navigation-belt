import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompassService {
  Stream<double> get headingStream {
    final events = FlutterCompass.events;

    if (events == null) {
      return const Stream.empty();
    }

    return events
        .map((event) => event.heading)
        .where((heading) => heading != null)
        .map((heading) => _normalizeHeading(heading!));
  }

  Future<double> getCurrentHeading() async {
    final events = FlutterCompass.events;

    if (events == null) {
      throw const CompassFailure(
        'Compass sensor is not available on this device.',
      );
    }

    final event = await events.first;

    final heading = event.heading;

    if (heading == null) {
      throw const CompassFailure(
        'Could not read the phone compass heading.',
      );
    }

    return _normalizeHeading(heading);
  }

  double _normalizeHeading(double heading) {
    var normalized = heading % 360;

    if (normalized < 0) {
      normalized += 360;
    }

    return normalized;
  }
}

class CompassFailure implements Exception {
  const CompassFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final compassServiceProvider = Provider<CompassService>((ref) {
  return CompassService();
});