import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/offer_record.dart';
import '../models/order_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';
import '../utils/pricing.dart';
import '../utils/profit_analysis.dart';

class ItemProfitController extends GetxController {
  ItemProfitController(this._service);

  final ControlRoomService _service;
  final products = <ProductRecord>[].obs;
  final orders = <OrderRecord>[].obs;
  final offers = <OfferRecord>[].obs;
  final productId = RxnString();
  final periodDays = 30.obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;
  DocumentSnapshot<Map<String, dynamic>>? _orderCursor;
  DocumentSnapshot<Map<String, dynamic>>? _billCursor;
  final Map<String, OrderRecord> _loadedOrderMap = {};
  bool _ordersDone = false;
  bool _billsDone = false;
  String? _requestedProductId;

  bool get canLoadMore => !_ordersDone || !_billsDone;

  @override
  void onInit() {
    super.onInit();
    final initialProductId = Get.arguments;
    if (initialProductId is String && initialProductId.isNotEmpty) {
      productId.value = initialProductId;
    }
    reload();
  }

  void reload() {
    _productsSub?.cancel();
    _ordersSub?.cancel();
    _billsSub?.cancel();
    _offersSub?.cancel();
    loading.value = true;
    error.value = null;
    _orderCursor = null;
    _billCursor = null;
    _loadedOrderMap.clear();
    _requestedProductId = null;
    _ordersDone = false;
    _billsDone = false;
    void updateOrders() {
      orders.assignAll(_loadedOrderMap.values);
      loading.value = false;
    }

    _productsSub = _service.watchProducts().listen((snapshot) {
      final selectedId = productId.value;
      final cachedSelected = selectedId == null
          ? null
          : products.where((product) => product.id == selectedId).firstOrNull;
      products.assignAll(
        snapshot.docs.map(
          (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
      if (selectedId == null) {
        productId.value = products.firstOrNull?.id;
      } else if (!products.any((product) => product.id == selectedId)) {
        if (cachedSelected != null) {
          products.add(cachedSelected);
        } else {
          _loadSelectedProduct(selectedId);
        }
      }
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
    _offersSub = _service.watchOffers().listen((snapshot) {
      offers.assignAll(
        snapshot.docs.map((doc) => OfferRecord.fromMap(doc.data(), id: doc.id)),
      );
    }, onError: _handleError);
  }

  void _handleError(Object exception) {
    error.value = exception.toString();
    loading.value = false;
  }

  Future<void> _loadSelectedProduct(String id) async {
    if (_requestedProductId == id) return;
    _requestedProductId = id;
    try {
      final doc = await _service.fetchProductById(id);
      if (!doc.exists) {
        if (productId.value == id) productId.value = products.firstOrNull?.id;
        return;
      }
      if (!products.any((product) => product.id == id)) {
        products.add(ProductRecord.fromMap(doc.data()!, id: doc.id));
      }
    } catch (exception) {
      _requestedProductId = null;
      _handleError(exception);
    }
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
        } else {
          _ordersDone = true;
        }
        if (page.docs.length < ControlRoomService.pageSize) {
          _ordersDone = true;
        }
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
        } else {
          _billsDone = true;
        }
        if (page.docs.length < ControlRoomService.pageSize) {
          _billsDone = true;
        }
      }
      orders.assignAll(_loadedOrderMap.values);
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  ProductRecord? get selectedProduct =>
      products.where((product) => product.id == productId.value).firstOrNull;

  List<OrderRecord> get periodOrders {
    final cutoff = DateTime.now().subtract(Duration(days: periodDays.value));
    return orders
        .where(
          (order) =>
              order.createdAt != null && order.createdAt!.isAfter(cutoff),
        )
        .toList();
  }

  List<OrderRecord> get selectedProductOrders => periodOrders
      .where(
        (order) => order.items.any((line) => line.productId == productId.value),
      )
      .toList();

  ProfitTotals get selectedTotals => calculateProfitTotals(
    selectedProductOrders.map(
      (order) => OrderRecord(
        items: order.items
            .where((line) => line.productId == productId.value)
            .toList(),
        number: order.number,
        createdAt: order.createdAt,
        customerType: order.customerType,
      ),
    ),
  );

  List<(String, double)> get priceScenarios {
    final product = selectedProduct;
    if (product == null) return const [];
    final scenarios = <(String, double)>[
      (
        'Home price',
        unitPrice(product: product, shopCustomer: false, quantity: 1),
      ),
      (
        'Shop price',
        unitPrice(product: product, shopCustomer: true, quantity: 1),
      ),
    ];
    if (product.bulkEnabled) {
      for (final tier in product.tiers) {
        final qty = (tier['qty'] as num?)?.toInt() ?? 1;
        scenarios.add((
          'Bulk · $qty+ · Home',
          unitPrice(product: product, shopCustomer: false, quantity: qty),
        ));
        scenarios.add((
          'Bulk · $qty+ · Shop',
          unitPrice(product: product, shopCustomer: true, quantity: qty),
        ));
      }
    }
    for (final offer in offers.where(
      (offer) =>
          offer.live &&
          offer.productIds.contains(product.id) &&
          (offer.endsAt == null || offer.endsAt!.isAfter(DateTime.now())),
    )) {
      if (offer.audience != 'shop') {
        scenarios.add((
          'Offer · ${offer.name} · Home',
          unitPrice(
            product: product,
            shopCustomer: false,
            quantity: 1,
            offers: [offer],
          ),
        ));
      }
      if (offer.audience != 'home') {
        scenarios.add((
          'Offer · ${offer.name} · Shop',
          unitPrice(
            product: product,
            shopCustomer: true,
            quantity: 1,
            offers: [offer],
          ),
        ));
      }
    }
    return scenarios;
  }

  int get belowCostCount => priceScenarios
      .where((scenario) => scenario.$2 < (selectedProduct?.cost ?? 0))
      .length;

  List<double> get dailyProfit {
    final product = selectedProduct;
    if (product == null) return List.filled(periodDays.value, 0);
    return List.generate(periodDays.value, (index) {
      final day = DateTime.now().subtract(
        Duration(days: periodDays.value - index - 1),
      );
      return selectedProductOrders
          .where((order) {
            final date = order.createdAt!;
            return date.year == day.year &&
                date.month == day.month &&
                date.day == day.day;
          })
          .fold(
            0.0,
            (accumulator, order) =>
                accumulator +
                order.items
                    .where((line) => line.productId == product.id)
                    .fold(
                      0.0,
                      (lineSum, line) =>
                          lineSum +
                          (line.unitPrice - line.costAtSale) * line.qty,
                    ),
          );
    });
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _ordersSub?.cancel();
    _billsSub?.cancel();
    _offersSub?.cancel();
    super.onClose();
  }
}
