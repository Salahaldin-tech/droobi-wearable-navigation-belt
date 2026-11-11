import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/accessible_theme.dart';
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Droobi',
      theme: AccessibleTheme.theme,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9F2E0),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 132,
              height: 132,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            const Text(
              'Droobi',
              style: TextStyle(
                color: Color(0xFF896E5F),
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF896E5F),
              ),
            ),
          ],
        ),
      ),
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
          child: Text('Something went wrong starting the app: $error'),
        ),
      ),
    );
  }
}
