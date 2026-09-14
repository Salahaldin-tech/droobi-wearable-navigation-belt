import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firebase_auth_service.dart';

/// The single AuthService instance for the app. Everywhere else
/// should depend on [AuthService] (the interface), never on
/// FirebaseAuthService directly.
final authServiceProvider = Provider<AuthService>((ref) {
  return FirebaseAuthService();
});

/// Current auth state: null when signed out, an AppUser when signed
/// in. AsyncValue.loading() while Firebase resolves the initial state.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges;
});

/// Convenience provider for "is a user currently signed in", useful
/// for routing decisions in later UI stages without needing to
/// unwrap AsyncValue<AppUser?> everywhere.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
});
