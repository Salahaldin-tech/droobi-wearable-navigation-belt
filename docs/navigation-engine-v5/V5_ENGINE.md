# Droobi Navigation Engine V5

Branch: `experiment/campus-public-osrm-v5` (created from `experiment/campus-public-osrm-v4`).
No external IMU is used. The engine only ends a session itself on confirmed arrival, as in V4. V5 adds no new automatic shutdown conditions.

## Pipeline

**Per GPS fix:** GPS filter → map matching → compass calibration from GPS course → arrival check → off-route check and reroute → guidance.

**Per compass sample:** true-north correction (WMM2025 on Android, `trueHeading` on iOS) → course offset → time-constant smoothing → guidance against the last matched route target.

## Changes from V4

| Area | V4 problem | V5 behaviour |
|---|---|---|
| GPS stream | `distanceFilter: 3`: no fixes while standing still, so arrival confirmation could stall at the destination | ~1 Hz time-based updates (Android `AndroidSettings`, iOS `AppleSettings` with fitness activity) |
| GPS gating | Raw speed check rejected honest fixes whenever reported accuracy was poor | Speed check subtracts the combined uncertainty of both fixes before comparing to walking speed |
| GPS anchor | A bad accepted fix made correct fixes look like jumps for up to ~10 s | Re-anchors after 3 rejected fixes that agree with each other, or after a 12 s gap |
| GPS smoothing | None in the navigation path | Constant-velocity Kalman filter in a local metric frame. It also estimates speed and course; the platform's Doppler course is used when available |
| Map matching | Searched only the next 8 vertices, recomputed the route length on every fix, and projected beyond the window (a hairpin's return leg could capture the user) | Geometry cached once per route, distance-based window clipped exactly, forward catch-up after GPS gaps |
| Turn detection | One vertex angle: curves drawn as many small OSRM vertices were missed | Angle measured over a ±6 m window, one turn per physical corner, with signed angle and distance to the turn |
| Cue bearing | Switched only after the projection passed the vertex | Follows the path, switches to the outgoing leg within 3 m of a turn, and applies a capped (25°), dead-banded steer back toward the path. When clearly off route, aims at the route target to rejoin |
| Compass, Android | Unknown accuracy (plugin default until the first sensor accuracy callback) was rejected forever, freezing the heading at its last value; campus startup could fail outright | Unknown accuracy is smoothed like MEDIUM and flagged `compassDegraded`. Startup falls back to unknown-accuracy samples with a stricter stability check |
| Compass, standard mode | Magnetic heading used as true north (no declination on Android) | Both modes use the same true-north sample pipeline |
| Compass bias | `CourseOffsetEstimator` existed but was unused, and trusted a single sample | Learns the phone-to-walking-direction offset (bounded to ±35°) only while walking straight with good GPS and a steady compass. It needs 5 consistent samples first |
| No compass | Navigation waited for a heading indefinitely | A walking user is guided by GPS course (`gpsCourse`). A compass that fails at startup no longer aborts the session |
| Rerouting | Campus mode only; each fix was matched twice | Both modes (standard: 20 m, 3 fixes, 10 s cooldown; campus: 12 m, 2 fixes, 5 s cooldown). Each fix is matched once. A failed reroute never ends the session |
| Lifecycle | A missing campus router left `start()` stuck in starting; `stop()` during routing was overridden when the route arrived; `dispose()` leaked the campus compass subscription | A session token cancels stale async work, and a newer `start()` supersedes an older one. All subscriptions are released |
| Belt bridge | Concurrent async writes could reorder; recovery states re-sent STOP for every snapshot | Writes are serialized in snapshot order; identical STOPs are collapsed, with a 2 s safety refresh |

## Snapshot additions (all optional)

- `headingSource`: `compass`, `compassDegraded` or `gpsCourse`.
- `remainingMeters`, `distanceToNextTurnMeters`, `nextTurnAngleDegrees` (positive means a right turn).
- `isOffRoute` and `courseOffsetDegrees`.

Debug builds show these on the Live Navigation card.

## Tests

`flutter test` runs 50 tests: the V4 suite plus GPS filter, route matching, course offset, end-to-end navigation engine (fake GPS, compass and router) and belt bridge tests.

## Known limitations / field-test checklist

- `router.project-osrm.org` is the OSRM *demo* server. As far as is publicly documented, it serves only the car profile and ignores `/foot/` in the URL. Campus routes may therefore follow driveways rather than footpaths. Check the route geometry in the field. If it is car-routed, choose a foot-profile endpoint; switching provider is a product decision and V5 does not make it.
- The ±35° bound on compass calibration cannot correct a phone carried sideways in a pocket. Guidance assumes the phone is held or chest-mounted, facing forward.
- Tune the thresholds (look-ahead, turn switch 3 m, cross-track dead band 4 m, off-route distances) on real campus walks.
