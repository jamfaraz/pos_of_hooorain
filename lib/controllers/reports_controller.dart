import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/category_record.dart';
import '../models/order_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';
import '../services/report_export_service.dart';
import '../utils/money.dart';

class ReportsController extends GetxController {
  ReportsController(this._service, this._exporter);

  final ControlRoomService _service;
  final ReportExportService _exporter;
  final products = <ProductRecord>[].obs;
  final categories = <CategoryRecord>[].obs;
  final orders = <OrderRecord>[].obs;
  final loading = true.obs;
  final exporting = false.obs;
  final loadingMore = false.obs;
  final error = RxnString();
  final selectedMonth = DateTime(DateTime.now().year, DateTime.now().month).obs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSub;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _rangeSubscriptions = [];
  DocumentSnapshot<Map<String, dynamic>>? _orderCursor;
  DocumentSnapshot<Map<String, dynamic>>? _billCursor;
  final Map<String, OrderRecord> _loadedOrderMap = {};
  bool _ordersDone = false;
  bool _billsDone = false;

  bool get canLoadMore => !_ordersDone || !_billsDone;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _ordersSub?.cancel();
    _billsSub?.cancel();
    for (final subscription in _rangeSubscriptions) {
      subscription.cancel();
    }
    _rangeSubscriptions.clear();
    loading.value = true;
    error.value = null;
    _loadedOrderMap.clear();
    _orderCursor = null;
    _billCursor = null;
    _ordersDone = false;
    _billsDone = false;
    void updateOrders() {
      orders.assignAll(
        _loadedOrderMap.values.toList()..sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        ),
      );
      loading.value = false;
    }

    _productsSub = _service.watchProducts().listen((snapshot) {
      products.assignAll(
        snapshot.docs.map(
          (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
      loading.value = false;
    }, onError: _handleError);
    _categoriesSub = _service.watchCategories().listen((snapshot) {
      categories.assignAll(
        snapshot.docs.map(
          (doc) => CategoryRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
      loading.value = false;
    }, onError: _handleError);
    final month = selectedMonth.value;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final sources = <(String, String, String)>[
      ('orders', 'orderDate', 'orders-orderDate'),
      ('orders', 'createdAt', 'orders-createdAt'),
      ('bills', 'orderDate', 'bills-orderDate'),
      ('bills', 'createdAt', 'bills-createdAt'),
    ];
    final received = <String>{};
    for (final (collection, field, source) in sources) {
      final subscription = _service
          .watchCollectionRange(collection, field, start, end)
          .listen((snapshot) {
            for (final doc in snapshot.docs) {
              _loadedOrderMap['$collection:${doc.id}'] = OrderRecord.fromMap(
                doc.data(),
                doc.id,
              );
            }
            received.add(source);
            if (received.length == sources.length) updateOrders();
          }, onError: _handleError);
      _rangeSubscriptions.add(subscription);
    }
  }

  void _handleError(Object exception) {
    error.value = exception.toString();
    loading.value = false;
  }

  Future<void> loadMore() async {
    if (!canLoadMore || loadingMore.value) return;
    loadingMore.value = true;
    error.value = null;
    try {
      if (!_ordersDone && _orderCursor != null) {
        final page = await _service.fetchSimplePage(
          'orders',
          after: _orderCursor,
        );
        if (page.docs.isNotEmpty) {
          _orderCursor = page.docs.last;
          for (final doc in page.docs) {
            _loadedOrderMap['orders:${doc.id}'] = OrderRecord.fromMap(
              doc.data(),
              doc.id,
            );
          }
        }
        _ordersDone = page.docs.length < ControlRoomService.pageSize;
      }
      if (!_billsDone && _billCursor != null) {
        final page = await _service.fetchSimplePage(
          'bills',
          after: _billCursor,
        );
        if (page.docs.isNotEmpty) {
          _billCursor = page.docs.last;
          for (final doc in page.docs) {
            _loadedOrderMap['bills:${doc.id}'] = OrderRecord.fromMap(
              doc.data(),
              doc.id,
            );
          }
        }
        _billsDone = page.docs.length < ControlRoomService.pageSize;
      }
      orders.assignAll(
        _loadedOrderMap.values.toList()..sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        ),
      );
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  List<MapEntry<String, double>> get salesByDay {
    final month = selectedMonth.value;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totals = <String, double>{
      for (var day = 1; day <= daysInMonth; day++)
        '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}':
            0,
    };
    for (final order in orders) {
      final date = order.createdAt;
      if (date == null) continue;
      if (date.year != month.year || date.month != month.month) continue;
      final status = order.status.trim().toLowerCase();
      if ({'cancelled', 'canceled', 'rejected', 'returned'}.contains(status)) {
        continue;
      }
      final label =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      totals.update(
        label,
        (value) => value + order.total,
        ifAbsent: () => order.total,
      );
    }
    return totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  double get selectedMonthSales =>
      salesByDay.fold(0.0, (total, entry) => total + entry.value);

  double get selectedMonthAverage {
    final values = salesByDay;
    if (values.isEmpty) return 0;
    return selectedMonthSales / values.length;
  }

  MapEntry<String, double>? get selectedMonthBestDay {
    final values = salesByDay;
    if (values.isEmpty) return null;
    return values.reduce(
      (best, entry) => entry.value > best.value ? entry : best,
    );
  }

  void previousMonth() {
    final month = selectedMonth.value;
    selectedMonth.value = DateTime(month.year, month.month - 1, 1);
    reload();
  }

  void nextMonth() {
    final month = selectedMonth.value;
    final now = DateTime.now();
    final next = DateTime(month.year, month.month + 1, 1);
    if (next.isAfter(DateTime(now.year, now.month, 1))) return;
    selectedMonth.value = next;
    reload();
  }

  List<MapEntry<String, double>> get salesByCategory {
    final productCategory = {
      for (final product in products)
        product.id:
            categories
                .where((category) => category.id == product.categoryId)
                .firstOrNull
                ?.name ??
            'Uncategorized',
    };
    final totals = <String, double>{};
    for (final order in orders) {
      for (final line in order.items) {
        final category = productCategory[line.productId] ?? 'Uncategorized';
        totals.update(
          category,
          (value) => value + line.unitPrice * line.qty,
          ifAbsent: () => line.unitPrice * line.qty,
        );
      }
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Map<String, ({int units, double sales, double profit})>
  get productPerformance {
    final totals = <String, ({int units, double sales, double profit})>{};
    for (final order in orders) {
      for (final line in order.items) {
        final old =
            totals[line.productId] ?? (units: 0, sales: 0.0, profit: 0.0);
        totals[line.productId] = (
          units: old.units + line.qty,
          sales: old.sales + line.unitPrice * line.qty,
          profit: old.profit + (line.unitPrice - line.costAtSale) * line.qty,
        );
      }
    }
    return totals;
  }

  List<ProductRecord> get topProducts {
    final values = products.toList();
    values.sort(
      (a, b) => (productPerformance[b.id]?.units ?? 0).compareTo(
        productPerformance[a.id]?.units ?? 0,
      ),
    );
    return values;
  }

  Future<String?> exportCsv() async {
    exporting.value = true;
    error.value = null;
    try {
      final sections = <String, List<List<String>>>{
        'Daily sales': [
          ['Date', 'Sales'],
          ...salesByDay.map((entry) => [entry.key, Money.rs(entry.value)]),
        ],
      };
      return await _exporter.export(
        'Hoorain sales and profit reports',
        sections,
      );
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    } finally {
      exporting.value = false;
    }
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _ordersSub?.cancel();
    _billsSub?.cancel();
    for (final subscription in _rangeSubscriptions) {
      subscription.cancel();
    }
    super.onClose();
  }
}
