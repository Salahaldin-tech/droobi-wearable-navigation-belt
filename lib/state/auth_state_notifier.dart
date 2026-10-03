import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/firebase_auth_service.dart';


final authServiceProvider = Provider<AuthService>((ref) {
  return FirebaseAuthService();
});


final authStateProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges;
});


final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
});
