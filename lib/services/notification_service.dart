import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('Notifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchForUser(String userId) =>
      _notifications
          .where('userId', isEqualTo: userId)
          .orderBy('time', descending: true)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUnread(String userId) =>
      _notifications
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots();

  Future<void> markAsRead(String notificationId) =>
      _notifications.doc(notificationId).update({'isRead': true});

  Future<int> markAllAsRead(String userId) async {
    final snapshot = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final documents = snapshot.docs;

    for (var start = 0; start < documents.length; start += 500) {
      final batch = _firestore.batch();
      final end = (start + 500).clamp(0, documents.length);
      for (final document in documents.sublist(start, end)) {
        batch.update(document.reference, {'isRead': true});
      }
      await batch.commit();
    }

    return documents.length;
  }
}
