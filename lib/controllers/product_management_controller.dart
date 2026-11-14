import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/category_record.dart';
import '../models/offer_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';

class ProductManagementController extends GetxController {
  ProductManagementController(this._service);

  final ControlRoomService _service;
  final products = <ProductRecord>[].obs;
  final categories = <CategoryRecord>[].obs;
  final offers = <OfferRecord>[].obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  final search = ''.obs;
  final mode = 'all'.obs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastProductDoc;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    loading.value = true;
    error.value = null;
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _offersSub?.cancel();
    _productsSub = _service.watchProducts().listen(
      (snapshot) {
        products.assignAll(
          snapshot.docs.map(
            (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        _lastProductDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        canLoadMore.value = snapshot.docs.length == ControlRoomService.pageSize;
        loading.value = false;
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
    _categoriesSub = _service.watchCategories().listen((snapshot) {
      categories.assignAll(
        snapshot.docs.map(
          (doc) => CategoryRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
    }, onError: (Object exception) => error.value = exception.toString());
    _offersSub = _service.watchOffers().listen((snapshot) {
      offers.assignAll(
        snapshot.docs.map((doc) => OfferRecord.fromMap(doc.data(), id: doc.id)),
      );
    }, onError: (Object exception) => error.value = exception.toString());
  }

  Future<void> loadMore() async {
    final cursor = _lastProductDoc;
    if (cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      final page = await _service.fetchPage(
        'products',
        after: cursor,
        orderBy: 'name',
        descending: false,
      );
      products.addAll(
        page.docs.map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id)),
      );
      _lastProductDoc = page.docs.isEmpty ? null : page.docs.last;
      canLoadMore.value = page.docs.length == ControlRoomService.pageSize;
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  List<ProductRecord> get filteredProducts {
    final needle = search.value.trim().toLowerCase();
    return products.where((product) {
      final matchesMode = switch (mode.value) {
        'featured' => product.featured,
        'hidden' => !product.active,
        _ => true,
      };
      final matchesSearch =
          needle.isEmpty ||
          product.name.toLowerCase().contains(needle) ||
          product.sku.toLowerCase().contains(needle);
      return matchesMode && matchesSearch;
    }).toList();
  }

  String categoryName(String id) =>
      categories.firstWhereOrNull((category) => category.id == id)?.name ?? id;

  bool hasLiveOffer(ProductRecord product) => offers.any(
    (offer) =>
        offer.live &&
        offer.productIds.contains(product.id) &&
        (offer.endsAt == null || offer.endsAt!.isAfter(DateTime.now())),
  );

  Future<void> saveProduct(ProductRecord product) async {
    try {
      await _service.saveProduct(product);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<bool> deleteOrHide(ProductRecord product) async {
    final id = product.id;
    if (id == null) throw StateError('Cannot update a product without an ID.');
    try {
      if (await _service.hasSalesHistory(id)) {
        await _service.saveProduct(product.copyWith(active: false));
        return false;
      }
      await _service.deleteProduct(id);
      return true;
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<void> toggleFeatured(ProductRecord product, bool featured) =>
      saveProduct(product.copyWith(featured: featured));

  Future<void> toggleVisible(ProductRecord product, bool active) =>
      saveProduct(product.copyWith(active: active));

  @override
  void onClose() {
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _offersSub?.cancel();
    super.onClose();
  }
}
