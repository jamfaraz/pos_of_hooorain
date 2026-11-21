import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/product_record.dart';
import '../services/inventory_service.dart';

class InventoryController extends GetxController {
  InventoryController(this._service);

  final InventoryService _service;
  final products = <ProductRecord>[].obs;
  final movements = <Map<String, dynamic>>[].obs;
  final lowStockOnly = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = 'All'.obs;
  final sortMode = 'value'.obs;
  final loading = true.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _movementsSub;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    _productsSub?.cancel();
    _movementsSub?.cancel();
    loading.value = true;
    error.value = null;
    movements.clear();
    _productsSub = _service.watchProducts().listen((snapshot) {
      products.assignAll(
        snapshot.docs.map(
          (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
      loading.value = false;
    }, onError: _handleError);
    _movementsSub = _service.watchStockMovements().listen((snapshot) {
      movements.assignAll([
        ...snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}),
      ]);
      loading.value = false;
    }, onError: _handleError);
  }

  void _handleError(Object exception) {
    error.value = exception.toString();
    loading.value = false;
  }

  List<ProductRecord> get visibleProducts {
    final list = products.toList();
    if (lowStockOnly.value) {
      list.removeWhere(
        (product) =>
            product.reorderLevel <= 0 || product.stock > product.reorderLevel,
      );
    }
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      list.removeWhere(
        (product) =>
            !product.name.toLowerCase().contains(query) &&
            !product.sku.toLowerCase().contains(query),
      );
    }
    if (selectedCategory.value != 'All') {
      list.removeWhere((product) => product.category != selectedCategory.value);
    }
    switch (sortMode.value) {
      case 'qty':
        list.sort((a, b) => b.stock.compareTo(a.stock));
      case 'low':
        list.sort((a, b) => a.stock.compareTo(b.stock));
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
      default:
        list.sort(
          (a, b) =>
              (b.stock * b.inventoryCost).compareTo(a.stock * a.inventoryCost),
        );
    }
    return list;
  }

  int get inventoryUnitCount => products.fold(
    0,
    (total, product) => total + (product.stock > 0 ? product.stock : 0),
  );

  int get inStockProductCount =>
      products.where((product) => product.stock > 0).length;

  double get inventoryRetailValue => products.fold(
    0.0,
    (total, product) =>
        total +
        (product.stock > 0 ? product.stock.toDouble() * product.price : 0.0),
  );

  double get inventoryExpectedProfit =>
      inventoryRetailValue - inventoryStockValue;

  List<String> get categories {
    final values =
        products
            .map((product) => product.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<(String, double)> get categoryStockValues {
    final totals = <String, double>{};
    for (final product in products) {
      final category = product.category.trim().isEmpty
          ? 'Uncategorised'
          : product.category.trim();
      totals[category] =
          (totals[category] ?? 0) +
          (product.stock > 0
              ? product.stock.toDouble() * product.inventoryCost
              : 0);
    }
    return totals.entries.map((entry) => (entry.key, entry.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  double get inventoryStockValue => InventoryService.stockValue(products);

  ProductRecord? productById(String? id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<void> addStock({
    required ProductRecord product,
    required int quantity,
    required String note,
  }) async {
    if (product.id == null) throw StateError('Product has no ID.');
    await _service.addStock(product.id!, quantity, note);
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _movementsSub?.cancel();
    super.onClose();
  }
}
