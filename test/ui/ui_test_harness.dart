import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:droobi/core/enums/belt_connection_state.dart';
import 'package:droobi/core/theme/accessible_theme.dart';
import 'package:droobi/l10n/l10n.dart';
import 'package:droobi/models/app_user.dart';
import 'package:droobi/models/favorite_location.dart';
import 'package:droobi/services/accessibility/feedback_service.dart';
import 'package:droobi/services/voice/voice_input_service.dart';
import 'package:droobi/state/auth_state_notifier.dart';
import 'package:droobi/state/favorites_notifier.dart';
import 'package:droobi/state/voice_command_notifier.dart';
import 'package:droobi/services/ble/belt_connection_service.dart';
import 'package:droobi/services/ble/belt_navigation_bridge.dart';
import 'package:droobi/services/navigation/navigation_service.dart';
import 'package:droobi/state/belt_connection_notifier.dart';
import 'package:droobi/state/navigation_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone sizes (logical pixels) used by the layout tests, from a small
/// 5" Android phone up to a large 6.7" device.
const phoneSizes = <String, Size>{
  'small 320x568': Size(320, 568),
  'compact 360x640': Size(360, 640),
  'medium 360x740': Size(360, 740),
  'galaxy 384x832': Size(384, 832),
  'large 412x915': Size(412, 915),
};

/// Loads the app's real fonts so text is measured as on a device (the
/// default test font draws every glyph as a wide square, which would make
/// horizontal layout checks meaningless). Call from setUpAll.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File(file).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('LyonArabic', ['assets/fonts/lyon-arabic-display-black.otf']);
  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
}

/// Runs [body] while recording every Flutter error (e.g. RenderFlex
/// overflows), then fails with the full details, including the source
/// location of the widget that caused it.
Future<void> expectNoFlutterErrors(Future<void> Function() body) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  if (errors.isNotEmpty) {
    fail(errors.map((e) => e.toString()).join('\n---\n'));
  }
}

/// Sets the test surface to [size] and restores it afterwards.
void usePhoneSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Same MaterialApp configuration as DroobiApp (theme, locale, delegates),
/// without Firebase auth, so individual screens can be pumped in tests.
Widget localizedApp({
  required AppLanguage language,
  required Widget home,
  List<Override> overrides = const [],
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      appLanguageProvider.overrideWith((ref) => AppLanguageNotifier(language)),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final current = ref.watch(appLanguageProvider);
        return MaterialApp(
          theme: AccessibleTheme.theme,
          locale: current.locale,
          supportedLocales: [for (final l in AppLanguage.values) l.locale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Fakes for the navigation / BLE layer. They only feed the UI; the real
// services are never touched by the layout tests.
// ---------------------------------------------------------------------------

class FakeNavigationService implements NavigationService {
  FakeNavigationService(this.snapshot);

  final NavigationSnapshot snapshot;
  final _controller = StreamController<NavigationSnapshot>.broadcast();

  @override
  Stream<NavigationSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> start({
    required destination,
    destinationCandidates,
    bool campusNavigation = false,
  }) async {
    _controller.add(snapshot);
  }

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeBeltService implements BeltConnectionService {
  @override
  Stream<BeltConnectionState> get connectionState =>
      Stream.value(BeltConnectionState.disconnected);

  @override
  BeltConnectionState get currentState => BeltConnectionState.disconnected;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeBeltBridge implements BeltNavigationBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeVoiceInput implements VoiceInputService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeFeedback implements FeedbackService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

final testUser = AppUser(
  uid: 'test-user',
  displayName: 'Test User',
  createdAt: DateTime(2026),
);

/// Overrides for screens that need a signed-in user, favorites, the belt
/// and the voice pipeline. No Firebase, BLE or microphone is touched.
List<Override> appOverrides() => [
      authStateProvider.overrideWith((ref) => Stream.value(testUser)),
      favoritesProvider.overrideWith(
        (ref) => Stream.value(const <FavoriteLocation>[]),
      ),
      beltConnectionServiceProvider.overrideWithValue(FakeBeltService()),
      voiceInputServiceProvider.overrideWithValue(FakeVoiceInput()),
      feedbackServiceProvider.overrideWithValue(FakeFeedback()),
    ];

List<Override> navigationOverrides(NavigationSnapshot snapshot) => [
      navigationServiceProvider
          .overrideWithValue(FakeNavigationService(snapshot)),
      beltConnectionServiceProvider.overrideWithValue(FakeBeltService()),
      beltNavigationBridgeProvider.overrideWithValue(FakeBeltBridge()),
    ];
