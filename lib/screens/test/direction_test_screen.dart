import 'package:flutter/material.dart';

import '../../models/navigation_direction.dart';
import '../../services/navigation/direction_calculator.dart';

class DirectionTestScreen extends StatefulWidget {
  const DirectionTestScreen({super.key});

  @override
  State<DirectionTestScreen> createState() =>
      _DirectionTestScreenState();
}

class _DirectionTestScreenState
    extends State<DirectionTestScreen> {
  final DirectionCalculator _calculator =
      DirectionCalculator();

  double _relativeAngle = 0;

  NavigationDirection get _direction =>
      _calculator.directionFromAngle(_relativeAngle);

  void _setAngle(double angle) {
    setState(() {
      _relativeAngle = angle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Direction Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Relative Angle',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              '${_relativeAngle.toStringAsFixed(1)}°',
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _direction.command,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              _direction.name,
              style: const TextStyle(
                fontSize: 20,
              ),
            ),

            const SizedBox(height: 32),

            Expanded(
              child: ListView(
                children: [
                  _angleButton('F', 0),
                  _angleButton('FR', 45),
                  _angleButton('R', 90),
                  _angleButton('BR', 135),
                  _angleButton('B', 180),
                  _angleButton('BL', -135),
                  _angleButton('L', -90),
                  _angleButton('FL', -45),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _angleButton(String label, double angle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: () => _setAngle(angle),
        child: Text(
          '$label    ${angle.toStringAsFixed(0)}°',
        ),
      ),
    );
  }
}