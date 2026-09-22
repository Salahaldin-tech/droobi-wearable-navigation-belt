import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/navigation/compass_service.dart';
import '../../state/compass_notifier.dart';

class CompassTestScreen extends ConsumerStatefulWidget {
  const CompassTestScreen({super.key});

  @override
  ConsumerState<CompassTestScreen> createState() =>
      _CompassTestScreenState();
}

class _CompassTestScreenState
    extends ConsumerState<CompassTestScreen> {
  StreamSubscription<double>? _headingSubscription;

  double? _heading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _startCompass();
  }

  void _startCompass() {
    final compassService = ref.read(compassServiceProvider);

    _headingSubscription =
        compassService.headingStream.listen(
      (heading) {
        if (!mounted) return;

        setState(() {
          _heading = heading;
          _errorMessage = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          _errorMessage = error.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _headingSubscription?.cancel();
    super.dispose();
  }

  String _directionName(double heading) {
    if (heading >= 337.5 || heading < 22.5) {
      return 'North';
    }

    if (heading >= 22.5 && heading < 67.5) {
      return 'North-East';
    }

    if (heading >= 67.5 && heading < 112.5) {
      return 'East';
    }

    if (heading >= 112.5 && heading < 157.5) {
      return 'South-East';
    }

    if (heading >= 157.5 && heading < 202.5) {
      return 'South';
    }

    if (heading >= 202.5 && heading < 247.5) {
      return 'South-West';
    }

    if (heading >= 247.5 && heading < 292.5) {
      return 'West';
    }

    return 'North-West';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compass Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.explore,
                size: 80,
              ),

              const SizedBox(height: 24),

              const Text(
                'Phone Heading',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              if (_heading != null) ...[
                Text(
                  '${_heading!.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _directionName(_heading!),
                  style: const TextStyle(
                    fontSize: 24,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Reading compass...',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}