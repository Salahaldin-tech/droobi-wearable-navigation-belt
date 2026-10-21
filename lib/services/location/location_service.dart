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
  // Keeps the existing LatLon API for screens and older callers.
  Future<LatLon> getCurrentLocation() async {
    final fix = await getCurrentLocationFix();
    return fix.position;
  }

  // Returns coordinates, accuracy, and timestamp for navigation.
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

  Stream<LatLon> get positionStream {
    return locationFixStream.map((fix) => fix.position);
  }

  Stream<LocationFix> get locationFixStream {
    final controller = StreamController<LocationFix>();

    StreamSubscription<Position>? positionSubscription;
    StreamSubscription<ServiceStatus>? serviceStatusSubscription;

    () async {
      try {
        await _ensureLocationAvailable();

        positionSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          ),
        ).listen(
          (position) {
            if (controller.isClosed) {
              return;
            }

            controller.add(_toLocationFix(position));
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

        // Detect GPS/location services being disabled during navigation,
        // instead of waiting for another position event to reveal it.
        serviceStatusSubscription =
            Geolocator.getServiceStatusStream().listen(
          (status) {
            if (controller.isClosed ||
                status != ServiceStatus.disabled) {
              return;
            }

            controller.addError(
              const LocationFailure(
                LocationErrorType.serviceDisabled,
                'Location services were turned off. Enable GPS to resume navigation.',
              ),
            );
          },
          onError: (Object error) {
            if (controller.isClosed) {
              return;
            }

            controller.addError(
              LocationFailure(
                LocationErrorType.unavailable,
                'Could not monitor GPS service status: $error',
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
      await positionSubscription?.cancel();
      await serviceStatusSubscription?.cancel();

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  Future<void> _ensureLocationAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationFailure(
        LocationErrorType.serviceDisabled,
        'Location services are disabled. Please enable GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationFailure(
        LocationErrorType.permissionDenied,
        'Location permission was denied.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationErrorType.permissionDeniedForever,
        'Location permission was permanently denied. '
        'Please enable it from the app settings.',
      );
    }
  }

  LocationFix _toLocationFix(Position position) {
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
