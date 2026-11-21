import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';
import '../services/inventory_service.dart';
import '../utils/dashboard_metrics.dart' as dashboard_metrics;

class DashboardController extends GetxController {
  DashboardController(this._service);

  final ControlRoomService _service;
  final orders = <OrderRecord>[].obs;
  final pendingOrders = <OrderRecord>[].obs;
  final products = <ProductRecord>[].obs;
  final loadingOrders = true.obs;
  final loadingProducts = true.obs;
  final error = RxnString();
  final topSellerPeriodDays = 7.obs;

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _orderSubscriptions = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;
  final Map<String, Map<String, OrderRecord>> _orderSources = {};

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    for (final subscription in _orderSubscriptions) {
      subscription.cancel();
    }
    _orderSubscriptions.clear();
    _productsSub?.cancel();
    _pendingSub?.cancel();
    _orderSources.clear();
    orders.clear();
    pendingOrders.clear();
    loadingOrders.value = true;
    loadingProducts.value = true;
    error.value = null;

    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    const sources = <(String, String, String)>[
      ('orders', 'orderDate', 'orders-orderDate'),
      ('orders', 'createdAt', 'orders-createdAt'),
      ('bills', 'orderDate', 'bills-orderDate'),
      ('bills', 'createdAt', 'bills-createdAt'),
    ];
    for (final (collection, field, source) in sources) {
      _orderSubscriptions.add(
        _service
            .watchCollectionSince(collection, field, start)
            .listen(
              (snapshot) {
                _orderSources[source] = {
                  for (final doc in snapshot.docs)
                    doc.id: OrderRecord.fromMap(doc.data(), doc.id),
                };
                _updateOrders();
                if (_orderSources.length == sources.length) {
                  loadingOrders.value = false;
                }
              },
              onError: (Object exception) {
                error.value = exception.toString();
                loadingOrders.value = false;
              },
            ),
      );
    }

    _pendingSub = _service
        .watchOrdersByStatus('Pending')
        .listen(
          (snapshot) {
            pendingOrders.assignAll(
              snapshot.docs.map(
                (doc) => OrderRecord.fromMap(doc.data(), doc.id),
              ),
            );
            pendingOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
          },
          onError: (Object exception) {
            error.value = exception.toString();
          },
        );

    _productsSub = _service.watchAllProducts().listen(
      (snapshot) {
        products.assignAll(
          snapshot.docs.map(
            (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        loadingProducts.value = false;
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loadingProducts.value = false;
      },
    );
  }

  void _updateOrders() {
    final combined = <String, OrderRecord>{};
    for (final source in _orderSources.entries) {
      final collection = source.key.startsWith('bills-') ? 'bills' : 'orders';
      for (final order in source.value.values) {
        combined['$collection:${order.id}'] = order;
      }
    }
    orders.assignAll(
      combined.values.toList()
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate)),
    );
  }

  List<OrderRecord> get todayOrders {
    final now = DateTime.now();
    return orders.where((order) {
      final date = order.orderDate;
      return dashboard_metrics.countsAsDashboardSale(order) &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  double get todaySales =>
      todayOrders.fold(0.0, (total, order) => total + order.total);

  double get todayCostedSales => todayOrders.fold(
    0.0,
    (total, order) => total + dashboard_metrics.knownCostSales(order),
  );

  double get todayProfit => todayOrders.fold(
    0.0,
    (total, order) => total + dashboard_metrics.knownCostProfit(order),
  );

  double get inventoryStockValue => InventoryService.stockValue(products);

  List<ProductRecord> get lowStock =>
      products
          .where(
            (product) =>
                product.reorderLevel > 0 &&
                product.stock <= product.reorderLevel,
          )
          .toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));

  List<double> get weeklySales => List.generate(7, (index) {
    final day = DateTime.now().subtract(Duration(days: 6 - index));
    return _ordersForDay(day).fold(0.0, (total, order) => total + order.total);
  });

  List<double> get weeklyProfit => List.generate(7, (index) {
    final day = DateTime.now().subtract(Duration(days: 6 - index));
    return _ordersForDay(day).fold(
      0.0,
      (total, order) => total + dashboard_metrics.knownCostProfit(order),
    );
  });

  List<OrderRecord> _ordersForDay(DateTime day) => orders.where((order) {
    final date = order.orderDate;
    return dashboard_metrics.countsAsDashboardSale(order) &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }).toList();

  List<dashboard_metrics.DashboardTopSeller> topSellingItems({int? days}) =>
      dashboard_metrics.topSellingItems(
        orders,
        now: DateTime.now(),
        days: days ?? topSellerPeriodDays.value,
      );

  void setTopSellerPeriod(int days) {
    if (days == 1 || days == 7 || days == 30) {
      topSellerPeriodDays.value = days;
    }
  }

  @override
  void onClose() {
    for (final subscription in _orderSubscriptions) {
      subscription.cancel();
    }
    _productsSub?.cancel();
    _pendingSub?.cancel();
    super.onClose();
  }
}
