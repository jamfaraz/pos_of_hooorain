import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/product_record.dart';
import '../services/control_room_service.dart';

class InventoryController extends GetxController {
  InventoryController(this._service);

  final ControlRoomService _service;
  final products = <ProductRecord>[].obs;
  final movements = <Map<String, dynamic>>[].obs;
  final lowStockOnly = false.obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _movementsSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastMovement;

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
      if (_lastMovement == null && snapshot.docs.isNotEmpty) {
        _lastMovement = snapshot.docs.last;
      }
      final pageIds = snapshot.docs.map((doc) => doc.id).toSet();
      final loadedOlder = movements.where(
        (movement) => !pageIds.contains(movement['id']),
      );
      movements.assignAll([
        ...snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}),
        ...loadedOlder,
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
    return list;
  }

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

  Future<void> loadMoreMovements() async {
    if (loadingMore.value || _lastMovement == null) return;
    loadingMore.value = true;
    error.value = null;
    try {
      final page = await _service.fetchPage(
        'stockMovements',
        after: _lastMovement,
      );
      if (page.docs.isNotEmpty) {
        _lastMovement = page.docs.last;
        movements.addAll(page.docs.map((doc) => {...doc.data(), 'id': doc.id}));
      }
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  @override
  void onClose() {
    _productsSub?.cancel();
    _movementsSub?.cancel();
    super.onClose();
  }
}
