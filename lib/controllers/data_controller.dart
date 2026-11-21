import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

class DataController extends GetxController {
  FirebaseAuth auth = FirebaseAuth.instance;
  var isMessageSending = false.obs;
  var hasNewNotification = false.obs;

  @override
  void onInit() {
    super.onInit();
    listenForNotifications();
  }

  void listenForNotifications() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userId = user.uid;

      FirebaseFirestore.instance
          .collection('Notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
            hasNewNotification.value = snapshot.docs.isNotEmpty;
          });
    }
  }

  void markNotificationsAsRead() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String userId = user.uid;

      var notifications = await FirebaseFirestore.instance
          .collection('Notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }
      hasNewNotification.value = false;
    }
  }

  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatRoomId).update(
      {'unreadCount_$userId': 0},
    );
  }

  Stream<QuerySnapshot> getNotification(String uuidToRetrieve) {
    return FirebaseFirestore.instance
        .collection('Notifications')
        .where('userId', isEqualTo: uuidToRetrieve)
        .orderBy('time', descending: true)
        .snapshots();
  }

  Future<void> createNotification({
    required String message,
    required String userId,
    required String orderId,
    required bool isChat,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var uuid = const Uuid();
      var myId = uuid.v6();

      try {
        await FirebaseFirestore.instance
            .collection('Notifications')
            .doc(myId)
            .set({
              'notificationUid': myId,
              'currentUserId': FirebaseAuth.instance.currentUser!.uid,
              'message': message,
              'userId': userId,
              'orderId': orderId,
              'time': DateTime.now(),
              'isChat': isChat,
              'isRead': false,
            });
      } catch (e) {
        if (kDebugMode) {
          print("Error: ${e.toString()}");
        }
      }
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(id)
          .delete()
          .then((value) {});
    } catch (e) {
      print(e);
    }
  }
}
