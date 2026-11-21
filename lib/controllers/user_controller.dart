import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class UsersController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  var users = [].obs;
  var bannedUsers = [].obs;
  var activeUsers = [].obs;
  var verifiedUsers = [].obs;
  var unverifiedUsers = [].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  final searchQuery = ''.obs;

  // Single user observable
  var selectedUser = Rxn<UserModel>();
  var isUserLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    isLoading(true);
    errorMessage('');
    try {
      final querySnapshot = await _firestore.collection('users').get();
      users.value = querySnapshot.docs;

      // Filter users by different categories
      bannedUsers.value = users
          .where((user) => user['isBanned'] == true)
          .toList();
      activeUsers.value = users
          .where((user) => user['isBanned'] == false)
          .toList();
      verifiedUsers.value = users
          .where((user) => user['isVerified'] == true)
          .toList();
      unverifiedUsers.value = users
          .where((user) => user['isVerified'] == false)
          .toList();
    } catch (e) {
      errorMessage('Failed to load users: $e');
      print(e);
    } finally {
      isLoading(false);
    }
  }

  // ✅ NEW: Fetch a single user by ID
  Future<UserModel?> fetchUserById(String userId) async {
    if (userId.isEmpty) {
      errorMessage.value = 'User ID is empty';
      return null;
    }

    try {
      isUserLoading.value = true;
      errorMessage.value = '';

      // First try: Fetch by document ID
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final user = UserModel.fromFirestore(docSnapshot);
        selectedUser.value = user;
        return user;
      }

      // Second try: Fetch by userId field
      final querySnapshot = await _firestore
          .collection('users')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final user = UserModel.fromFirestore(querySnapshot.docs.first);
        selectedUser.value = user;
        return user;
      }

      // Third try: Fetch by uniqueId field
      final uniqueIdQuery = await _firestore
          .collection('users')
          .where('uniqueId', isEqualTo: userId)
          .limit(1)
          .get();

      if (uniqueIdQuery.docs.isNotEmpty) {
        final user = UserModel.fromFirestore(uniqueIdQuery.docs.first);
        selectedUser.value = user;
        return user;
      }

      // User not found
      errorMessage.value = 'User not found with ID: $userId';
      selectedUser.value = null;
      return null;
    } catch (e) {
      errorMessage.value = 'Error fetching user: ${e.toString()}';
      selectedUser.value = null;
      print('Error fetching user by ID: $e');
      return null;
    } finally {
      isUserLoading.value = false;
    }
  }

  Future<void> toggleBanStatus(String userId, bool isBanned) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': !isBanned,
      });
      fetchUsers();
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to update ban status: $e',
        title: 'Error',
      );
    }
  }

  Future<void> toggleVerificationStatus(String userId, bool isVerified) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isVerified': !isVerified,
      });
      fetchUsers();
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to update verification status: $e',
        title: 'Error',
      );
    }
  }

  Future<void> updateShopRequestStatus(String userId, String status) async {
    try {
      final updates = <String, dynamic>{'shopRequestStatus': status};
      if (status.toLowerCase() == 'approved') {
        updates['userType'] = 'shop';
      }
      await _firestore.collection('users').doc(userId).update(updates);
      await fetchUsers();
    } catch (e) {
      MessageToast.showError(
        msg: 'Failed to update shop request: $e',
        title: 'Error',
      );
    }
  }
}
