import 'dart:math' as math;

import '../../models/navigation_direction.dart';

/// Converts the relative route/phone angle into one of eight stable cues.
class RelativeDirectionEngine {
  RelativeDirectionEngine({
    this.hysteresisDegrees = 9,
    this.confirmationDuration = const Duration(milliseconds: 500),
    this.largeJumpDuration = const Duration(milliseconds: 1000),
  });

  final double hysteresisDegrees;
  final Duration confirmationDuration;
  final Duration largeJumpDuration;

  NavigationDirection? _confirmed;
  NavigationDirection? _candidate;
  DateTime? _candidateSince;

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
      _candidate = null;
      _candidateSince = null;
      return _confirmed!;
    }

    // Apply hysteresis only when the raw sector is adjacent. For a
    // multi-sector jump, require the longer dwell below rather than
    // accidentally preventing a valid fast phone turn.
    final adjacent = _sectorDistance(_confirmed!, raw) == 1;
    if (adjacent && !_hasClearedCurrentBoundary(angle, _confirmed!)) {
      _candidate = null;
      _candidateSince = null;
      return _confirmed!;
    }

    if (_candidate != raw) {
      _candidate = raw;
      _candidateSince = now;
      return _confirmed!;
    }

    final started = _candidateSince ?? now;
    final twoOrMoreSectors = _sectorDistance(_confirmed!, raw) >= 2;
    final required = routeTurnContext
        ? confirmationDuration
        : (twoOrMoreSectors ? largeJumpDuration : confirmationDuration);

    if (now.difference(started) >= required) {
      _confirmed = raw;
      _candidate = null;
      _candidateSince = null;
    }
    return _confirmed!;
  }

  void reset() {
    _confirmed = null;
    _candidate = null;
    _candidateSince = null;
  }

  bool _hasClearedCurrentBoundary(
    double angle,
    NavigationDirection current,
  ) {
    final center = _sectorCenter(current);
    final delta = _wrap180(angle - center);
    final half = 22.5 + hysteresisDegrees;
    return delta.abs() > half;
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
