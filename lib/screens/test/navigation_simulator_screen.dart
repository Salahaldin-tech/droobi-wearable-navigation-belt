import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lat_lon.dart';
import '../../models/navigation_direction.dart';
import '../../models/route_result.dart';
import '../../services/navigation/direction_calculator.dart';
import '../../services/navigation/heading_estimator.dart';
import '../../services/navigation/relative_direction_engine.dart';
import '../../services/navigation/route_progress_service.dart';

/// Deterministic, sensor-free simulator for the navigation direction pipeline.
///
/// It feeds a synthetic GPS position and user-controlled phone heading into
/// the same route-progress, heading-estimation and relative-direction services
/// used by the live navigation engine. It does not start BLE or real GPS.
class NavigationSimulatorScreen extends StatefulWidget {
  const NavigationSimulatorScreen({super.key});

  @override
  State<NavigationSimulatorScreen> createState() =>
      _NavigationSimulatorScreenState();
}

class _NavigationSimulatorScreenState
    extends State<NavigationSimulatorScreen> {
  // A compact sample route with two turns. Coordinates are only simulation
  // geometry; replace them with an imported campus route in a later iteration.
  static const List<LatLon> _routePoints = [
    LatLon(latitude: 32.462000, longitude: 35.298000),
    LatLon(latitude: 32.462350, longitude: 35.298000),
    LatLon(latitude: 32.462350, longitude: 35.298420),
    LatLon(latitude: 32.462080, longitude: 35.298420),
    LatLon(latitude: 32.462080, longitude: 35.298780),
  ];

  final RouteProgressService _progressService = RouteProgressService();
  final DirectionCalculator _directionCalculator = DirectionCalculator();
  final HeadingEstimator _headingEstimator = HeadingEstimator();
  final RelativeDirectionEngine _directionEngine = RelativeDirectionEngine();

  late final RouteResult _route;
  late final List<double> _segmentLengths;
  late final double _totalDistance;

  Timer? _timer;
  bool _isPlaying = false;
  bool _gpsDriftEnabled = false;
  double _distanceTravelled = 0;
  double _phoneHeading = 0;
  double _speedMetersPerSecond = 1.2;
  double _gpsDriftMeters = 0;
  double? _routeBearing;
  double? _relativeAngle;
  NavigationDirection? _rawDirection;
  NavigationDirection? _stableDirection;
  double _distanceFromRoute = 0;
  bool _nearTurn = false;

  @override
  void initState() {
    super.initState();
    _route = RouteResult(
      polyline: _routePoints,
      distanceMeters: 0,
      durationSeconds: 0,
    );
    _segmentLengths = [
      for (var i = 0; i < _routePoints.length - 1; i++)
        _distanceBetween(_routePoints[i], _routePoints[i + 1]),
    ];
    _totalDistance = _segmentLengths.fold<double>(0.0, (sum, value) => sum + value);
    _recalculate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  LatLon _positionAt(double distance) {
    var remaining = distance.clamp(0.0, _totalDistance).toDouble();
    for (var i = 0; i < _segmentLengths.length; i++) {
      final length = _segmentLengths[i];
      if (remaining <= length || i == _segmentLengths.length - 1) {
        final fraction = length <= 0 ? 0.0 : (remaining / length).clamp(0.0, 1.0);
        final start = _routePoints[i];
        final end = _routePoints[i + 1];
        return LatLon(
          latitude: start.latitude + (end.latitude - start.latitude) * fraction,
          longitude: start.longitude + (end.longitude - start.longitude) * fraction,
        );
      }
      remaining -= length;
    }
    return _routePoints.last;
  }

  LatLon _applyGpsDrift(LatLon position) {
    if (!_gpsDriftEnabled || _gpsDriftMeters == 0) return position;

    var remaining = _distanceTravelled;
    var segmentIndex = 0;
    while (segmentIndex < _segmentLengths.length - 1 &&
        remaining > _segmentLengths[segmentIndex]) {
      remaining -= _segmentLengths[segmentIndex];
      segmentIndex++;
    }
    final segmentBearing = _directionCalculator.calculateBearing(
      from: _routePoints[segmentIndex],
      to: _routePoints[segmentIndex + 1],
    );
    final lateralBearing = (segmentBearing + 90) * math.pi / 180;
    final eastMeters = math.sin(lateralBearing) * _gpsDriftMeters;
    final northMeters = math.cos(lateralBearing) * _gpsDriftMeters;
    final longitudeMeters =
        111320 * math.cos(position.latitude * math.pi / 180);

    // Offset perpendicular to the active route segment, not always east-west.
    return LatLon(
      latitude: position.latitude + northMeters / 111320,
      longitude: position.longitude + eastMeters / longitudeMeters,
    );
  }

  void _recalculate() {
    final actualPosition = _positionAt(_distanceTravelled);
    final simulatedGps = _applyGpsDrift(actualPosition);
    final target = _progressService.getNextTarget(
      currentPosition: simulatedGps,
      route: _route,
      lookAheadMeters: null,
    );
    final bearing = target.routeBearing ??
        _directionCalculator.calculateBearing(
          from: simulatedGps,
          to: target.point,
        );
    final heading = _headingEstimator.update(
          _phoneHeading,
          timestamp: DateTime.now(),
        ) ??
        _phoneHeading;
    final angle = _directionCalculator.normalizeAngle(bearing - heading);
    final raw = _directionCalculator.directionFromAngle(angle);
    final stable = _directionEngine.update(
      angle,
      timestamp: DateTime.now(),
      routeTurnContext: target.isNearTurn,
    );

    if (!mounted) return;
    setState(() {
      _routeBearing = bearing;
      _relativeAngle = angle;
      _rawDirection = raw;
      _stableDirection = stable;
      _distanceFromRoute = target.distanceFromRouteMeters;
      _nearTurn = target.isNearTurn;
    });
  }

  void _start() {
    if (_isPlaying || _distanceTravelled >= _totalDistance) return;
    setState(() => _isPlaying = true);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final next = _distanceTravelled + _speedMetersPerSecond * 0.25;
      setState(() {
        _distanceTravelled = math.min(next, _totalDistance).toDouble();
        if (_distanceTravelled >= _totalDistance) _isPlaying = false;
      });
      _recalculate();
      if (!_isPlaying) _timer?.cancel();
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  void _reset() {
    _timer?.cancel();
    _progressService.reset();
    _headingEstimator.reset();
    _directionEngine.reset();
    setState(() {
      _isPlaying = false;
      _distanceTravelled = 0;
      _routeBearing = null;
      _relativeAngle = null;
      _rawDirection = null;
      _stableDirection = null;
      _distanceFromRoute = 0;
      _nearTurn = false;
    });
    _recalculate();
  }

  void _onHeadingChanged(double value) {
    _phoneHeading = value;
    _headingEstimator.reset();
    _directionEngine.reset();
    _recalculate();
  }

  double _distanceBetween(LatLon a, LatLon b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  String _directionName(NavigationDirection? value) {
    if (value == null) return '—';
    return switch (value) {
      NavigationDirection.forward => 'Forward',
      NavigationDirection.forwardRight => 'Forward-right',
      NavigationDirection.right => 'Right',
      NavigationDirection.backRight => 'Back-right',
      NavigationDirection.back => 'Back',
      NavigationDirection.backLeft => 'Back-left',
      NavigationDirection.left => 'Left',
      NavigationDirection.forwardLeft => 'Forward-left',
    };
  }

  String _degrees(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}°';

  Widget _metric(String label, String value, {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.brown,
              backgroundColor: highlight ? AppColors.cream : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDistance == 0 ? 0.0 : _distanceTravelled / _totalDistance;
    final currentPosition = _applyGpsDrift(_positionAt(_distanceTravelled));

    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Simulator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Simulation Route', [
            SizedBox(
              height: 230,
              width: double.infinity,
              child: CustomPaint(
                painter: _RoutePainter(
                  points: _routePoints,
                  currentPosition: currentPosition,
                  phoneHeading: _phoneHeading,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sample route • ${_routePoints.length} points • ${_totalDistance.toStringAsFixed(1)} m',
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress, color: AppColors.brown),
            const SizedBox(height: 6),
            Text('${_distanceTravelled.toStringAsFixed(1)} m / ${_totalDistance.toStringAsFixed(1)} m'),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isPlaying || progress >= 1 ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPlaying ? _pause : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Reset simulation',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ]),
          _section('Simulated Phone Compass', [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Phone heading'),
                Text(_degrees(_phoneHeading), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _phoneHeading,
              min: 0,
              max: 359,
              divisions: 359,
              label: _degrees(_phoneHeading),
              onChanged: _onHeadingChanged,
            ),
            const Text('Change this slider to rotate the virtual phone without moving the simulated GPS position.'),
          ]),
          _section('Simulation Controls', [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Walking speed'),
                Text('${_speedMetersPerSecond.toStringAsFixed(1)} m/s'),
              ],
            ),
            Slider(
              value: _speedMetersPerSecond,
              min: 0.3,
              max: 2.5,
              divisions: 22,
              onChanged: (value) => setState(() => _speedMetersPerSecond = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate GPS drift'),
              subtitle: const Text('Shift the simulated GPS position sideways from the route.'),
              value: _gpsDriftEnabled,
              onChanged: (value) {
                setState(() => _gpsDriftEnabled = value);
                _recalculate();
              },
            ),
            if (_gpsDriftEnabled) ...[
              Text('Lateral GPS offset: ${_gpsDriftMeters.toStringAsFixed(1)} m'),
              Slider(
                value: _gpsDriftMeters,
                min: -30,
                max: 30,
                divisions: 60,
                onChanged: (value) {
                  setState(() => _gpsDriftMeters = value);
                  _recalculate();
                },
              ),
            ],
          ]),
          _section('Navigation Engine Output', [
            Row(
              children: [
                Expanded(child: _metric('Route bearing', _degrees(_routeBearing))),
                const SizedBox(width: 8),
                Expanded(child: _metric('Phone heading', _degrees(_phoneHeading))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _metric('Relative angle', _degrees(_relativeAngle))),
                const SizedBox(width: 8),
                Expanded(child: _metric('GPS cross-track', '${_distanceFromRoute.toStringAsFixed(1)} m')),
              ],
            ),
            const SizedBox(height: 12),
            _metric('Raw direction', _directionName(_rawDirection)),
            const SizedBox(height: 8),
            _metric('Confirmed direction', _directionName(_stableDirection), highlight: true),
            const SizedBox(height: 8),
            Text(_nearTurn ? 'Turn context: approaching a route turn' : 'Turn context: normal route segment'),
            if (progress >= 1) ...[
              const SizedBox(height: 12),
              const Text('Route simulation completed. Reset to replay.'),
            ],
          ]),
          const Text(
            'Developer tool only: this screen uses synthetic GPS and a manually controlled heading. It does not use the phone compass, real GPS, BLE, or the ESP32.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.points,
    required this.currentPosition,
    required this.phoneHeading,
  });

  final List<LatLon> points;
  final LatLon currentPosition;
  final double phoneHeading;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const padding = 22.0;
    final minLat = points.map((p) => p.latitude).reduce((a, b) => math.min(a, b).toDouble());
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => math.max(a, b).toDouble());
    final minLon = points.map((p) => p.longitude).reduce((a, b) => math.min(a, b).toDouble());
    final maxLon = points.map((p) => p.longitude).reduce((a, b) => math.max(a, b).toDouble());
    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();

    Offset project(LatLon p) {
      final x = padding + (p.longitude - minLon) / (lonRange == 0 ? 1 : lonRange) * (size.width - padding * 2);
      final y = size.height - padding - (p.latitude - minLat) / (latRange == 0 ? 1 : latRange) * (size.height - padding * 2);
      return Offset(x, y);
    }

    final routePaint = Paint()
      ..color = AppColors.brown.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final routePath = Path()..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      routePath.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(routePath, routePaint);

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(project(points[i]), 5, Paint()..color = AppColors.brown);
    }

    final user = project(currentPosition);
    canvas.drawCircle(user, 10, Paint()..color = AppColors.cream);
    canvas.drawCircle(user, 7, Paint()..color = AppColors.brown);
    final radians = (phoneHeading - 90) * math.pi / 180;
    final tip = Offset(user.dx + math.cos(radians) * 28, user.dy + math.sin(radians) * 28);
    canvas.drawLine(user, tip, Paint()
      ..color = AppColors.brown
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.currentPosition.latitude != currentPosition.latitude ||
      oldDelegate.currentPosition.longitude != currentPosition.longitude ||
      oldDelegate.phoneHeading != phoneHeading ||
      oldDelegate.points != points;
}
