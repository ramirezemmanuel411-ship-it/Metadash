import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Central authentication service for MetaDash.
///
/// Wraps Firebase Auth and the Google / Apple credential providers. The rest of
/// the app should go through this class rather than touching [FirebaseAuth]
/// directly, so the sign-in surface stays in one place.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// Apple Sign In requires a paid Apple Developer account (Sign in with Apple
  /// capability + a Service ID/key configured in the Firebase console). It is
  /// scaffolded but disabled until that setup is complete — flip this to `true`
  /// once the Apple provider is configured.
  static const bool appleSignInEnabled = false;

  /// Whether the Apple button should be shown on the current platform.
  static bool get appleSignInAvailable =>
      appleSignInEnabled && !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  User? get currentUser => _auth.currentUser;

  /// Emits the current user on every sign-in / sign-out. The app gates its
  /// entry flow on this stream.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // User dismissed the Google chooser.
      throw FirebaseAuthException(
        code: 'sign-in-cancelled',
        message: 'Google sign-in was cancelled.',
      );
    }
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Apple (scaffolded — gated by [appleSignInEnabled])
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithApple() async {
    if (!appleSignInEnabled) {
      throw FirebaseAuthException(
        code: 'apple-disabled',
        message: 'Apple sign-in is not configured yet.',
      );
    }
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);
    final result = await _auth.signInWithCredential(oauthCredential);

    // Apple only returns the name on the first authorization — capture it.
    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    if ((given != null || family != null) &&
        (result.user?.displayName == null ||
            result.user!.displayName!.isEmpty)) {
      final displayName = [given, family].whereType<String>().join(' ').trim();
      if (displayName.isNotEmpty) {
        await result.user?.updateDisplayName(displayName);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Not signed in via Google; ignore.
    }
    await _auth.signOut();
  }

  /// Turns a Firebase auth error into a message safe to show a user.
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists for that email.';
        case 'weak-password':
          return 'Password is too weak — use at least 6 characters.';
        case 'operation-not-allowed':
          return 'This sign-in method isn\'t enabled for the project yet.';
        case 'network-request-failed':
          return 'Network error — check your connection and try again.';
        case 'sign-in-cancelled':
        case 'apple-disabled':
          return error.message ?? 'Sign-in was cancelled.';
        default:
          return error.message ?? 'Authentication failed (${error.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  // ---------------------------------------------------------------------------
  // Nonce helpers (Apple)
  // ---------------------------------------------------------------------------

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
