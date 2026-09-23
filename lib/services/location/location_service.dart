import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../models/lat_lon.dart';
import '../../models/location_fix.dart';

enum LocationErrorType {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
  unknown,
}

class LocationFailure implements Exception {
  const LocationFailure(
    this.type,
    this.message,
  );

  final LocationErrorType type;
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  // ============================================================
  // EXISTING API
  // ============================================================
  //
  // Keeps returning LatLon so existing GPS/routing test screens
  // continue working without any changes.
  //
  Future<LatLon> getCurrentLocation() async {
    final fix = await getCurrentLocationFix();
    return fix.position;
  }

  // ============================================================
  // NEW LOCATION FIX API
  // ============================================================
  //
  // Returns:
  // - GPS coordinates
  // - GPS accuracy
  // - timestamp
  //
  // This will be used by the new navigation filtering system.
  //
  Future<LocationFix> getCurrentLocationFix() async {
    await _ensureLocationAvailable();

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return _toLocationFix(position);
    } on LocationServiceDisabledException {
      throw const LocationFailure(
        LocationErrorType.serviceDisabled,
        'Location services are disabled. Please enable GPS.',
      );
    } on PermissionDeniedException {
      throw const LocationFailure(
        LocationErrorType.permissionDenied,
        'Location permission was denied.',
      );
    } catch (e) {
      throw LocationFailure(
        LocationErrorType.unavailable,
        'Could not get the current GPS location: $e',
      );
    }
  }

  // ============================================================
  // EXISTING-STYLE POSITION STREAM
  // ============================================================
  //
  // Returns only LatLon.
  //
  // Existing code can use this without knowing about LocationFix.
  //
  Stream<LatLon> get positionStream {
    return locationFixStream.map(
      (fix) => fix.position,
    );
  }

  // ============================================================
  // NEW LOCATION FIX STREAM
  // ============================================================
  //
  // Uses LocationSettings because this is the correct API form
  // for the Geolocator version currently used by the project.
  //
  Stream<LocationFix> get locationFixStream {
    final controller =
        StreamController<LocationFix>();

    StreamSubscription<Position>? subscription;

    () async {
      try {
        await _ensureLocationAvailable();

        subscription =
            Geolocator.getPositionStream(
          locationSettings:
              const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          ),
        ).listen(
          (position) {
            if (controller.isClosed) {
              return;
            }

            controller.add(
              _toLocationFix(position),
            );
          },
          onError: (Object error) {
            if (controller.isClosed) {
              return;
            }

            controller.addError(
              LocationFailure(
                LocationErrorType.unavailable,
                'GPS stream error: $error',
              ),
            );
          },
        );
      } catch (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      }
    }();

    controller.onCancel = () async {
      await subscription?.cancel();

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  // ============================================================
  // LOCATION SERVICE + PERMISSION
  // ============================================================

  Future<void> _ensureLocationAvailable() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationErrorType.serviceDisabled,
        'Location services are disabled. Please enable GPS.',
      );
    }

    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw const LocationFailure(
        LocationErrorType.permissionDenied,
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationErrorType.permissionDeniedForever,
        'Location permission was permanently denied. '
        'Please enable it from the app settings.',
      );
    }
  }

  // ============================================================
  // POSITION → LOCATION FIX
  // ============================================================

  LocationFix _toLocationFix(
    Position position,
  ) {
    return LocationFix(
      position: LatLon(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}