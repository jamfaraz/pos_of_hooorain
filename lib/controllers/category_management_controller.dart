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
  final products = <ProductRecord>[].obs;
  final selected = Rxn<CategoryRecord>();
  final selectedSubcategory = ''.obs;
  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productsSub;
  DocumentSnapshot<Map<String, dynamic>>? _lastCategoryDoc;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    loading.value = true;
    error.value = null;
    _categoriesSub?.cancel();
    _productsSub?.cancel();
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
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
    _productsSub = _service.watchProducts().listen((snapshot) {
      products.assignAll(
        snapshot.docs.map(
          (doc) => ProductRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
    }, onError: (Object exception) => error.value = exception.toString());
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
      _lastCategoryDoc = page.docs.isEmpty ? null : page.docs.last;
      canLoadMore.value = page.docs.length == ControlRoomService.pageSize;
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  List<ProductRecord> get selectedProducts => products.where((product) {
    if (selected.value?.id != product.categoryId &&
        selected.value?.name != product.categoryId) {
      return false;
    }
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
    _productsSub?.cancel();
    super.onClose();
  }
}
