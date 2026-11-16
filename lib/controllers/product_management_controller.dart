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
  final loadMoreError = RxnString();
  final productCounts = <String, int>{'all': 0, 'featured': 0, 'hidden': 0}.obs;
  final productCountsError = RxnString();
  final search = ''.obs;
  final mode = 'all'.obs;
  bool _countsInitialized = false;
  bool _hasLoadedMoreProducts = false;
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
    loadMoreError.value = null;
    _hasLoadedMoreProducts = false;
    _productsSub?.cancel();
    _categoriesSub?.cancel();
    _offersSub?.cancel();
    _productsSub = _service
        .watchProductScreenPage(mode: mode.value)
        .listen(
          (snapshot) {
            final firstPage = snapshot.docs
                .map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id))
                .toList();
            final firstPageIds = firstPage
                .map((product) => product.id)
                .whereType<String>()
                .toSet();
            final laterPages = _hasLoadedMoreProducts
                ? products
                      .where(
                        (product) =>
                            product.id == null ||
                            !firstPageIds.contains(product.id),
                      )
                      .toList()
                : <ProductRecord>[];
            products.assignAll([...firstPage, ...laterPages]);
            if (!_hasLoadedMoreProducts) {
              _lastProductDoc = snapshot.docs.isEmpty
                  ? null
                  : snapshot.docs.last;
              canLoadMore.value =
                  snapshot.docs.length ==
                  ControlRoomService.productScreenPageSize;
            }
            loading.value = false;
          },
          onError: (Object exception) {
            error.value = exception.toString();
            loading.value = false;
          },
        );
    if (!_countsInitialized) {
      _countsInitialized = true;
      unawaited(refreshProductCounts());
    }
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
    loadMoreError.value = null;
    try {
      final page = await _service.fetchProductScreenPage(
        mode: mode.value,
        after: cursor,
      );
      products.addAll(
        page.docs.map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id)),
      );
      if (page.docs.isNotEmpty) _hasLoadedMoreProducts = true;
      _lastProductDoc = page.docs.isEmpty ? null : page.docs.last;
      canLoadMore.value =
          page.docs.length == ControlRoomService.productScreenPageSize;
    } catch (exception) {
      loadMoreError.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  List<ProductRecord> get filteredProducts => filteredProductsFor(mode.value);

  List<ProductRecord> filteredProductsFor(String selectedMode) {
    final needle = search.value.trim().toLowerCase();
    return products.where((product) {
      final matchesMode = switch (selectedMode) {
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

  void configureScreen(String selectedMode) {
    if (mode.value == selectedMode) return;
    mode.value = selectedMode;
    products.clear();
    _lastProductDoc = null;
    _hasLoadedMoreProducts = false;
    canLoadMore.value = false;
    reload();
  }

  void setMode(String selectedMode) => configureScreen(selectedMode);

  Future<void> refreshProductCounts() async {
    productCountsError.value = null;
    try {
      final counts = await Future.wait([
        _service.countProductScreen('all'),
        _service.countProductScreen('featured'),
        _service.countProductScreen('hidden'),
      ]);
      productCounts.assignAll({
        'all': counts[0],
        'featured': counts[1],
        'hidden': counts[2],
      });
    } catch (exception) {
      productCountsError.value = exception.toString();
    }
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
      unawaited(refreshProductCounts());
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
        unawaited(refreshProductCounts());
        return false;
      }
      await _service.deleteProduct(id);
      unawaited(refreshProductCounts());
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
