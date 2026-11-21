import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../services/admin_access_service.dart';
import '../utils/toas_message.dart';

class LoginController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  // Forgot password
  Future<void> forgotPassword(String email) async {
    // try {
    //   isLoading.value = true;
    //   await _auth.sendPasswordResetEmail(email: email);
    //   MessageToast.showSuccess(
    //     msg: 'Password reset email sent. Check your inbox.',
    //     title: 'Success',
    //   );
    //   Get.toNamed('/login');
    // } on FirebaseAuthException catch (e) {
    //   _handleAuthError(e);
    // } catch (e) {
    //   MessageToast.showError(
    //     msg: 'Something went wrong. Please try again.',
    //     title: 'Error',
    //   );
    // } finally {
    //   isLoading.value = false;
    // }
  }

  // Handle Firebase Auth errors
  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = 'Something went wrong. Please try again.';
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = 'Email is already in use.';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email address.';
        break;
      case 'weak-password':
        errorMessage = 'Password is too weak.';
        break;
      case 'user-not-found':
        errorMessage = 'User not found.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many requests. Try again later.';
        break;
    }
    MessageToast.showError(msg: errorMessage, title: 'Error');
  }

  Future<void> loginAdmin({
    required String email,
    required String password,
  }) async {
    // Check for empty fields
    if (email.isEmpty || password.isEmpty) {
      MessageToast.showToast(msg: "Please fill in all the fields!");
      return;
    }

    isLoading.value = true; // Start loading
    try {
      // Sign in with email and password
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final access = Get.find<AdminAccessService>();
      await access.retry();
      if (!access.isAdmin.value) {
        MessageToast.showToast(
          msg: access.error.value.isNotEmpty
              ? 'Could not verify admin access. Please retry.'
              : 'This account does not have admin access.',
        );
        return;
      }
      Get.offAllNamed('/dashboard');

      // Show success message
      MessageToast.showToast(msg: "Login successful!");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        MessageToast.showToast(msg: "Admin not found!");
      } else if (e.code == 'wrong-password') {
        MessageToast.showToast(msg: "Incorrect password!");
      } else {
        _handleAuthError(e);
      }
    } catch (e) {
      MessageToast.showToast(msg: "An unexpected error occurred!");
    } finally {
      isLoading.value = false; // Stop loading
    }
  }
}
