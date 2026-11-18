import 'dart:math' as math;

import '../../models/navigation_direction.dart';

/// Converts the relative route/phone angle into one of eight stable cues.
///
/// A new cue is confirmed only when the angle has stayed away from the
/// confirmed sector for [confirmationDuration] (one sector) or
/// [largeJumpDuration] (two or more sectors), and has rested in the new
/// sector for [settleDuration]. The away-time is measured from when the angle
/// first left the confirmed sector, so a fast phone rotation that sweeps
/// through intermediate sectors does not restart the wait at every sector.
class RelativeDirectionEngine {
  RelativeDirectionEngine({
    this.hysteresisDegrees = 9,
    this.confirmationDuration = const Duration(milliseconds: 500),
    this.largeJumpDuration = const Duration(milliseconds: 1000),
    this.settleDuration = const Duration(milliseconds: 250),
  });

  final double hysteresisDegrees;
  final Duration confirmationDuration;
  final Duration largeJumpDuration;

  /// Minimum time the angle must rest in the new sector before switching.
  final Duration settleDuration;

  NavigationDirection? _confirmed;
  NavigationDirection? _candidate;
  DateTime? _candidateSince;
  DateTime? _departedAt;

  NavigationDirection? get confirmedDirection => _confirmed;

  NavigationDirection update(
    double relativeAngle, {
    DateTime? timestamp,
    bool routeTurnContext = false,
  }) {
    final now = timestamp ?? DateTime.now();
    final angle = _wrap180(relativeAngle);
    final raw = _sector(angle);

    if (_confirmed == null) {
      _confirmed = raw;
      return raw;
    }

    if (raw == _confirmed) {
      _clearPending();
      return _confirmed!;
    }

    // Apply hysteresis only when the raw sector is adjacent. For a
    // multi-sector jump, require the longer dwell below rather than
    // accidentally preventing a valid fast phone turn.
    final adjacent = _sectorDistance(_confirmed!, raw) == 1;
    if (adjacent && !_hasClearedCurrentBoundary(angle, _confirmed!)) {
      _clearPending();
      return _confirmed!;
    }

    _departedAt ??= now;
    if (_candidate != raw) {
      _candidate = raw;
      _candidateSince = now;
    }

    final twoOrMoreSectors = _sectorDistance(_confirmed!, raw) >= 2;
    final required = routeTurnContext
        ? confirmationDuration
        : (twoOrMoreSectors ? largeJumpDuration : confirmationDuration);
    // A one-sector change keeps the original rule: the candidate itself must
    // persist for the full confirmation time.
    final settle = twoOrMoreSectors ? settleDuration : required;

    final awayLongEnough = now.difference(_departedAt!) >= required;
    final settled = now.difference(_candidateSince!) >= settle;
    if (awayLongEnough && settled) {
      _confirmed = raw;
      _clearPending();
    }
    return _confirmed!;
  }

  void reset() {
    _confirmed = null;
    _clearPending();
  }

  void _clearPending() {
    _candidate = null;
    _candidateSince = null;
    _departedAt = null;
  }

  bool _hasClearedCurrentBoundary(
    double angle,
    NavigationDirection current,
  ) {
    final center = _sectorCenter(current);
    final candidate = _sector(angle);
    final candidateCenter = _sectorCenter(candidate);
    final delta = _wrap180(angle - center);
    final candidateDelta = _wrap180(angle - candidateCenter);

    // Signed angular travel from the current sector center. For a new sector,
    // the sample must clear the shared edge by the hysteresis margin.
    final sectorStep = _wrap180(candidateCenter - center);
    final crossesPositive = sectorStep > 0 &&
        delta > 22.5 + hysteresisDegrees;
    final crossesNegative = sectorStep < 0 &&
        delta < -22.5 - hysteresisDegrees;
    return crossesPositive || crossesNegative ||
        candidateDelta.abs() > 22.5 + hysteresisDegrees;
  }
  NavigationDirection _sector(double angle) {
    final index = (((angle + 180 + 22.5) / 45).floor()) % 8;
    const values = <NavigationDirection>[
      NavigationDirection.back,
      NavigationDirection.backLeft,
      NavigationDirection.left,
      NavigationDirection.forwardLeft,
      NavigationDirection.forward,
      NavigationDirection.forwardRight,
      NavigationDirection.right,
      NavigationDirection.backRight,
    ];
    return values[index];
  }

  double _sectorCenter(NavigationDirection direction) {
    switch (direction) {
      case NavigationDirection.forward: return 0;
      case NavigationDirection.forwardRight: return 45;
      case NavigationDirection.right: return 90;
      case NavigationDirection.backRight: return 135;
      case NavigationDirection.back: return 180;
      case NavigationDirection.backLeft: return -135;
      case NavigationDirection.left: return -90;
      case NavigationDirection.forwardLeft: return -45;
    }
  }

  int _sectorDistance(NavigationDirection a, NavigationDirection b) {
    const order = <NavigationDirection>[
      NavigationDirection.forward,
      NavigationDirection.forwardRight,
      NavigationDirection.right,
      NavigationDirection.backRight,
      NavigationDirection.back,
      NavigationDirection.backLeft,
      NavigationDirection.left,
      NavigationDirection.forwardLeft,
    ];
    final diff = (order.indexOf(a) - order.indexOf(b)).abs();
    return math.min(diff, 8 - diff);
  }

  double _wrap180(double angle) {
    var result = angle % 360;
    if (result > 180) result -= 360;
    if (result <= -180) result += 360;
    return result;
  }
}
