import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/offer_record.dart';
import '../models/order_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';
import '../utils/pricing.dart';

class BillingController extends GetxController {
  BillingController(this._service);

  final ControlRoomService _service;
  final products = <ProductRecord>[].obs;
  final offers = <OfferRecord>[].obs;
  final cart = <OrderLineRecord>[].obs;
  final selectedProductId = RxnString();
  final customerType = 'home'.obs;
  final loading = true.obs;
  final saving = false.obs;
  final error = RxnString();
  final discountController = TextEditingController();
  final deliveryController = TextEditingController(text: '0');
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    _productsSub?.cancel();
    _offersSub?.cancel();
    loading.value = true;
    error.value = null;
    _productsSub = _service.watchProducts().listen(
      (snapshot) {
        products.assignAll(
          snapshot.docs
              .map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id))
              .where((product) => product.active),
        );
        selectedProductId.value ??= products.firstOrNull?.id;
        loading.value = false;
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
    _offersSub = _service.watchOffers().listen(
      (snapshot) {
        offers.assignAll(
          snapshot.docs.map(
            (doc) => OfferRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
      },
      onError: (Object exception) {
        error.value = exception.toString();
      },
    );
  }

  ProductRecord? get selectedProduct => products
      .where((product) => product.id == selectedProductId.value)
      .firstOrNull;

  double get subtotal =>
      cart.fold(0.0, (total, line) => total + line.unitPrice * line.qty);
  double? get _discountAmount => _parseAmount(discountController.text);
  double? get _deliveryAmount => _parseAmount(deliveryController.text);
  double get discount => _discountAmount ?? 0;
  double get delivery => _deliveryAmount ?? 0;
  double get total =>
      (subtotal - discount + delivery).clamp(0, double.infinity);

  double? _parseAmount(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 0 : double.tryParse(trimmed);
  }

  void addSelectedProduct() {
    final product = selectedProduct;
    if (product == null || product.id == null) {
      error.value = 'Select a product before adding it.';
      return;
    }
    final existingIndex = cart.indexWhere(
      (line) => line.productId == product.id,
    );
    final nextQty = existingIndex < 0 ? 1 : cart[existingIndex].qty + 1;
    if (nextQty > product.stock) {
      error.value = '${product.name} only has ${product.stock} in stock.';
      return;
    }
    final price = unitPrice(
      product: product,
      shopCustomer: customerType.value == 'shop',
      quantity: nextQty,
      offers: offers,
    );
    if (existingIndex < 0) {
      cart.add(
        OrderLineRecord(
          productId: product.id!,
          name: product.name,
          qty: 1,
          unitPrice: price,
          costAtSale: product.cost,
        ),
      );
    } else {
      cart[existingIndex] = OrderLineRecord(
        productId: product.id!,
        name: product.name,
        qty: nextQty,
        unitPrice: price,
        costAtSale: product.cost,
      );
    }
    error.value = null;
  }

  void changeQuantity(OrderLineRecord line, int nextQty) {
    if (nextQty <= 0) {
      cart.remove(line);
      return;
    }
    final product = products
        .where((item) => item.id == line.productId)
        .firstOrNull;
    if (product == null) return;
    if (nextQty > product.stock) {
      error.value = '${product.name} only has ${product.stock} in stock.';
      return;
    }
    final price = unitPrice(
      product: product,
      shopCustomer: customerType.value == 'shop',
      quantity: nextQty,
      offers: offers,
    );
    final index = cart.indexOf(line);
    cart[index] = OrderLineRecord(
      productId: line.productId,
      name: line.name,
      qty: nextQty,
      unitPrice: price,
      costAtSale: product.cost,
    );
    error.value = null;
  }

  Future<String?> checkout() async {
    if (cart.isEmpty) throw StateError('Add at least one product to the bill.');
    if (_discountAmount == null ||
        _deliveryAmount == null ||
        discount < 0 ||
        delivery < 0 ||
        discount > subtotal) {
      throw ArgumentError('Check the discount and delivery amounts.');
    }
    saving.value = true;
    error.value = null;
    try {
      final order = OrderRecord(
        number: '',
        customerType: customerType.value,
        items: cart.toList(),
        subtotal: subtotal,
        discount: discount,
        delivery: delivery,
        total: total,
        paymentMethod: 'cash',
        paymentStatus: 'paid',
        status: 'Delivered',
        channel: 'counter',
      );
      final id = await _service.createOrder(order);
      cart.clear();
      discountController.clear();
      deliveryController.text = '0';
      return id;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _offersSub?.cancel();
    discountController.dispose();
    deliveryController.dispose();
    super.onClose();
  }
}
