import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';

class DashboardController extends GetxController {
  DashboardController(this._service);

  final ControlRoomService _service;
  final orders = <OrderRecord>[].obs;
  final products = <ProductRecord>[].obs;
  final loadingOrders = true.obs;
  final loadingProducts = true.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    _ordersSub?.cancel();
    _billsSub?.cancel();
    _productsSub?.cancel();
    loadingOrders.value = true;
    loadingProducts.value = true;
    error.value = null;
    final orderDocs = <String, OrderRecord>{};
    void updateOrders() {
      orders.assignAll(
        orderDocs.values.toList()..sort(
          (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
            a.createdAt ?? DateTime(2000),
          ),
        ),
      );
      loadingOrders.value = false;
    }

    _ordersSub = _service.watchRecentOrders().listen(
      (snapshot) {
        for (final doc in snapshot.docs) {
          orderDocs[doc.id] = OrderRecord.fromMap(doc.data(), doc.id);
        }
        updateOrders();
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loadingOrders.value = false;
      },
    );
    _billsSub = _service.watchRecentBills().listen(
      (snapshot) {
        for (final doc in snapshot.docs) {
          orderDocs[doc.id] = OrderRecord.fromMap(doc.data(), doc.id);
        }
        updateOrders();
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loadingOrders.value = false;
      },
    );
    _productsSub = _service.watchProducts().listen(
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

  List<OrderRecord> get todayOrders {
    final now = DateTime.now();
    return orders.where((order) {
      final date = order.createdAt;
      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  double get todaySales =>
      todayOrders.fold(0.0, (accumulator, order) => accumulator + order.total);

  double get todayProfit => todayOrders.fold(
    0.0,
    (accumulator, order) =>
        accumulator +
        order.items.fold(
          0.0,
          (total, line) =>
              total + (line.unitPrice - line.costAtSale) * line.qty,
        ),
  );

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
    return orders
        .where((order) {
          final date = order.createdAt;
          return date != null &&
              date.year == day.year &&
              date.month == day.month &&
              date.day == day.day;
        })
        .fold(0.0, (accumulator, order) => accumulator + order.total);
  });

  List<double> get weeklyProfit => List.generate(7, (index) {
    final day = DateTime.now().subtract(Duration(days: 6 - index));
    return orders
        .where((order) {
          final date = order.createdAt;
          return date != null &&
              date.year == day.year &&
              date.month == day.month &&
              date.day == day.day;
        })
        .fold(
          0.0,
          (accumulator, order) =>
              accumulator +
              order.items.fold(
                0.0,
                (lineTotal, line) =>
                    lineTotal + (line.unitPrice - line.costAtSale) * line.qty,
              ),
        );
  });

  @override
  void onClose() {
    _ordersSub?.cancel();
    _billsSub?.cancel();
    _productsSub?.cancel();
    super.onClose();
  }
}
