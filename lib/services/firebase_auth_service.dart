import 'package:firebase_auth/firebase_auth.dart';

/// Minimal Firebase Auth helper. Uses anonymous sign-in for demo/cloud writes.
class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sign in anonymously (used when no explicit login flow configured).
  Future<User?> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user;
    } catch (e) {
      return null;
    }
  }

  /// Sign in with email and password. Returns user on success, null on failure.
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      // Propagate FirebaseAuthException for caller to handle specific codes
      throw e;
    } catch (_) {
      return null;
    }
  }

  /// Register with email/password. Returns user on success, throws on error.
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (_) {
      return null;
    }
  }

  /// Current user id or null.
  String? get currentUserId => _auth.currentUser?.uid;

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  /// Check session presence.
  Future<bool> verifySession() async => _auth.currentUser != null;
}
