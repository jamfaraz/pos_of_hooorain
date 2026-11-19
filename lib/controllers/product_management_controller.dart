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
  final _productScreens = <String, _ProductScreenState>{
    'all': _ProductScreenState(),
    'featured': _ProductScreenState(),
    'hidden': _ProductScreenState(),
  };
  final categories = <CategoryRecord>[].obs;
  final offers = <OfferRecord>[].obs;
  final productCounts = <String, int>{'all': 0, 'featured': 0, 'hidden': 0}.obs;
  final productCountsError = RxnString();
  final search = ''.obs;
  final mode = 'all'.obs;
  bool _countsInitialized = false;
  bool _relatedDataLoaded = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offersSub;

  RxList<ProductRecord> productsFor(String selectedMode) =>
      _screen(selectedMode).products;

  RxBool loadingFor(String selectedMode) => _screen(selectedMode).loading;

  RxBool loadingMoreFor(String selectedMode) =>
      _screen(selectedMode).loadingMore;

  RxBool canLoadMoreFor(String selectedMode) =>
      _screen(selectedMode).canLoadMore;

  RxnString errorFor(String selectedMode) => _screen(selectedMode).error;

  RxnString loadMoreErrorFor(String selectedMode) =>
      _screen(selectedMode).loadMoreError;

  RxList<ProductRecord> get products => productsFor(mode.value);
  RxBool get loading => loadingFor(mode.value);
  RxBool get loadingMore => loadingMoreFor(mode.value);
  RxBool get canLoadMore => canLoadMoreFor(mode.value);
  RxnString get error => errorFor(mode.value);
  RxnString get loadMoreError => loadMoreErrorFor(mode.value);

  @override
  void onInit() {
    super.onInit();
    _watchRelatedData();
  }

  void reload({String? selectedMode}) {
    final screenMode = selectedMode ?? mode.value;
    final screen = _screen(screenMode);
    screen.loading.value = true;
    screen.error.value = null;
    screen.loadMoreError.value = null;
    screen.hasLoadedMoreProducts = false;
    screen.productsSub?.cancel();
    screen.productsSub = _service
        .watchProductScreenPage(mode: screenMode)
        .listen(
          (snapshot) {
            final firstPage = snapshot.docs
                .map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id))
                .toList();
            final firstPageIds = firstPage
                .map((product) => product.id)
                .whereType<String>()
                .toSet();
            final laterPages = screen.hasLoadedMoreProducts
                ? screen.products
                      .where(
                        (product) =>
                            product.id == null ||
                            !firstPageIds.contains(product.id),
                      )
                      .toList()
                : <ProductRecord>[];
            screen.products.assignAll([...firstPage, ...laterPages]);
            if (!screen.hasLoadedMoreProducts) {
              screen.lastProductDoc = snapshot.docs.isEmpty
                  ? null
                  : snapshot.docs.last;
              screen.canLoadMore.value =
                  snapshot.docs.length ==
                  ControlRoomService.productScreenPageSize;
            }
            screen.loading.value = false;
          },
          onError: (Object exception) {
            screen.error.value = exception.toString();
            screen.loading.value = false;
          },
        );
    if (!_countsInitialized) {
      _countsInitialized = true;
      unawaited(refreshProductCounts());
    }
  }

  void _watchRelatedData() {
    if (_relatedDataLoaded) return;
    _relatedDataLoaded = true;
    _categoriesSub = _service.watchCategories().listen(
      (snapshot) {
        categories.assignAll(
          snapshot.docs.map(
            (doc) => CategoryRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
      },
      onError: (Object exception) {
        error.value = exception.toString();
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

  Future<void> loadMore({String? selectedMode}) async {
    final screenMode = selectedMode ?? mode.value;
    final screen = _screen(screenMode);
    final cursor = screen.lastProductDoc;
    if (cursor == null ||
        !screen.canLoadMore.value ||
        screen.loadingMore.value) {
      return;
    }
    screen.loadingMore.value = true;
    screen.loadMoreError.value = null;
    try {
      final page = await _service.fetchProductScreenPage(
        mode: screenMode,
        after: cursor,
      );
      screen.products.addAll(
        page.docs.map((doc) => ProductRecord.fromMap(doc.data(), id: doc.id)),
      );
      if (page.docs.isNotEmpty) screen.hasLoadedMoreProducts = true;
      screen.lastProductDoc = page.docs.isEmpty ? null : page.docs.last;
      screen.canLoadMore.value =
          page.docs.length == ControlRoomService.productScreenPageSize;
    } catch (exception) {
      screen.loadMoreError.value = exception.toString();
    } finally {
      screen.loadingMore.value = false;
    }
  }

  List<ProductRecord> get filteredProducts => filteredProductsFor(mode.value);

  List<ProductRecord> filteredProductsFor(String selectedMode) {
    final needle = search.value.trim().toLowerCase();
    return productsFor(selectedMode).where((product) {
      final matchesSearch =
          needle.isEmpty ||
          product.name.toLowerCase().contains(needle) ||
          product.sku.toLowerCase().contains(needle);
      return matchesSearch;
    }).toList();
  }

  void configureScreen(String selectedMode) {
    final screen = _screen(selectedMode);
    if (screen.productsSub == null) reload(selectedMode: selectedMode);
  }

  void setMode(String selectedMode) {
    mode.value = selectedMode;
    configureScreen(selectedMode);
  }

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
    for (final screen in _productScreens.values) {
      screen.productsSub?.cancel();
    }
    _categoriesSub?.cancel();
    _offersSub?.cancel();
    super.onClose();
  }

  _ProductScreenState _screen(String selectedMode) =>
      _productScreens[selectedMode] ??
      (throw ArgumentError.value(selectedMode, 'selectedMode'));
}

class _ProductScreenState {
  final products = <ProductRecord>[].obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  final loadMoreError = RxnString();
  bool hasLoadedMoreProducts = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? productsSub;
  DocumentSnapshot<Map<String, dynamic>>? lastProductDoc;
}
