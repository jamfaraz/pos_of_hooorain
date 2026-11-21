import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_model.dart';
import '../utils/toas_message.dart';

/// Loads one customer (users/{userId}), their orders, and applies
/// verification decisions.
class UserDetailController extends GetxController {
  UserDetailController(this.userId);

  static const verified = 'verified';
  static const notVerified = 'notVerified';
  static const rejected = 'rejected';

  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = true.obs;
  final error = RxnString();
  final user = Rxn<Map<String, dynamic>>();

  final ordersLoading = true.obs;
  final orders = <OrderModel>[].obs;

  /// The status currently being written, or null when idle.
  final updatingStatus = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// [silent] keeps the current page on screen while refreshing.
  Future<void> load({bool silent = false}) async {
    if (!silent || user.value == null) loading.value = true;
    error.value = null;
    try {
      final doc = await _db.collection('users').doc(userId).get();
      user.value = doc.exists ? doc.data() : null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
    if (user.value != null) unawaited(_loadOrders());
  }

  Future<void> _loadOrders() async {
    ordersLoading.value = true;
    try {
      final snap = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      final list = snap.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
      orders.assignAll(list);
    } catch (_) {
      orders.clear();
    } finally {
      ordersLoading.value = false;
    }
  }

  // ------------------------------------------------------------- order stats

  static bool _counts(OrderModel o) {
    final s = o.status.toLowerCase();
    return !(s.contains('cancel') || s.contains('reject') || s.contains('return'));
  }

  /// Orders that were not cancelled, rejected or returned.
  List<OrderModel> get countedOrders => orders.where(_counts).toList();

  double get totalSpent =>
      countedOrders.fold(0.0, (sum, order) => sum + order.total);

  double get averageOrder {
    final counted = countedOrders;
    return counted.isEmpty ? 0 : totalSpent / counted.length;
  }

  OrderModel? get lastOrder => orders.isEmpty ? null : orders.first;

  // ------------------------------------------------------------ verification

  static String labelFor(String status) => switch (status) {
    verified => 'Verified',
    rejected => 'Rejected',
    _ => 'Not verified',
  };

  Future<bool> setStatus(String status) async {
    if (updatingStatus.value != null) return false;
    updatingStatus.value = status;
    try {
      await _db.collection('users').doc(userId).update({
        'profileStatus': status,
        'isVerified': status == verified,
      });
      user.value = {
        ...?user.value,
        'profileStatus': status,
        'isVerified': status == verified,
      };
      MessageToast.showToast(msg: 'Customer marked as ${labelFor(status)}');
      return true;
    } catch (e) {
      Get.snackbar('Could not update status', e.toString());
      return false;
    } finally {
      updatingStatus.value = null;
    }
  }
}