import 'dart:math' as math;

import '../../core/geo/geo_math.dart';
import '../../models/lat_lon.dart';
import '../../models/route_result.dart';

/// Map-matches the user's position onto the active route and derives the
/// guidance bearing.
///
/// Design:
/// * Route geometry (local metric coordinates, cumulative distance, turns) is
///   computed once per route, not on every GPS fix.
/// * Matching searches a distance window around the previous progress, so a
///   parallel or looping part of the route cannot capture the user. If the
///   window match is poor, a forward search lets progress catch up after a GPS
///   outage instead of causing a false off-route event.
/// * Turns are detected over a distance window, so a curve drawn as many small
///   vertices (typical OSRM output) is still recognised as one turn.
/// * The guidance bearing follows the route direction (not GPS → target), so
///   lateral GPS noise cannot invent a "cross the road" cue. It switches to the
///   outgoing direction only when the user is within a few meters of a turn,
///   and applies a capped, dead-banded correction when the user has clearly
///   drifted off the path line.
class RouteProgressService {
  RouteProgressService({
    this.defaultLookAheadMeters = 7.5,
    this.minimumLookAheadMeters = 3.5,
    this.maximumLookAheadMeters = 9.0,
    this.turnDetectionAngleDegrees = 35.0,
    this.turnWindowMeters = 6.0,
    this.turnSwitchDistanceMeters = 3.0,
    this.nearTurnDistanceMeters = 10.0,
    this.matchWindowBehindMeters = 10.0,
    this.matchWindowAheadMeters = 50.0,
    this.crossTrackDeadbandMeters = 4.0,
    this.crossTrackConvergenceMeters = 8.0,
    this.maximumCrossTrackCorrectionDegrees = 25.0,
  });

  /// Normal look-ahead on reasonably straight sections.
  final double defaultLookAheadMeters;

  /// Minimum look-ahead used when a meaningful turn is close.
  final double minimumLookAheadMeters;

  /// Maximum look-ahead on long straight sections.
  final double maximumLookAheadMeters;

  /// A route heading change larger than this is treated as a meaningful turn.
  final double turnDetectionAngleDegrees;

  /// Distance before/after a vertex used to measure its turn angle.
  final double turnWindowMeters;

  /// Within this distance of a turn the cue points along the outgoing leg.
  final double turnSwitchDistanceMeters;

  /// A turn closer than this marks the target as "near turn".
  final double nearTurnDistanceMeters;

  final double matchWindowBehindMeters;
  final double matchWindowAheadMeters;

  /// Lateral offset tolerated before steering back toward the path.
  final double crossTrackDeadbandMeters;

  /// Distance along the path over which the user is steered back.
  final double crossTrackConvergenceMeters;

  final double maximumCrossTrackCorrectionDegrees;

  RouteResult? _activeRoute;
  _RouteGeometry? _geometry;
  double _progressMeters = 0;
  bool _matched = false;

  double get totalRouteMeters => _geometry?.totalMeters ?? 0;

  double get remainingRouteMeters =>
      math.max(0.0, totalRouteMeters - _progressMeters).toDouble();

  /// Distance travelled along the active route.
  double get progressMeters => _progressMeters;

  void reset() {
    _activeRoute = null;
    _geometry = null;
    _progressMeters = 0;
    _matched = false;
  }

  // ================================================================
  // SIMPLE TARGET API
  // ================================================================

  LatLon getNextTargetPoint({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
  }) {
    return getNextTarget(
      currentPosition: currentPosition,
      route: route,
      lookAheadMeters: lookAheadMeters,
    ).point;
  }

  // ================================================================
  // MAIN TARGET CALCULATION
  // ================================================================

