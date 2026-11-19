import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/category_record.dart';
import '../models/product_record.dart';
import '../services/control_room_service.dart';

class CategoryManagementController extends GetxController {
  CategoryManagementController(this._service);

  final ControlRoomService _service;
  final categories = <CategoryRecord>[].obs;
  final categoryProductCounts = <String, int>{}.obs;
  final loadingProductCountIds = <String>{}.obs;
  final categoryProducts = <ProductRecord>[].obs;
  final selected = Rxn<CategoryRecord>();
  final selectedSubcategory = ''.obs;
  final loadingCategoryProducts = false.obs;
  final categoryProductsError = RxnString();
  final categoryCountsError = RxnString();
  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastCategoryDoc;
  int _categoryProductsRequestId = 0;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    loading.value = true;
    error.value = null;
    _categoriesSub?.cancel();
    _categoriesSub = _service.watchCategories().listen(
      (snapshot) {
        categories.assignAll(
          snapshot.docs.map(
            (doc) => CategoryRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        _lastCategoryDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;
        canLoadMore.value = snapshot.docs.length == ControlRoomService.pageSize;
        loading.value = false;
        loadCategoryProductCounts(categories);
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
  }

  Future<void> loadMore() async {
    final cursor = _lastCategoryDoc;
    if (cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      final page = await _service.fetchCategoryPage(after: cursor);
      categories.addAll(
        page.docs.map((doc) => CategoryRecord.fromMap(doc.data(), id: doc.id)),
      );
      loadCategoryProductCounts(
        page.docs.map((doc) => CategoryRecord.fromMap(doc.data(), id: doc.id)),
      );
      _lastCategoryDoc = page.docs.isEmpty ? null : page.docs.last;
      canLoadMore.value = page.docs.length == ControlRoomService.pageSize;
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> selectCategory(CategoryRecord category) async {
    selected.value = category;
    selectedSubcategory.value = '';
    await reloadSelectedProducts();
  }

  Future<void> loadCategoryProductCounts(
    Iterable<CategoryRecord> categoriesToCount,
  ) async {
    final pending = <Future<void>>[];
    for (final category in categoriesToCount) {
      final key = category.id ?? category.name;
      if (categoryProductCounts.containsKey(key) ||
          loadingProductCountIds.contains(key)) {
        continue;
      }
      loadingProductCountIds.add(key);
      pending.add(_loadCategoryProductCount(category, key));
    }
    await Future.wait(pending);
  }

  Future<void> _loadCategoryProductCount(
    CategoryRecord category,
    String key,
  ) async {
    try {
      final count = await _service.countProductsForCategory(
        categoryId: category.id ?? category.name,
        categoryName: category.name,
      );
      categoryProductCounts[key] = count;
    } catch (exception) {
      categoryCountsError.value = exception.toString();
    } finally {
      loadingProductCountIds.remove(key);
    }
  }

  Future<void> retryCategoryProductCounts() async {
    categoryCountsError.value = null;
    await loadCategoryProductCounts(
      categories.where(
        (category) =>
            !categoryProductCounts.containsKey(category.id ?? category.name),
      ),
    );
  }

  void clearSelectedCategory() {
    _categoryProductsRequestId++;
    selected.value = null;
    selectedSubcategory.value = '';
    loadingCategoryProducts.value = false;
    categoryProducts.clear();
    categoryProductsError.value = null;
    categoryProductCounts.clear();
    categoryCountsError.value = null;
    loadCategoryProductCounts(categories);
  }

  Future<void> reloadSelectedProducts() async {
    final category = selected.value;
    if (category == null) return;
    final requestId = ++_categoryProductsRequestId;
    loadingCategoryProducts.value = true;
    categoryProductsError.value = null;
    try {
      final loaded = await _service.fetchProductsForCategory(
        categoryId: category.id ?? category.name,
        categoryName: category.name,
      );
      if (requestId != _categoryProductsRequestId) return;
      categoryProducts.assignAll(loaded);
      categoryProductCounts[category.id ?? category.name] = loaded.length;
    } catch (exception) {
      if (requestId == _categoryProductsRequestId) {
        categoryProductsError.value = exception.toString();
      }
    } finally {
      if (requestId == _categoryProductsRequestId) {
        loadingCategoryProducts.value = false;
      }
    }
  }

  List<ProductRecord> get selectedProducts => categoryProducts.where((product) {
    return selectedSubcategory.value.isEmpty ||
        product.subcategory == selectedSubcategory.value;
  }).toList();

  Future<void> save(CategoryRecord category) async {
    try {
      await _service.saveCategory(category);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<void> delete(CategoryRecord category) async {
    if (category.id == null) throw StateError('Category has no document ID.');
    try {
      await _service.deleteCategory(category.id!);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  @override
  void onClose() {
    _categoriesSub?.cancel();
    super.onClose();
  }
}
