import 'package:geolocator/geolocator.dart';

import '../../models/lat_lon.dart';

enum LocationErrorType {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unknown,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type, this.message);

  final LocationErrorType type;
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<LatLon> getCurrentLocation() async {
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

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLon(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}