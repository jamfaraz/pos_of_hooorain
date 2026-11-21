import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class AdminAccessService extends GetxService {
  AdminAccessService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<User?>? _authSubscription;
  String? _verifiedUid;
  int _verificationVersion = 0;

  final isChecking = true.obs;
  final isAdmin = false.obs;
  final error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _authSubscription = _auth.authStateChanges().listen(
      (user) => unawaited(_verifyUser(user)),
      onError: (Object exception) {
        isAdmin.value = false;
        error.value = exception.toString();
        isChecking.value = false;
      },
    );
  }

  Future<void> retry() async {
    _verifiedUid = null;
    await _verifyUser(_auth.currentUser);
  }

  Future<void> logout() async {
    Object? notificationCleanupError;
    try {
      final user = _auth.currentUser;
      final token = await FirebaseMessaging.instance.getToken();
      if (user != null && token != null) {
        await _firestore.collection('admin').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (exception) {
      notificationCleanupError = exception;
    }

    await _auth.signOut();
    if (notificationCleanupError != null) {
      MessageToast.showSuccess(
        msg: 'Could not clear this device’s notification token.',
        title: 'Signed out',
      );
    }
  }

  Future<void> _verifyUser(User? user) async {
    if (user == null) {
      _verifiedUid = null;
      _verificationVersion++;
      isAdmin.value = false;
      error.value = '';
      isChecking.value = false;
      return;
    }
    if (_verifiedUid == user.uid) return;

    _verifiedUid = user.uid;
    final version = ++_verificationVersion;
    isChecking.value = true;
    isAdmin.value = false;
    error.value = '';
    try {
      final admin = await _firestore.collection('admin').doc(user.uid).get();
      if (version != _verificationVersion) return;
      if (!admin.exists) {
        await _auth.signOut();
        return;
      }
      isAdmin.value = true;
    } catch (exception) {
      if (version == _verificationVersion) {
        error.value = exception.toString();
      }
    } finally {
      if (version == _verificationVersion) {
        isChecking.value = false;
      }
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }
}
