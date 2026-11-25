import 'package:droobi/l10n/l10n.dart';
import 'package:droobi/screens/auth/sign_in_screen.dart';
import 'package:droobi/screens/auth/sign_up_screen.dart';
import 'package:droobi/screens/destination/destination_search_screen.dart';
import 'package:droobi/screens/favorites/favorites_screen.dart';
import 'package:droobi/screens/home/AboutUsScreen.dart';
import 'package:droobi/screens/home/home_screen.dart';
import 'package:droobi/screens/settings/settings_screen.dart';
import 'package:droobi/screens/university/university_locations_screen.dart';
import 'package:droobi/widgets/droobi_bottom_nav.dart';
import 'package:droobi/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui_test_harness.dart';

const _welcomeDone = {'droobi_welcome_completed_v1': true};

Future<void> _settle(WidgetTester tester) async {
  // Several screens run repeating background animations, so pump fixed
  // durations instead of pumpAndSettle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

TextDirection _directionOf(WidgetTester tester, Finder finder) =>
    Directionality.of(tester.element(finder));

void main() {
  setUpAll(loadAppFonts);

  group('Language persistence', () {
    test('fresh install defaults to Arabic', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppLanguageStore.load(), AppLanguage.arabic);
    });

    test('English choice survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = AppLanguageNotifier(await AppLanguageStore.load());
      await notifier.setLanguage(AppLanguage.english);

      // A "restart" reads the value back from storage.
      expect(await AppLanguageStore.load(), AppLanguage.english);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppLanguageStore.preferencesKey), 'en');
    });

    test('Arabic choice survives a restart', () async {
      SharedPreferences.setMockInitialValues(
        {AppLanguageStore.preferencesKey: 'en'},
      );
      final notifier = AppLanguageNotifier(await AppLanguageStore.load());
      expect(notifier.state, AppLanguage.english);
      await notifier.setLanguage(AppLanguage.arabic);
      expect(await AppLanguageStore.load(), AppLanguage.arabic);
    });
  });

  group('Settings language switch', () {
    testWidgets('switches the whole UI and direction immediately',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      usePhoneSize(tester, const Size(384, 832));
      await tester.pumpWidget(localizedApp(
        language: AppLanguage.arabic,
        overrides: appOverrides(),
        home: const SettingsScreen(),
      ));
      await _settle(tester);

      // Arabic, RTL by default.
      expect(find.text('الإعدادات'), findsWidgets);
      expect(find.text('لغة التطبيق'), findsOneWidget);
      expect(
        _directionOf(tester, find.text('لغة التطبيق')),
        TextDirection.rtl,
      );

      await tester.tap(find.text('English'));
      await _settle(tester);

      // English, LTR, and persisted.
      expect(find.text('APP LANGUAGE'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('الإعدادات'), findsNothing);
      expect(
        _directionOf(tester, find.text('APP LANGUAGE')),
        TextDirection.ltr,
      );
      expect(await AppLanguageStore.load(), AppLanguage.english);

      await tester.tap(find.text('العربية'));
      await _settle(tester);
      expect(find.text('لغة التطبيق'), findsOneWidget);
      expect(await AppLanguageStore.load(), AppLanguage.arabic);
    });
  });

  group('Bottom navigation', () {
    for (final language in AppLanguage.values) {
      testWidgets('keeps its original order in ${language.code}',
          (tester) async {
        SharedPreferences.setMockInitialValues(_welcomeDone);
        usePhoneSize(tester, const Size(384, 832));
        await tester.pumpWidget(localizedApp(
          language: language,
          overrides: appOverrides(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DroobiBottomNav(currentItem: DroobiNavItem.home),
            ),
          ),
        ));
        await _settle(tester);

        final labels = language == AppLanguage.arabic
            ? ['الرئيسية', 'المفضلة', 'الجامعة', 'الإعدادات']
            : ['Home', 'Favorites', 'University', 'Settings'];
        final xs = [
          for (final label in labels) tester.getCenter(find.text(label)).dx,
        ];
        // Home is always the left-most item, Settings the right-most.
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i], greaterThan(xs[i - 1]),
              reason: '${labels[i]} must stay right of ${labels[i - 1]}');
        }

        // On regular-width phones the bar keeps its original natural-size
        // layout: no shared-width items and no scaled-down labels.
        final bar = find.byType(DroobiBottomNav);
        expect(find.descendant(of: bar, matching: find.byType(Flexible)),
            findsNothing);
        expect(find.descendant(of: bar, matching: find.byType(FittedBox)),
            findsNothing);
      });
    }
  });

  group('Page headers', () {
    final screens = <String, Widget Function()>{
      'Home': () => const HomeScreen(),
      'Settings': () => const SettingsScreen(),
      'University': () => const UniversityLocationsScreen(),
      'Favorites': () => const FavoritesScreen(),
      'Destination search': () => const DestinationSearchScreen(),
      'Sign in': () => const SignInScreen(),
      'Sign up': () => const SignUpScreen(),
      'About us': () => const AboutUsScreen(),
    };

    for (final language in AppLanguage.values) {
      testWidgets('share one style, height and inset · ${language.code}',
          (tester) async {
        TextStyle? firstStyle;
        double? firstCenterY;
        for (final screen in screens.entries) {
          SharedPreferences.setMockInitialValues(_welcomeDone);
          usePhoneSize(tester, const Size(384, 832));
          await tester.pumpWidget(localizedApp(
            language: language,
            overrides: appOverrides(),
            home: screen.value(),
          ));
          await _settle(tester);

          final titleFinder = find.descendant(
            of: find.byType(PageTitle),
            matching: find.byType(Text),
          );
          expect(titleFinder, findsOneWidget, reason: screen.key);
          final text = tester.widget<Text>(titleFinder);
          final rect = tester.getRect(titleFinder);
          final style = text.style!;
          expect(style.fontFamily, 'LyonArabic', reason: screen.key);
          firstStyle ??= style;
          expect(style.fontSize, firstStyle.fontSize, reason: screen.key);
          expect(style.fontWeight, firstStyle.fontWeight, reason: screen.key);

          // Same vertical position (one-line titles) ...
          if (rect.height < style.fontSize! * 2) {
            firstCenterY ??= rect.center.dy;
            expect(rect.center.dy, closeTo(firstCenterY, 1),
                reason: screen.key);
          }
          // ... and the same 24px inset from the leading edge.
          final inset = language == AppLanguage.arabic
              ? 384 - rect.right
              : rect.left;
          expect(inset, closeTo(24, 1), reason: screen.key);
        }
      });
    }

    testWidgets('University no longer shows the campus-guide label',
        (tester) async {
      for (final language in AppLanguage.values) {
        SharedPreferences.setMockInitialValues(_welcomeDone);
        usePhoneSize(tester, const Size(384, 832));
        await tester.pumpWidget(localizedApp(
          language: language,
          overrides: appOverrides(),
          home: const UniversityLocationsScreen(),
        ));
        await _settle(tester);
        expect(find.text('دليل الحرم الجامعي'), findsNothing);
        expect(find.text('CAMPUS GUIDE'), findsNothing);
      }
    });
  });

  group('Screens render without overflow', () {
    final screens = <String, Widget Function()>{
      'Home': () => const HomeScreen(),
      'Settings': () => const SettingsScreen(),
      'University': () => const UniversityLocationsScreen(),
      'Favorites': () => const FavoritesScreen(),
      'Destination search': () => const DestinationSearchScreen(),
      'Sign in': () => const SignInScreen(),
      'Sign up': () => const SignUpScreen(),
      'About us': () => const AboutUsScreen(),
    };

    for (final language in AppLanguage.values) {
      for (final screen in screens.entries) {
        for (final size in phoneSizes.entries) {
          testWidgets('${screen.key} · ${size.key} · ${language.code}',
              (tester) async {
            SharedPreferences.setMockInitialValues(_welcomeDone);
            usePhoneSize(tester, size.value);
            await expectNoFlutterErrors(() async {
              await tester.pumpWidget(localizedApp(
                language: language,
                overrides: appOverrides(),
                home: screen.value(),
              ));
              await _settle(tester);
            });
            expect(
              Directionality.of(tester.element(find.byType(Scaffold).first)),
              language.textDirection,
            );
          });
        }
      }
    }

    for (final language in AppLanguage.values) {
      testWidgets('Home welcome dialog · ${language.code}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        usePhoneSize(tester, const Size(360, 640));
        await expectNoFlutterErrors(() async {
          await tester.pumpWidget(localizedApp(
            language: language,
            overrides: appOverrides(),
            home: const HomeScreen(),
          ));
          await _settle(tester);
        });
        expect(
          find.text(language == AppLanguage.arabic
              ? 'مرحبًا بك في دروبي!'
              : 'Welcome to Droobi!'),
          findsOneWidget,
        );
      });
    }
  });
}
