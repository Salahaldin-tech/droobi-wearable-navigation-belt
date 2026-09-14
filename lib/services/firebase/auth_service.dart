import '../../models/app_user.dart';

/// Accessible, user-facing auth error categories.
///
/// Kept as an enum (not raw Firebase exception objects) so the UI
/// layer and future FeedbackService can map each case to a plain,
/// screen-reader/TTS-friendly message without depending on Firebase
/// error codes directly.
enum AuthErrorType {
  invalidEmail,
  emailAlreadyInUse,
  weakPassword,
  wrongCredentials,
  networkError,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.type, this.message);

  final AuthErrorType type;

  /// Plain-language message, safe to show on screen or speak via TTS.
  final String message;

  @override
  String toString() => message;
}

/// Abstract interface for authentication + the minimal required user
/// record. The rest of the app depends only on this interface, never
/// on the Firebase SDK directly - consistent with the "interfaces
/// over concrete implementations" rule from the architecture.
abstract class AuthService {
  /// Emits the current signed-in user (or null when signed out)
  /// whenever auth state changes.
  Stream<AppUser?> get authStateChanges;

  /// Synchronous snapshot of the current user, if any.
  AppUser? get currentUser;

  /// Creates a new account and the corresponding minimal
  /// users/{uid} Firestore document.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
