import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lat_lon.dart';
import '../../services/location/location_service.dart';
import '../../state/location_notifier.dart';

class LocationTestScreen extends ConsumerStatefulWidget {
  const LocationTestScreen({super.key});

  @override
  ConsumerState<LocationTestScreen> createState() =>
      _LocationTestScreenState();
}

class _LocationTestScreenState
    extends ConsumerState<LocationTestScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  LatLon? _location;

  Future<void> _getLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _location = null;
    });

    final locationService = ref.read(locationServiceProvider);

    try {
      final location = await locationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        _location = location;
      });
    } on LocationFailure catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _getLocation,
              child: Text(
                _isLoading
                    ? 'Getting location...'
                    : 'Get Current Location',
              ),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),

            if (_location != null) ...[
              const Text(
                'Current Location',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Latitude: ${_location!.latitude}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Longitude: ${_location!.longitude}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                _location.toString(),
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}