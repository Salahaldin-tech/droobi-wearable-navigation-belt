import 'package:droobi/l10n/l10n.dart';
import 'package:droobi/models/lat_lon.dart';
import 'package:droobi/models/navigation_direction.dart';
import 'package:droobi/models/route_result.dart';
import 'package:droobi/screens/navigation/live_navigation_screen.dart';
import 'package:droobi/services/navigation/navigation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_test_harness.dart';

/// A realistic campus ("Uni") navigation snapshot with every optional
/// line populated, which is the tallest layout the screen can show.
const _campusSnapshot = NavigationSnapshot(
  state: NavigationState.navigating,
  accuracyMeters: 6,
  distanceFromRouteMeters: 2.4,
  heading: 87,
  relativeAngle: 92,
  direction: NavigationDirection.right,
  headingSource: HeadingSource.compass,
  remainingMeters: 184,
  distanceToNextTurnMeters: 23,
  nextTurnAngleDegrees: 88,
  courseOffsetDegrees: 4,
  route: RouteResult(
    polyline: [
      LatLon(latitude: 32.41, longitude: 35.33),
      LatLon(latitude: 32.42, longitude: 35.34),
    ],
    distanceMeters: 200,
    durationSeconds: 160,
    destinationSnapMeters: 1.3,
  ),
);

Widget _screen(AppLanguage language, {double textScale = 1.0}) =>
    localizedApp(
      language: language,
      textScale: textScale,
      overrides: navigationOverrides(_campusSnapshot),
      home: const LiveNavigationScreen(
        destination: LatLon(latitude: 32.42, longitude: 35.34),
        campusNavigation: true,
      ),
    );

void main() {
  setUpAll(loadAppFonts);

  for (final language in AppLanguage.values) {
    for (final entry in phoneSizes.entries) {
      testWidgets(
          'Uni live navigation has no overflow on ${entry.key} '
          '(${language.code})', (tester) async {
        usePhoneSize(tester, entry.value);
        await tester.pumpWidget(_screen(language));
        await tester.pump(); // post-frame start()
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        // The stop button is always pinned on screen.
        expect(find.byType(ElevatedButton), findsOneWidget);
        // On regular phones the guidance fits without any scrolling.
        if (entry.value.height >= 640) {
          expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        }
        // The direction guidance is reachable (scrolls into view on the
        // smallest phones instead of being clipped).
        await tester.scrollUntilVisible(
          find.byIcon(Icons.arrow_forward),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Uni live navigation has no overflow at 1.3x text '
        '(${language.code})', (tester) async {
      usePhoneSize(tester, const Size(360, 740));
      await tester.pumpWidget(_screen(language, textScale: 1.3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('physical direction arrow is not mirrored in Arabic',
      (tester) async {
    usePhoneSize(tester, const Size(412, 915));
    await tester.pumpWidget(_screen(AppLanguage.arabic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // "Right" must point right on screen even though the layout is RTL.
    final arrow = find.byIcon(Icons.arrow_forward);
    expect(arrow, findsOneWidget);
    expect(
      Directionality.of(tester.element(arrow)),
      TextDirection.ltr,
    );
    expect(find.text('يمينًا'), findsOneWidget);
  });
}