  /// Matches [currentPosition] to [route] and returns guidance data.
  ///
  /// [accuracyMeters] widens the cross-track dead band for poor fixes.
  RouteTarget getNextTarget({
    required LatLon currentPosition,
    required RouteResult route,
    double? lookAheadMeters,
    double? accuracyMeters,
  }) {
    if (route.polyline.isEmpty) {
      throw const RouteProgressFailure('Route polyline is empty.');
    }

    if (route.polyline.length == 1) {
      final only = route.polyline.first;
      return RouteTarget(
        point: only,
        index: 0,
        distanceAheadMeters: 0,
        distanceFromRouteMeters: distanceBetween(currentPosition, only),
        routeBearing: null,
        isNearTurn: false,
        projectedPoint: only,
        progressMeters: 0,
        remainingMeters: 0,
      );
    }

    if (!identical(_activeRoute, route)) {
      _activeRoute = route;
      _geometry = _RouteGeometry.build(
        route.polyline,
        turnWindowMeters: turnWindowMeters,
        turnAngleDegrees: turnDetectionAngleDegrees,
      );
      _progressMeters = 0;
      _matched = false;
    }
    final g = _geometry!;

    final match = _match(g, currentPosition);
    _progressMeters = match.along;
    _matched = true;

    final nextTurn = g.nextTurnAfter(match.along - 0.01);
    final distanceToTurn = nextTurn == null ? null : nextTurn.along - match.along;

    final lookAhead = lookAheadMeters ?? _adaptiveLookAhead(distanceToTurn);
    final targetAlong = math.min(g.totalMeters, match.along + lookAhead);
    final targetPoint = g.pointAt(targetAlong);

    final routeBearing = _pathBearing(g, match.along, lookAhead);

    // Guidance bearing: path direction, turned slightly back toward the path
    // when the user has clearly drifted off it.
    final deadband = math.max(
      crossTrackDeadbandMeters,
      math.min(10.0, (accuracyMeters ?? 0) * 0.7),
    );
    final excess = match.crossTrack.abs() - deadband;
    var guidanceBearing = routeBearing;
    if (excess > 0) {
      final correction = math
          .min(
            maximumCrossTrackCorrectionDegrees,
            math.atan2(excess, crossTrackConvergenceMeters) * 180 / math.pi,
          )
          .toDouble();
      // Right of the path → steer left, and vice versa.
      guidanceBearing = GeoMath.normalize360(
        routeBearing - correction * match.crossTrack.sign,
      );
    }

    final previousTurn = g.previousTurnAtOrBefore(match.along);
    final justPassedTurn = previousTurn != null &&
        match.along - previousTurn.along <= turnSwitchDistanceMeters;
    final isNearTurn = (distanceToTurn != null &&
            distanceToTurn <= nearTurnDistanceMeters) ||
        justPassedTurn;

    return RouteTarget(
      point: targetPoint,
      index: math.min(g.segmentIndexAt(targetAlong) + 1, g.points.length - 1),
      distanceAheadMeters: targetAlong - match.along,
      distanceFromRouteMeters: match.distance,
      routeBearing: routeBearing,
      guidanceBearing: guidanceBearing,
      isNearTurn: isNearTurn,
      projectedPoint: g.pointAt(match.along),
      segmentIndex: match.segment,
      crossTrackMeters: match.crossTrack,
      progressMeters: match.along,
      remainingMeters: math.max(0.0, g.totalMeters - match.along),
      distanceToNextTurnMeters: distanceToTurn,
      nextTurnAngleDegrees: nextTurn?.signedAngle,
    );
  }

  /// Bearing of travel along the route at [along], looking up to [lookAhead]
  /// meters ahead but never past the next turn, except when the turn is
  /// within [turnSwitchDistanceMeters] (then the outgoing leg is used).
  double _pathBearing(_RouteGeometry g, double along, double lookAhead) {
    final nextTurn = g.nextTurnAfter(along - 0.01);
    var from = along;
    var to = math.min(g.totalMeters, along + math.max(lookAhead, 2.0));
    if (nextTurn != null) {
      final toTurn = nextTurn.along - along;
      if (toTurn <= turnSwitchDistanceMeters) {
        // Point down the outgoing leg.
        from = nextTurn.along;
        final after = g.nextTurnAfter(nextTurn.along + 0.01);
        final limit = after?.along ?? g.totalMeters;
        to = math.min(limit, nextTurn.along + math.max(lookAhead, 2.0));
      } else {
        to = math.min(to, nextTurn.along);
      }
    }
    if (to - from < 0.5) {
      // At the very end of the route: use the final segment direction.
      return g.segmentBearing(g.segmentIndexAt(math.max(0.0, g.totalMeters - 0.01)));
    }
    return g.bearingBetween(from, to);
  }

  _Match _match(_RouteGeometry g, LatLon position) {
    final (px, py) = g.frame.toLocal(position);

    if (!_matched) {
      // First fix on this route: global search, preferring the start on ties.
      return g.project(px, py, 0, g.totalMeters);
    }

    final windowed = g.project(
      px,
      py,
      _progressMeters - matchWindowBehindMeters,
      _progressMeters + matchWindowAheadMeters,
    );
    if (windowed.distance <= 12.0) return windowed;

    // Poor windowed match: allow catching up further ahead (e.g. after a GPS
    // gap), but never jump backwards beyond the window.
    final forward = g.project(
      px,
      py,
      _progressMeters - matchWindowBehindMeters,
      g.totalMeters,
    );
    if (forward.distance < windowed.distance * 0.5) return forward;
    return windowed;
  }

  double _adaptiveLookAhead(double? turnDistance) {
    if (turnDistance == null) {
      return defaultLookAheadMeters
          .clamp(minimumLookAheadMeters, maximumLookAheadMeters)
          .toDouble();
    }
    if (turnDistance <= 7.0) return minimumLookAheadMeters;
    if (turnDistance <= 15.0) return 4.5;
    if (turnDistance <= 25.0) return 6.5;
    return maximumLookAheadMeters;
  }

