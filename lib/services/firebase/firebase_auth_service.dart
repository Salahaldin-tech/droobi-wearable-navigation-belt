import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../models/app_user.dart';
import 'auth_service.dart';

/// Concrete AuthService implementation using Firebase Auth + Firestore.
///
/// This is the only file that imports the Firebase Auth/Firestore
/// packages directly. Everything else in the app depends on
/// [AuthService], keeping the underlying provider swappable.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Best-effort synchronous fallback using Auth data only; the
    // authoritative record (with createdAt) comes from Firestore via
    // authStateChanges/the fetch in signIn/signUp.
    return AppUser(
      uid: user.uid,
      displayName: user.displayName ?? '',
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _fetchUserDocument(user.uid, fallbackDisplayName: user.displayName ?? '');
    });
  }

  Future<AppUser> _fetchUserDocument(
    String uid, {
    required String fallbackDisplayName,
  }) async {
    final snapshot = await _userDoc(uid).get();
    if (snapshot.exists && snapshot.data() != null) {
      return AppUser.fromFirestore(uid, snapshot.data()!);
    }
    // Defensive fallback: if the Firestore doc is somehow missing
    // (e.g. it was never created), don't crash auth state - surface
    // a minimal user rather than blocking sign-in.
    return AppUser(
      uid: uid,
      displayName: fallbackDisplayName,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      await credential.user!.updateDisplayName(displayName);

      final userData = {
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _userDoc(uid).set(userData);

      // Re-fetch so we return the server-resolved createdAt timestamp
      // rather than a client-side guess.
      return _fetchUserDocument(uid, fallbackDisplayName: displayName);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      return _fetchUserDocument(
        uid,
        fallbackDisplayName: credential.user!.displayName ?? '',
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Maps Firebase's error codes to accessible, plain-language
  /// failures. Kept centralized here so no raw Firebase exception
  /// ever reaches the UI or FeedbackService layers.
  AuthFailure _mapAuthException(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const AuthFailure(
          AuthErrorType.invalidEmail,
          'That email address doesn\'t look valid. Please check and try again.',
        );
      case 'email-already-in-use':
        return const AuthFailure(
          AuthErrorType.emailAlreadyInUse,
          'An account already exists with that email. Try signing in instead.',
        );
      case 'weak-password':
        return const AuthFailure(
          AuthErrorType.weakPassword,
          'That password is too weak. Please choose a stronger password.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFailure(
          AuthErrorType.wrongCredentials,
          'Email or password is incorrect. Please try again.',
        );
      case 'network-request-failed':
        return const AuthFailure(
          AuthErrorType.networkError,
          'Network error. Please check your connection and try again.',
        );
      default:
        return const AuthFailure(
          AuthErrorType.unknown,
          'Something went wrong. Please try again.',
        );
    }
  }
}
