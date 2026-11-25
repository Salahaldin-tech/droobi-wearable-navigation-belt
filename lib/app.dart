import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/accessible_theme.dart';
import 'l10n/l10n.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home/home_screen.dart';
import 'state/auth_state_notifier.dart';

/// Root widget for the real Droobi app. Watches authStateProvider
/// (existing Stage 6 service) and routes to Sign In or Home - this
/// replaces the Dev Test Menu as the app's default entry point.
class DroobiApp extends ConsumerWidget {
  const DroobiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final appLanguage = ref.watch(appLanguageProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Droobi',
      theme: AccessibleTheme.theme,
      // Arabic (RTL) is the default; English (LTR) is selectable in Settings.
      // The Material/Widgets localizations supply the text direction, so
      // every screen mirrors automatically when the language changes.
      locale: appLanguage.locale,
      supportedLocales: [
        for (final language in AppLanguage.values) language.locale,
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: authState.when(
        data: (user) => user == null ? const SignInScreen() : const HomeScreen(),
        loading: () => const _SplashScreen(),
        error: (error, _) => _AuthErrorScreen(error: error),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.tr(
              'Something went wrong starting the app: $error',
              'حدث خطأ أثناء تشغيل التطبيق: $error',
            ),
          ),
        ),
      ),
    );
  }
}
