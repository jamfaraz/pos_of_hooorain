import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Creates rider login accounts from the admin panel without signing the
/// admin out.
///
/// Firebase signs the current user out when you call
/// createUserWithEmailAndPassword on the default Auth instance. To avoid that,
/// the account is created on a second, separate Firebase app instance and that
/// instance is signed out right afterwards. The admin session is untouched.
class RiderAccountService {
  static const _appName = 'rider-provisioning';

  Future<FirebaseApp> _secondaryApp() async {
    try {
      return Firebase.app(_appName);
    } catch (_) {
      return Firebase.initializeApp(
        name: _appName,
        options: Firebase.app().options,
      );
    }
  }

  /// Creates the Auth user, then runs [onCreated] with the new uid (write the
  /// rider document there). If [onCreated] fails, the Auth user is deleted
  /// again so no orphan login is left behind.
  Future<String> createRiderLogin({
    required String email,
    required String password,
    required Future<void> Function(String uid) onCreated,
  }) async {
    final app = await _secondaryApp();
    final auth = FirebaseAuth.instanceFor(app: app);

    UserCredential credential;
    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw StateError(_message(e));
    }

    final user = credential.user!;
    try {
      await onCreated(user.uid);
      return user.uid;
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {}
      rethrow;
    } finally {
      await auth.signOut();
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw StateError(_message(e));
    }
  }

  String _message(FirebaseAuthException e) => switch (e.code) {
    'email-already-in-use' =>
      'This email already has an account. Use a different email, or send a password reset to the existing rider.',
    'invalid-email' => 'The email address is not valid.',
    'weak-password' => 'Password is too weak. Use at least 6 characters.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled. Turn it on in Firebase Console → Authentication → Sign-in method.',
    'user-not-found' => 'No account exists for this email.',
    'network-request-failed' => 'No internet connection. Please try again.',
    _ => e.message ?? 'Authentication error (${e.code}).',
  };
}