  // ================================================================
  // NEAREST ROUTE POINT
  // ================================================================

  int findNearestPointIndex({
    required LatLon currentPosition,
    required List<LatLon> polyline,
  }) {
    if (polyline.isEmpty) {
      throw const RouteProgressFailure('Route polyline is empty.');
    }
    if (polyline.length == 1) return 0;
    final g = _RouteGeometry.build(
      polyline,
      turnWindowMeters: turnWindowMeters,
      turnAngleDegrees: turnDetectionAngleDegrees,
    );
    final (px, py) = g.frame.toLocal(currentPosition);
    return g.project(px, py, 0, g.totalMeters).segment;
  }

  // ================================================================
  // GEODESY
  // ================================================================

  double distanceBetween(LatLon first, LatLon second) =>
      GeoMath.distance(first, second);

  double calculateBearing({required LatLon from, required LatLon to}) =>
      GeoMath.bearing(from, to);
}

// ================================================================
// ROUTE TARGET
// ================================================================

class RouteTarget {
  const RouteTarget({
    required this.point,
    required this.index,
    required this.distanceAheadMeters,
    required this.distanceFromRouteMeters,
    required this.routeBearing,
    required this.isNearTurn,
    double? guidanceBearing,
    this.projectedPoint,
    this.segmentIndex = 0,
    this.crossTrackMeters = 0,
    this.progressMeters = 0,
    this.remainingMeters = 0,
    this.distanceToNextTurnMeters,
    this.nextTurnAngleDegrees,
  }) : guidanceBearing = guidanceBearing ?? routeBearing;

  /// Look-ahead point on the route.
  final LatLon point;

  /// Polyline vertex index at or after the target.
  final int index;

  /// Distance along the route from the matched position to [point].
  final double distanceAheadMeters;

  /// Distance between the GPS position and the route.
  final double distanceFromRouteMeters;

  /// Direction of travel along the route at the matched position.
  ///
  /// Deliberately different from the bearing from the user's GPS position to
  /// the target, so lateral noise cannot produce a crossing cue.
  final double? routeBearing;

  /// [routeBearing] with a bounded correction back toward the path line when
  /// the user has clearly drifted off it. Use this for the belt cue.
  final double? guidanceBearing;

  /// Whether a meaningful route turn is close (ahead or just passed).
  final bool isNearTurn;

  /// The user's position snapped onto the route.
  final LatLon? projectedPoint;

  final int segmentIndex;

  /// Signed lateral offset from the route: positive = right of the path.
  final double crossTrackMeters;

  final double progressMeters;
  final double remainingMeters;

  /// Distance along the route to the next meaningful turn, if any.
  final double? distanceToNextTurnMeters;

  /// Signed angle of the next turn: positive = right turn.
  final double? nextTurnAngleDegrees;
}

// ================================================================
// ROUTE GEOMETRY
// ================================================================

class _Turn {
  const _Turn(this.vertex, this.along, this.signedAngle);
  final int vertex;
  final double along;
  final double signedAngle;
}

class _Match {
  const _Match(this.segment, this.along, this.distance, this.crossTrack);
  final int segment;
  final double along;
  final double distance;
  final double crossTrack;
}

class _RouteGeometry {
  _RouteGeometry._(this.frame, this.points, this.xs, this.ys, this.cumulative,
      this.turns);

  final LocalFrame frame;
  final List<LatLon> points;
  final List<double> xs;
  final List<double> ys;
  final List<double> cumulative;
  final List<_Turn> turns;

  double get totalMeters => cumulative.last;

  static _RouteGeometry build(
    List<LatLon> polyline, {
    required double turnWindowMeters,
    required double turnAngleDegrees,
  }) {
    final frame = LocalFrame(polyline.first);
    final xs = <double>[];
    final ys = <double>[];
    for (final p in polyline) {
      final (x, y) = frame.toLocal(p);
      xs.add(x);
      ys.add(y);
    }
    final cumulative = <double>[0];
    for (var i = 1; i < polyline.length; i++) {
      final dx = xs[i] - xs[i - 1];
      final dy = ys[i] - ys[i - 1];
      cumulative.add(cumulative.last + math.sqrt(dx * dx + dy * dy));
    }
    final geometry = _RouteGeometry._(
        frame, List.unmodifiable(polyline), xs, ys, cumulative, <_Turn>[]);
    geometry._detectTurns(turnWindowMeters, turnAngleDegrees);
    return geometry;
  }

