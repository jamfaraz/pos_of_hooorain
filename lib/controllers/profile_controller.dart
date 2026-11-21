import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../services/admin_access_service.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class ProfileController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RxBool isLoading = false.obs;
  RxString errorMessage = ''.obs;

  // User data
  RxString adminNumber = ''.obs;
  RxString email = ''.obs;
  RxString fcmToken = ''.obs;
  RxString image = ''.obs;
  RxString adminName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserData();
  }

  void fetchUserData() async {
    try {
      isLoading.value = true;
      final userId = FirebaseAuth
          .instance
          .currentUser!
          .uid; // Replace with actual current user ID
      final userDoc = await _firestore.collection('admin').doc(userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        adminNumber.value = data['phoneNumber'] ?? '';
        email.value = data['email'] ?? '';
        fcmToken.value = data['fcmToken'] ?? '';
        image.value = data['image'] ?? '';
        adminName.value = data['fullName'] ?? '';
      } else {
        errorMessage.value = 'Admin not found.';
      }
    } catch (e) {
      errorMessage.value = 'Failed to load admin data: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logOut() async {
    try {
      await Get.find<AdminAccessService>().logout();
      Get.offAllNamed('/login');
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to log out. Please try again.',
        title: 'Error',
      );
    }
  }
}
