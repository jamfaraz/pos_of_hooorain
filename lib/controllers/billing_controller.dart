import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/offer_record.dart';
import '../models/order_record.dart';
import '../models/product_record.dart';
import '../models/user_model.dart';
import '../services/control_room_service.dart';
import '../utils/pricing.dart';

class BillingController extends GetxController {
  BillingController(this._service);

  final ControlRoomService _service;
  final products = <ProductRecord>[].obs;
  final customers = <UserModel>[].obs;
  final offers = <OfferRecord>[].obs;
  final cart = <OrderLineRecord>[].obs;
  final selectedProductId = RxnString();
  final selectedCustomerId = RxnString();
  final customerType = 'home'.obs;
  final selectedPaymentMethod = 'cash'.obs;
  final isDiscountPercent = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = 'All'.obs;
  final loading = true.obs;
  final loadingMoreProducts = false.obs;
  final hasMoreProducts = false.obs;
  final productPageError = RxnString();
  final saving = false.obs;
  final error = RxnString();
  final discountController = TextEditingController();
  final deliveryController = TextEditingController(text: '0');
  final cashReceivedController = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _customersSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastProductDocument;
  final List<ProductRecord> _additionalProducts = [];
  bool _hasLoadedMoreProductPages = false;
  String? _draftBillNumber;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    _productsSub?.cancel();
    _offersSub?.cancel();
    _customersSub?.cancel();
    loading.value = true;
    error.value = null;
    productPageError.value = null;
    hasMoreProducts.value = false;
    _lastProductDocument = null;
    _additionalProducts.clear();
    _hasLoadedMoreProductPages = false;
    products.clear();
    _productsSub = _service.watchProducts().listen(
      (snapshot) {
        final firstPage = snapshot.docs
            .map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id))
            .where((product) => product.active)
            .toList();
        final firstPageIds = firstPage
            .map((product) => product.id)
            .whereType<String>()
            .toSet();
        products.assignAll([
          ...firstPage,
          ..._additionalProducts.where(
            (product) =>
                product.id == null || !firstPageIds.contains(product.id),
          ),
        ]);
        if (!_hasLoadedMoreProductPages) {
          _lastProductDocument = snapshot.docs.isEmpty
              ? null
              : snapshot.docs.last;
          hasMoreProducts.value =
              snapshot.docs.length >= ControlRoomService.pageSize;
        }
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
    _customersSub = _service.watchCustomers().listen(
      (snapshot) {
        customers.assignAll(
          snapshot.docs
              .map((doc) => UserModel.fromFirestore(doc))
              .where((customer) => !customer.isBanned),
        );
      },
      onError: (Object exception) {
        error.value = exception.toString();
      },
    );
  }

  Future<void> loadMoreProducts() async {
    final cursor = _lastProductDocument;
    if (cursor == null || !hasMoreProducts.value || loadingMoreProducts.value) {
      return;
    }

    loadingMoreProducts.value = true;
    productPageError.value = null;
    try {
      final page = await _service.fetchProductPage(after: cursor);
      if (page.docs.isNotEmpty) {
        _hasLoadedMoreProductPages = true;
        final existingIds = products
            .map((product) => product.id)
            .whereType<String>()
            .toSet();
        final newProducts = page.docs
            .where((doc) => !existingIds.contains(doc.id))
            .map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id))
            .where((product) => product.active)
            .toList();
        _additionalProducts.addAll(newProducts);
        products.addAll(newProducts);
        _lastProductDocument = page.docs.last;
      }
      hasMoreProducts.value = page.docs.length >= ControlRoomService.pageSize;
    } catch (exception) {
      productPageError.value = exception.toString();
    } finally {
      loadingMoreProducts.value = false;
    }
  }

  List<String> get categories {
    final names =
        products
            .map((product) => product.category.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...names];
  }

  List<ProductRecord> get filteredProducts {
    final query = searchQuery.value.trim().toLowerCase();
    return products.where((product) {
      final matchesCategory =
          selectedCategory.value == 'All' ||
          product.category.trim() == selectedCategory.value;
      final matchesQuery =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  ProductRecord? get selectedProduct => products
      .where((product) => product.id == selectedProductId.value)
      .firstOrNull;
  UserModel? get selectedCustomer => customers
      .where((customer) => customer.id == selectedCustomerId.value)
      .firstOrNull;

  double get subtotal =>
      cart.fold(0.0, (total, line) => total + line.unitPrice * line.qty);
  double? get _discountAmount => _parseAmount(discountController.text);
  double? get _deliveryAmount => _parseAmount(deliveryController.text);
  double get discount => isDiscountPercent.value
      ? subtotal * (_discountAmount ?? 0) / 100
      : _discountAmount ?? 0;
  double get delivery => _deliveryAmount ?? 0;
  double get total =>
      (subtotal - discount + delivery).clamp(0, double.infinity);
  double get cashReceived => _parseAmount(cashReceivedController.text) ?? 0;
  double get changeDue => (cashReceived - total).clamp(0, double.infinity);

  String ensureDraftBillNumber() =>
      _draftBillNumber ??= _service.newBillNumber();

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
    addProduct(product);
  }

  void addProduct(ProductRecord product) {
    if (saving.value) return;
    if (product.id == null) {
      error.value = 'This product cannot be added because it has no ID.';
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
          imageUrl: product.imageUrl,
        ),
      );
    } else {
      cart[existingIndex] = OrderLineRecord(
        productId: product.id!,
        name: product.name,
        qty: nextQty,
        unitPrice: price,
        costAtSale: product.cost,
        imageUrl: product.imageUrl,
      );
    }
    error.value = null;
  }

  void changeQuantity(OrderLineRecord line, int nextQty) {
    if (saving.value) return;
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
      imageUrl: line.imageUrl ?? product.imageUrl,
    );
    error.value = null;
  }

  void setCustomerType(String type) {
    if (saving.value) return;
    customerType.value = type;
    for (final line in cart.toList()) {
      changeQuantity(line, line.qty);
    }
  }

  void startNewBill() {
    cart.clear();
    discountController.clear();
    deliveryController.text = '0';
    cashReceivedController.clear();
    selectedCustomerId.value = null;
    customerType.value = 'home';
    selectedPaymentMethod.value = 'cash';
    isDiscountPercent.value = false;
    _draftBillNumber = null;
    error.value = null;
  }

  Future<String?> checkout() async {
    if (saving.value) throw StateError('A bill is already being saved.');
    if (cart.isEmpty) throw StateError('Add at least one product to the bill.');
    if (_discountAmount == null ||
        _deliveryAmount == null ||
        discount < 0 ||
        delivery < 0 ||
        discount > subtotal ||
        (isDiscountPercent.value && _discountAmount! > 100) ||
        (selectedPaymentMethod.value == 'cash' && cashReceived < total)) {
      throw ArgumentError('Check the discount and delivery amounts.');
    }
    saving.value = true;
    error.value = null;
    try {
      final order = OrderRecord(
        number: ensureDraftBillNumber(),
        userId: selectedCustomer?.id ?? '',
        userName: selectedCustomer?.fullName ?? 'Walk-in customer',
        userPhone: selectedCustomer?.phoneNumber ?? '',
        customerType: customerType.value,
        items: cart.toList(),
        subtotal: subtotal,
        discount: discount,
        delivery: delivery,
        total: total,
        paymentMethod: selectedPaymentMethod.value,
        paymentStatus: 'paid',
        status: 'Delivered',
        channel: 'counter',
      );
      final id = await _service.createOrder(order);
      startNewBill();
      return id;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _offersSub?.cancel();
    _customersSub?.cancel();
    discountController.dispose();
    deliveryController.dispose();
    cashReceivedController.dispose();
    super.onClose();
  }
}
