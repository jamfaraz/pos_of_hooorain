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

  /// How many orders are rendered at once. "Load more" adds another page.
  static const int pageSize = 20;

  /// Max days for which the daily trend chart is built.
  static const int _maxChartDays = 62;

  // Initial fetch / refresh from Firestore.
  final RxBool isLoading = true.obs;
  // Recomputing after the user changes the range (shows skeleton loader).
  final RxBool isComputing = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final List<OrderModel> _allOrders = <OrderModel>[];
  final RxList<OrderModel> filteredOrders = <OrderModel>[].obs;

  final Rx<SalesRange> selectedRange = SalesRange.today.obs;
  final Rx<DateTimeRange?> customRange = Rx<DateTimeRange?>(null);
  final Rx<DateTime?> singleDate = Rx<DateTime?>(null);

  final RxDouble totalSales = 0.0.obs;
  final RxInt totalOrders = 0.obs;
  final RxMap<String, int> statusBreakdown = <String, int>{}.obs;
  final RxDouble deliveredRevenue = 0.0.obs;
  final RxDouble averageOrder = 0.0.obs;

  /// Sales per day for the trend chart (empty when range is a single day).
  final RxList<MapEntry<DateTime, double>> dailyTotals =
      <MapEntry<DateTime, double>>[].obs;

  /// Number of orders currently rendered in the list (pagination).
  final RxInt visibleCount = pageSize.obs;

  int _computeToken = 0;

  /// userId -> UserModel, cached so each customer is fetched once per session.
  final Map<String, UserModel?> _customerCache = <String, UserModel?>{};

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

      _allOrders
        ..clear()
        ..addAll(
          snapshot.docs.map((doc) => OrderModel.fromMap(doc.data(), doc.id)),
        );

      final window = _windowFor(selectedRange.value);
      _computeNow(window.$1, window.$2);
    } catch (e) {
      hasError(true);
      errorMessage.value = e.toString();
    } finally {
      isLoading(false);
    }
  }

  Future<void> refresh() => fetchOrders();

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

  (DateTime, DateTime) _windowFor(SalesRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfToday = today
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));

    switch (range) {
      case SalesRange.today:
        return (today, endOfToday);
      case SalesRange.thisWeek:
        return (today.subtract(const Duration(days: 6)), endOfToday);
      case SalesRange.thisMonth:
        return (today.subtract(const Duration(days: 29)), endOfToday);
      case SalesRange.singleDay:
        final d = singleDate.value ?? now;
        final s = DateTime(d.year, d.month, d.day);
        return (
          s,
          s.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)),
        );
      case SalesRange.custom:
        final r = customRange.value;
        if (r == null) return (today, now);
        return (
          DateTime(r.start.year, r.start.month, r.start.day),
          DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59),
        );
    }
  }

  /// Changes the range. Shows the loader first so the UI never looks frozen,
  /// then computes everything in one batch.
  Future<void> applyRange(SalesRange range) async {
    selectedRange.value = range;
    final window = _windowFor(range);
    final token = ++_computeToken;

    isComputing(true);
    // Let Flutter paint the skeleton before the heavy work starts.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (token != _computeToken) return; // a newer request replaced this one

    _computeNow(window.$1, window.$2);
    isComputing(false);
  }

  void setSingleDate(DateTime date) {
    singleDate.value = date;
    applyRange(SalesRange.singleDay);
  }

  void setCustomRange(DateTimeRange range) {
    customRange.value = range;
    applyRange(SalesRange.custom);
  }

  void loadMore() {
    visibleCount.value =
        (visibleCount.value + pageSize).clamp(0, filteredOrders.length);
  }

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
        return r == null
            ? 'Custom'
            : '${f.format(r.start)} - ${f.format(r.end)}';
    }
  }

  bool _isExcluded(OrderModel order) =>
      _excludedStatuses.contains(order.status.trim().toLowerCase());

  /// Single pass over the orders; all observables are updated together so the
  /// UI rebuilds once instead of many times.
  void _computeNow(DateTime start, DateTime end) {
    final results = <OrderModel>[];
    final breakdown = <String, int>{};
    final byDay = <DateTime, double>{};
    double total = 0;
    double delivered = 0;

    for (final order in _allOrders) {
      final d = order.orderDate;
      if (d.isBefore(start) || d.isAfter(end) || _isExcluded(order)) continue;
      results.add(order);
      total += order.total;
      breakdown[order.status] = (breakdown[order.status] ?? 0) + 1;
      if (order.status == 'Delivered') delivered += order.total;
      final day = DateTime(d.year, d.month, d.day);
      byDay[day] = (byDay[day] ?? 0) + order.total;
    }

    // Trend chart buckets (zero-filled so gaps are visible).
    final days = end.difference(start).inDays + 1;
    final chart = <MapEntry<DateTime, double>>[];
    if (days > 1 && days <= _maxChartDays) {
      final first = DateTime(start.year, start.month, start.day);
      for (var i = 0; i < days; i++) {
        final day = DateTime(first.year, first.month, first.day + i);
        chart.add(MapEntry(day, byDay[day] ?? 0));
      }
    }

    // Batch update (one rebuild burst, no per-row work).
    filteredOrders.assignAll(results);
    statusBreakdown.assignAll(breakdown);
    dailyTotals.assignAll(chart);
    totalOrders.value = results.length;
    totalSales.value = total;
    deliveredRevenue.value = delivered;
    averageOrder.value = results.isEmpty ? 0 : total / results.length;
    visibleCount.value = pageSize;
  }
}