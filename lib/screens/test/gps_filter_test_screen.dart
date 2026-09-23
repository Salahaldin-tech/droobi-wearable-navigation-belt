import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/location_fix.dart';
import '../../models/lat_lon.dart';
import '../../services/location/gps_filter_service.dart';
import '../../services/location/location_service.dart';
import '../../services/location/position_filter_service.dart';

final gpsFilterTestServiceProvider =
    Provider<GpsFilterService>((ref) {
  return GpsFilterService();
});

final gpsFilterTestLocationServiceProvider =
    Provider<LocationService>((ref) {
  return LocationService();
});

final gpsPositionFilterTestServiceProvider =
    Provider<PositionFilterService>((ref) {
  return PositionFilterService();
});

class GpsFilterTestScreen extends ConsumerStatefulWidget {
  const GpsFilterTestScreen({super.key});

  @override
  ConsumerState<GpsFilterTestScreen> createState() =>
      _GpsFilterTestScreenState();
}

class _GpsFilterTestScreenState
    extends ConsumerState<GpsFilterTestScreen> {
  StreamSubscription<LocationFix>? _locationSubscription;

  LocationFix? _rawFix;
  LocationFix? _lastAcceptedFix;
  LocationFix? _firstAcceptedFix;
  LocationFix? _filteredFix;

  double? _rawToAcceptedDistance;
  double? _impliedSpeed;

  double _acceptedStraightLineDistance = 0.0;
  double _acceptedTotalDistance = 0.0;

  double _filteredStraightLineDistance = 0.0;
  double _filteredTotalDistance = 0.0;

  int _acceptedCount = 0;
  int _rejectedCount = 0;
  int _filteredCount = 0;

  String _status = 'Waiting for GPS...';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLocationStream();
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startLocationStream() async {
    await _locationSubscription?.cancel();

    final locationService =
        ref.read(
      gpsFilterTestLocationServiceProvider,
    );

    _locationSubscription =
        locationService.locationFixStream.listen(
      _processLocationFix,
      onError: (Object error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _status = 'GPS ERROR';
          _errorMessage = error.toString();
        });
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Waiting for GPS...';
      _errorMessage = null;
    });
  }

  void _processLocationFix(LocationFix rawFix) {
    if (!mounted) {
      return;
    }

    final gpsFilter =
        ref.read(
      gpsFilterTestServiceProvider,
    );

    final positionFilter =
        ref.read(
      gpsPositionFilterTestServiceProvider,
    );

    final previousAccepted =
        gpsFilter.lastAcceptedFix;

    double? distance;
    double? speed;

    if (previousAccepted != null) {
      distance = _distanceBetween(
        previousAccepted.position,
        rawFix.position,
      );

      final timeDifferenceSeconds =
          rawFix.timestamp
                  .difference(
                    previousAccepted.timestamp,
                  )
                  .inMilliseconds /
              1000.0;

      if (timeDifferenceSeconds > 0) {
        speed =
            distance / timeDifferenceSeconds;
      }
    }

    final accepted =
        gpsFilter.process(rawFix);

    if (accepted == null) {
      setState(() {
        _rawFix = rawFix;
        _rawToAcceptedDistance = distance;
        _impliedSpeed = speed;
        _rejectedCount++;
        _status = 'REJECTED';
        _errorMessage = null;
      });

      return;
    }

    final previousFiltered =
        positionFilter.lastFilteredFix;

    final filtered =
        positionFilter.process(accepted);

    _firstAcceptedFix ??= accepted;

    if (previousAccepted != null) {
      _acceptedTotalDistance +=
          _distanceBetween(
        previousAccepted.position,
        accepted.position,
      );
    }

    if (previousFiltered != null) {
      _filteredTotalDistance +=
          _distanceBetween(
        previousFiltered.position,
        filtered.position,
      );
    }

    _lastAcceptedFix = accepted;
    _filteredFix = filtered;

    _acceptedStraightLineDistance =
        _distanceBetween(
      _firstAcceptedFix!.position,
      accepted.position,
    );

    final firstFiltered =
        positionFilter.lastFilteredFix;

    // The first filtered fix is the first accepted fix.
    // We use the original first accepted position here.
    if (_firstAcceptedFix != null &&
        firstFiltered != null) {
      _filteredStraightLineDistance =
          _distanceBetween(
        _firstAcceptedFix!.position,
        filtered.position,
      );
    }

    _acceptedCount++;
    _filteredCount++;

    setState(() {
      _rawFix = rawFix;
      _rawToAcceptedDistance = distance;
      _impliedSpeed = speed;
      _status = 'ACCEPTED → FILTERED';
      _errorMessage = null;
    });
  }

  Future<void> _resetTest() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    ref
        .read(gpsFilterTestServiceProvider)
        .reset();

    ref
        .read(gpsPositionFilterTestServiceProvider)
        .reset();

    setState(() {
      _rawFix = null;
      _lastAcceptedFix = null;
      _firstAcceptedFix = null;
      _filteredFix = null;

      _rawToAcceptedDistance = null;
      _impliedSpeed = null;

      _acceptedStraightLineDistance = 0.0;
      _acceptedTotalDistance = 0.0;

      _filteredStraightLineDistance = 0.0;
      _filteredTotalDistance = 0.0;

      _acceptedCount = 0;
      _rejectedCount = 0;
      _filteredCount = 0;

      _status = 'Resetting...';
      _errorMessage = null;
    });

    await _startLocationStream();
  }

  double _distanceBetween(
    LatLon first,
    LatLon second,
  ) {
    const earthRadiusMeters = 6371000.0;

    final latitude1 =
        _degreesToRadians(first.latitude);

    final latitude2 =
        _degreesToRadians(second.latitude);

    final deltaLatitude =
        _degreesToRadians(
      second.latitude - first.latitude,
    );

    final deltaLongitude =
        _degreesToRadians(
      second.longitude - first.longitude,
    );

    final a =
        math.sin(deltaLatitude / 2) *
                math.sin(deltaLatitude / 2) +
            math.cos(latitude1) *
                math.cos(latitude2) *
                math.sin(deltaLongitude / 2) *
                math.sin(deltaLongitude / 2);

    final c =
        2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    return earthRadiusMeters * c;
  }

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees * math.pi / 180.0;
  }

  Color _statusBackgroundColor() {
    switch (_status) {
      case 'ACCEPTED → FILTERED':
        return Colors.green.shade50;

      case 'REJECTED':
        return Colors.red.shade50;

      case 'GPS ERROR':
        return Colors.orange.shade50;

      default:
        return Colors.grey.shade100;
    }
  }

  Color _statusTextColor() {
    switch (_status) {
      case 'ACCEPTED → FILTERED':
        return Colors.green.shade700;

      case 'REJECTED':
        return Colors.red.shade700;

      case 'GPS ERROR':
        return Colors.orange.shade800;

      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawFix = _rawFix;
    final acceptedFix = _lastAcceptedFix;
    final filteredFix = _filteredFix;
    final firstAccepted = _firstAcceptedFix;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'GPS Filter Test',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reset test',
            onPressed: _resetTest,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'GPS FILTER TEST',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 20),

            // --------------------------------------------------
            // STATUS
            // --------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              decoration: BoxDecoration(
                color: _statusBackgroundColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _statusTextColor(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Accepted: $_acceptedCount'
                    '   •   '
                    'Rejected: $_rejectedCount',
                    style: const TextStyle(
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // RAW GPS
            // --------------------------------------------------

            const _SectionTitle(
              'RAW GPS',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Latitude',
                  value: rawFix == null
                      ? '--'
                      : rawFix.position.latitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Longitude',
                  value: rawFix == null
                      ? '--'
                      : rawFix.position.longitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Accuracy',
                  value: rawFix == null
                      ? '--'
                      : '${rawFix.accuracyMeters.toStringAsFixed(1)} m',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // GPS QUALITY FILTER
            // --------------------------------------------------

            const _SectionTitle(
              'GPS QUALITY FILTER',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Result',
                  value: _acceptedCount == 0
                      ? '--'
                      : acceptedFix == null
                          ? 'REJECTED'
                          : 'ACCEPTED',
                ),
                _InfoRow(
                  label: 'Distance from previous',
                  value:
                      _rawToAcceptedDistance == null
                          ? '--'
                          : '${_rawToAcceptedDistance!.toStringAsFixed(2)} m',
                ),
                _InfoRow(
                  label: 'Implied speed',
                  value: _impliedSpeed == null
                      ? '--'
                      : '${_impliedSpeed!.toStringAsFixed(2)} m/s',
                ),
                const _InfoRow(
                  label: 'Accuracy limit',
                  value: '25.0 m',
                ),
                const _InfoRow(
                  label: 'Speed limit',
                  value: '3.0 m/s',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // ACCEPTED MOVEMENT
            // --------------------------------------------------

            const _SectionTitle(
              'ACCEPTED GPS MOVEMENT',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Straight-line displacement',
                  value:
                      '${_acceptedStraightLineDistance.toStringAsFixed(2)} m',
                ),
                _InfoRow(
                  label: 'Total accepted distance',
                  value:
                      '${_acceptedTotalDistance.toStringAsFixed(2)} m',
                ),
                _InfoRow(
                  label: 'Accepted fixes',
                  value: '$_acceptedCount',
                ),
                _InfoRow(
                  label: 'Rejected fixes',
                  value: '$_rejectedCount',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // POSITION FILTER
            // --------------------------------------------------

            const _SectionTitle(
              'POSITION FILTER',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Filtered fixes',
                  value: '$_filteredCount',
                ),
                _InfoRow(
                  label: 'Smoothing factor',
                  value: '0.65',
                ),
                _InfoRow(
                  label: 'Large jump threshold',
                  value: '15.0 m',
                ),
                _InfoRow(
                  label: 'Filtered displacement',
                  value:
                      '${_filteredStraightLineDistance.toStringAsFixed(2)} m',
                ),
                _InfoRow(
                  label: 'Filtered total distance',
                  value:
                      '${_filteredTotalDistance.toStringAsFixed(2)} m',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // FIRST ACCEPTED
            // --------------------------------------------------

            const _SectionTitle(
              'START ACCEPTED POSITION',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Latitude',
                  value: firstAccepted == null
                      ? '--'
                      : firstAccepted.position.latitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Longitude',
                  value: firstAccepted == null
                      ? '--'
                      : firstAccepted.position.longitude
                          .toStringAsFixed(7),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // ACCEPTED POSITION
            // --------------------------------------------------

            const _SectionTitle(
              'LAST ACCEPTED POSITION',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Latitude',
                  value: acceptedFix == null
                      ? '--'
                      : acceptedFix.position.latitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Longitude',
                  value: acceptedFix == null
                      ? '--'
                      : acceptedFix.position.longitude
                          .toStringAsFixed(7),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // FILTERED POSITION
            // --------------------------------------------------

            const _SectionTitle(
              'FINAL FILTERED POSITION',
            ),

            _InfoCard(
              children: [
                _InfoRow(
                  label: 'Latitude',
                  value: filteredFix == null
                      ? '--'
                      : filteredFix.position.latitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Longitude',
                  value: filteredFix == null
                      ? '--'
                      : filteredFix.position.longitude
                          .toStringAsFixed(7),
                ),
                _InfoRow(
                  label: 'Accuracy',
                  value: filteredFix == null
                      ? '--'
                      : '${filteredFix.accuracyMeters.toStringAsFixed(1)} m',
                ),
              ],
            ),

            const SizedBox(height: 28),

            // --------------------------------------------------
            // TEST INSTRUCTIONS
            // --------------------------------------------------

            _InfoCard(
              children: const [
                Text(
                  'TEST PROCEDURE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '1. Press reset.\n'
                  '2. Stand still for 30 seconds.\n'
                  '3. Walk 25–30 meters in a straight line.\n'
                  '4. Stop and wait 10 seconds.\n'
                  '5. Compare Accepted GPS Movement '
                  'with Position Filter results.\n\n'
                  'The goal is not to maximize ACCEPTED readings. '
                  'The goal is to obtain a stable position while '
                  'still following real movement.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              _InfoCard(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SECTION TITLE
// ================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ================================================================
// INFO CARD
// ================================================================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black45,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}