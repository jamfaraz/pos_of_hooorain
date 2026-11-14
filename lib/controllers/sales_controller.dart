import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/order_model.dart';
import '../models/user_model.dart';

enum SalesRange { today, thisWeek, thisMonth, singleDay, custom }

class SalesController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Statuses that are NOT counted in sales, revenue, status chips or the
  /// order list. Add 'rejected' here if you want those excluded too.
  static const Set<String> _excludedStatuses = {'cancelled'};

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<OrderModel> _allOrders = <OrderModel>[].obs;
  final RxList<OrderModel> filteredOrders = <OrderModel>[].obs;

  final Rx<SalesRange> selectedRange = SalesRange.today.obs;
  final Rx<DateTimeRange?> customRange = Rx<DateTimeRange?>(null);
  final Rx<DateTime?> singleDate = Rx<DateTime?>(null);

  final RxDouble totalSales = 0.0.obs;
  final RxInt totalOrders = 0.obs;
  final RxMap<String, int> statusBreakdown = <String, int>{}.obs;
  final RxDouble deliveredRevenue = 0.0.obs;

  /// userId -> UserModel, cached so each customer is fetched once per
  /// session no matter how many of their orders appear in the list.
  final RxMap<String, UserModel?> _customerCache = <String, UserModel?>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      isLoading(true);
      hasError(false);

      final snapshot = await _firestore
          .collection('orders')
          .orderBy('orderDate', descending: true)
          .get();

      _allOrders.assignAll(
        snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList(),
      );

      applyRange(selectedRange.value);
    } catch (e) {
      hasError(true);
      errorMessage.value = e.toString();
    } finally {
      isLoading(false);
    }
  }

  Future<void> refresh() => fetchOrders();

  /// Fetches (and caches) the customer for [userId]. Returns null if the
  /// user doc doesn't exist — callers fall back to order.userName/userPhone.
  Future<UserModel?> getCustomer(String userId) async {
    if (userId.isEmpty) return null;
    if (_customerCache.containsKey(userId)) return _customerCache[userId];

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final user = doc.exists ? UserModel.fromFirestore(doc) : null;
      _customerCache[userId] = user;
      return user;
    } catch (_) {
      _customerCache[userId] = null;
      return null;
    }
  }

  void applyRange(SalesRange range) {
    selectedRange.value = range;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late DateTime start;
    late DateTime end;

    switch (range) {
      case SalesRange.today:
        start = today;
        end = today
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        break;

      case SalesRange.thisWeek:
        // Last 7 days: today + the previous 6 days.
        start = today.subtract(const Duration(days: 6));
        end = today
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        break;

      case SalesRange.thisMonth:
        // Last 30 days: today + the previous 29 days.
        start = today.subtract(const Duration(days: 29));
        end = today
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        break;

      case SalesRange.singleDay:
        final d = singleDate.value ?? now;
        start = DateTime(d.year, d.month, d.day);
        end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        break;

      case SalesRange.custom:
        if (customRange.value == null) {
          start = today;
          end = now;
        } else {
          final r = customRange.value!;
          start = DateTime(r.start.year, r.start.month, r.start.day);
          end = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
        }
        break;
    }

    _computeForRange(start, end);
  }

  /// Show sales for one specific date.
  void setSingleDate(DateTime date) {
    singleDate.value = date;
    applyRange(SalesRange.singleDay);
  }

  /// Human readable label of the active range (shown above the order list).
  String get rangeLabel {
    final f = DateFormat('dd MMM yyyy');
    switch (selectedRange.value) {
      case SalesRange.today:
        return 'Today';
      case SalesRange.thisWeek:
        return 'Last 7 days';
      case SalesRange.thisMonth:
        return 'Last 30 days';
      case SalesRange.singleDay:
        final d = singleDate.value;
        return d == null ? 'Today' : f.format(d);
      case SalesRange.custom:
        final r = customRange.value;
        return r == null ? 'Custom' : '${f.format(r.start)} - ${f.format(r.end)}';
    }
  }

  void setCustomRange(DateTimeRange range) {
    customRange.value = range;
    applyRange(SalesRange.custom);
  }

  bool _isExcluded(OrderModel order) =>
      _excludedStatuses.contains(order.status.trim().toLowerCase());

  void _computeForRange(DateTime start, DateTime end) {
    final results = _allOrders.where((order) {
      final inRange =
          !order.orderDate.isBefore(start) && !order.orderDate.isAfter(end);
      return inRange && !_isExcluded(order);
    }).toList();

    filteredOrders.assignAll(results);

    totalOrders.value = results.length;
    totalSales.value = results.fold<double>(0, (sum, o) => sum + o.total);

    final breakdown = <String, int>{};
    double delivered = 0;
    for (final order in results) {
      breakdown[order.status] = (breakdown[order.status] ?? 0) + 1;
      if (order.status == 'Delivered') delivered += order.total;
    }
    statusBreakdown.assignAll(breakdown);
    deliveredRevenue.value = delivered;
  }
}