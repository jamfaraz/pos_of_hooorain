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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSub;
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
    _ordersSub = _service.watchRecentOrders().listen((snapshot) {
      for (final doc in snapshot.docs) {
        _loadedOrderMap['orders:${doc.id}'] = OrderRecord.fromMap(
          doc.data(),
          doc.id,
        );
      }
      if (_orderCursor == null && snapshot.docs.isNotEmpty) {
        _orderCursor = snapshot.docs.last;
      }
      _ordersDone = snapshot.docs.length < ControlRoomService.pageSize;
      updateOrders();
    }, onError: _handleError);
    _billsSub = _service.watchRecentBills().listen((snapshot) {
      for (final doc in snapshot.docs) {
        _loadedOrderMap['bills:${doc.id}'] = OrderRecord.fromMap(
          doc.data(),
          doc.id,
        );
      }
      if (_billCursor == null && snapshot.docs.isNotEmpty) {
        _billCursor = snapshot.docs.last;
      }
      _billsDone = snapshot.docs.length < ControlRoomService.pageSize;
      updateOrders();
    }, onError: _handleError);
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
    final totals = <String, double>{};
    for (final order in orders) {
      final date = order.createdAt;
      if (date == null) continue;
      final label =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      totals.update(
        label,
        (value) => value + order.total,
        ifAbsent: () => order.total,
      );
    }
    return totals.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
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
        'Sales by day': [
          ['Date', 'Sales'],
          ...salesByDay.map((entry) => [entry.key, Money.rs(entry.value)]),
        ],
        'Sales by category': [
          ['Category', 'Sales'],
          ...salesByCategory.map((entry) => [entry.key, Money.rs(entry.value)]),
        ],
        'Top products and profit': [
          ['Product', 'Units', 'Sales', 'Profit'],
          ...topProducts.map((product) {
            final stats = productPerformance[product.id];
            return [
              product.name,
              '${stats?.units ?? 0}',
              Money.rs(stats?.sales ?? 0),
              Money.rs(stats?.profit ?? 0),
            ];
          }),
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
    super.onClose();
  }
}