  void _detectTurns(double window, double threshold) {
    final candidates = <_Turn>[];
    for (var i = 1; i < points.length - 1; i++) {
      final at = cumulative[i];
      if (at <= 0.01 || at >= totalMeters - 0.01) continue;
      final before = math.max(0.0, at - window);
      final after = math.min(totalMeters, at + window);
      if (at - before < 0.5 || after - at < 0.5) continue;
      final incoming = bearingBetween(before, at);
      final outgoing = bearingBetween(at, after);
      final angle = GeoMath.wrap180(outgoing - incoming);
      if (angle.abs() >= threshold) candidates.add(_Turn(i, at, angle));
    }
    // Collapse vertices of one physical turn (within one window) into the
    // vertex with the sharpest angle.
    for (final c in candidates) {
      if (turns.isNotEmpty &&
          c.along - turns.last.along <= window &&
          c.signedAngle.sign == turns.last.signedAngle.sign) {
        if (c.signedAngle.abs() > turns.last.signedAngle.abs()) {
          turns[turns.length - 1] = c;
        }
      } else {
        turns.add(c);
      }
    }
  }

  _Turn? nextTurnAfter(double along) {
    for (final t in turns) {
      if (t.along > along) return t;
    }
    return null;
  }

  _Turn? previousTurnAtOrBefore(double along) {
    _Turn? result;
    for (final t in turns) {
      if (t.along <= along) {
        result = t;
      } else {
        break;
      }
    }
    return result;
  }

  int segmentIndexAt(double along) {
    if (along <= 0) return 0;
    var lo = 0;
    var hi = cumulative.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) >> 1;
      if (cumulative[mid] <= along) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return math.min(lo, points.length - 2);
  }

  (double, double) _xyAt(double along) {
    final a = along.clamp(0.0, totalMeters).toDouble();
    final i = segmentIndexAt(a);
    final len = cumulative[i + 1] - cumulative[i];
    final t = len <= 0 ? 0.0 : (a - cumulative[i]) / len;
    return (xs[i] + (xs[i + 1] - xs[i]) * t, ys[i] + (ys[i + 1] - ys[i]) * t);
  }

  LatLon pointAt(double along) {
    final a = along.clamp(0.0, totalMeters).toDouble();
    final i = segmentIndexAt(a);
    final len = cumulative[i + 1] - cumulative[i];
    final t = len <= 0 ? 0.0 : (a - cumulative[i]) / len;
    return GeoMath.interpolate(points[i], points[i + 1], t);
  }

  double bearingBetween(double fromAlong, double toAlong) {
    final (x1, y1) = _xyAt(fromAlong);
    final (x2, y2) = _xyAt(toAlong);
    return GeoMath.normalize360(math.atan2(x2 - x1, y2 - y1) * 180 / math.pi);
  }

  double segmentBearing(int i) => GeoMath.normalize360(
      math.atan2(xs[i + 1] - xs[i], ys[i + 1] - ys[i]) * 180 / math.pi);

  /// Projects (px, py) onto the route between [fromAlong] and [toAlong].
  _Match project(double px, double py, double fromAlong, double toAlong) {
    final first = segmentIndexAt(math.max(0.0, fromAlong));
    final last = segmentIndexAt(math.min(totalMeters, toAlong));
    var best = const _Match(0, 0, double.infinity, 0);
    for (var i = first; i <= last; i++) {
      final sx = xs[i + 1] - xs[i];
      final sy = ys[i + 1] - ys[i];
      final len2 = sx * sx + sy * sy;
      final rx = px - xs[i];
      final ry = py - ys[i];
      final len = math.sqrt(len2);
      var t = len2 <= 0 ? 0.0 : (rx * sx + ry * sy) / len2;
      // Clip to the search window, not merely to the segment: a long
      // segment that only partly lies in the window (e.g. the return leg of
      // a hairpin) must not capture the user outside that part.
      var tMin = 0.0;
      var tMax = 1.0;
      if (len > 0) {
        tMin = math.max(0.0, (fromAlong - cumulative[i]) / len);
        tMax = math.min(1.0, (toAlong - cumulative[i]) / len);
        if (tMax < tMin) continue;
      }
      t = t.clamp(tMin, tMax).toDouble();
      final qx = xs[i] + sx * t;
      final qy = ys[i] + sy * t;
      final dx = px - qx;
      final dy = py - qy;
      final distance = math.sqrt(dx * dx + dy * dy);
      // Strictly-less keeps the earliest segment on ties (vertex shared by
      // two segments).
      if (distance < best.distance - 1e-9) {
        // Cross product sign: positive when the point is right of travel.
        final cross = len2 <= 0 ? 0.0 : (sy * rx - sx * ry) / len;
        best = _Match(
          i,
          cumulative[i] + len * t,
          distance,
          cross.sign * distance,
        );
      }
    }
    return best;
  }
}

// ================================================================
// FAILURE
// ================================================================

class RouteProgressFailure implements Exception {
  const RouteProgressFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
