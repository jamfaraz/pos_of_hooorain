import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/product_model.dart';
import '../utils/toas_message.dart';

class FetchProductController extends GetxController {
  final totalProducts = Rxn<int>();
  final isLoadingTotalProducts = false.obs;
  final RxList<String> subcategories = <String>[].obs;
  final RxString selectedSubcategory = 'All'.obs;
  final isLoadingSubcategories = false.obs;
  final RxList<Product> products = <Product>[].obs;
  final RxList<Product> hiddenProducts = <Product>[].obs;
  StreamSubscription<QuerySnapshot>? _totalProductsSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchTotalProducts();
    listenToTotalProducts();
  }

  @override
  dispose() {
    _totalProductsSubscription?.cancel();
    super.dispose();
  }

  // Method to get ALL products including hidden
  Stream<List<Product>> getAllProductsByCategory(
    String category, {
    String? subcategory,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: category);

    if (subcategory != null && subcategory != 'All') {
      query = query.where('subcategory', isEqualTo: subcategory);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final bool isHide = data['isHide'] ?? false;
        return Product.fromMap({...data, 'isHide': isHide}, id: doc.id);
      }).toList();
    });
  }

  // Method to get ONLY HIDDEN products
  Stream<List<Product>> getHiddenProducts() {
    return FirebaseFirestore.instance
        .collection('products')
        .where('isHide', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Product.fromMap(data, id: doc.id);
          }).toList();
        });
  }

  // Method to get ONLY VISIBLE products
  Stream<List<Product>> getVisibleProductsByCategory(
    String category, {
    String? subcategory,
  }) {
    Query query = FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: category)
        .where('isHide', isEqualTo: false);

    if (subcategory != null && subcategory != 'All') {
      query = query.where('subcategory', isEqualTo: subcategory);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap(data, id: doc.id);
      }).toList();
    });
  }

  Future<void> fetchSubcategoriesForCategory(String category) async {
    try {
      isLoadingSubcategories.value = true;
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('category', isEqualTo: category)
          .get();

      Set<String> uniqueSubcategories = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? subcategory = data['subcategory'] as String?;
        if (subcategory != null && subcategory.isNotEmpty) {
          uniqueSubcategories.add(subcategory);
        }
      }

      subcategories.value = ['All', ...uniqueSubcategories.toList()..sort()];
      selectedSubcategory.value = 'All';
    } catch (e) {
      print('Error fetching subcategories: $e');
      MessageToast.showToast(msg: 'Failed to fetch subcategories');
      subcategories.value = ['All'];
    } finally {
      isLoadingSubcategories.value = false;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
      MessageToast.showToast(msg: 'Product deleted successfully');

      // Remove from both lists
      products.removeWhere((product) => product.id == productId);
      hiddenProducts.removeWhere((product) => product.id == productId);
      products.refresh();
      hiddenProducts.refresh();
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to delete product: $e');
    }
  }

  // Live count — updates automatically on any add/delete/hide/unhide
  void listenToTotalProducts() {
    isLoadingTotalProducts.value = true;
    _totalProductsSubscription = FirebaseFirestore.instance
        .collection('products')
        .snapshots()
        .listen(
          (snapshot) {
            totalProducts.value = snapshot.docs.length;
            isLoadingTotalProducts.value = false;
          },
          onError: (e) {
            print('Error listening to total products: $e');
            MessageToast.showToast(msg: 'Failed to fetch total products');
            totalProducts.value = null;
            isLoadingTotalProducts.value = false;
          },
        );
  }

  // Count ALL products (both hidden and visible)
  Future<void> fetchTotalProducts() async {
    try {
      isLoadingTotalProducts.value = true;
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .get();

      totalProducts.value = snapshot.docs.length;
    } catch (e) {
      print('Error fetching total products: $e');
      MessageToast.showToast(msg: 'Failed to fetch total products');
      totalProducts.value = null;
    } finally {
      isLoadingTotalProducts.value = false;
    }
  }

  // Count only VISIBLE products
  Future<int> getVisibleProductsCount() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('isHide', isEqualTo: false)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching visible products count: $e');
      return 0;
    }
  }

  // Count only HIDDEN products
  Future<int> getHiddenProductsCount() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('isHide', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching hidden products count: $e');
      return 0;
    }
  }
  // Add these methods to your existing FetchProductController

  // Load featured products
  Future<void> loadFeaturedProducts() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('isFeatured', isEqualTo: true)
          .get();

      // Update both products list and filter featured products
      products.value = snapshot.docs.map((doc) {
        final data = doc.data();
        final bool isHide = data['isHide'] ?? false;
        return Product.fromMap({...data, 'isHide': isHide}, id: doc.id);
      }).toList();

      products.refresh();
    } catch (e) {
      print('Error loading featured products: $e');
      MessageToast.showToast(msg: 'Failed to load featured products');
    }
  }

  // Toggle featured status
  Future<void> toggleFeaturedStatus(String productId, bool isFeatured) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
            'isFeatured': isFeatured,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update local product
      await refreshSingleProduct(productId);

      MessageToast.showToast(
        msg: isFeatured
            ? 'Product added to featured'
            : 'Product removed from featured',
      );
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to update featured status: $e');
    }
  }

  // Add product to featured
  Future<void> addToFeatured(String productId) async {
    await toggleFeaturedStatus(productId, true);
  }

  // Remove product from featured
  Future<void> removeFromFeatured(String productId) async {
    await toggleFeaturedStatus(productId, false);
  }

  // Refresh a single product by ID and update appropriate lists
  Future<void> refreshSingleProduct(String productId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool isHide = data['isHide'] ?? false;
        final productData = {...data, 'isHide': isHide};
        final updatedProduct = Product.fromMap(productData, id: doc.id);

        // Remove from both lists first
        products.removeWhere((p) => p.id == productId);
        hiddenProducts.removeWhere((p) => p.id == productId);

        // Add to appropriate list based on visibility
        if (isHide) {
          hiddenProducts.add(updatedProduct);
        } else {
          products.add(updatedProduct);
        }

        products.refresh();
        hiddenProducts.refresh();
      }
    } catch (e) {
      print('Error refreshing single product: $e');
    }
  }

  // Get only VISIBLE products from local list
  List<Product> get visibleProducts {
    return products.where((product) => !product.isHide).toList();
  }

  // Add product to appropriate list based on visibility
  void addProductToList(Product product) {
    if (product.isHide) {
      hiddenProducts.add(product);
      hiddenProducts.refresh();
    } else {
      products.add(product);
      products.refresh();
    }
  }

  // Clear all products
  void clearProducts() {
    products.clear();
    hiddenProducts.clear();
  }

  // Check if a product is visible
  bool isProductVisible(Product product) {
    return !product.isHide;
  }

  // Toggle product visibility
  Future<void> toggleProductVisibility(String productId, bool isHide) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .update({
            'isHide': isHide,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Update local product lists
      await refreshSingleProduct(productId);

      MessageToast.showToast(
        msg: isHide ? 'Product hidden' : 'Product made visible',
      );
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to update product visibility: $e');
    }
  }

  // Unhide a product (make it visible)
  Future<void> unhideProduct(String productId) async {
    await toggleProductVisibility(productId, false);
  }

  // Hide a product (make it invisible)
  Future<void> hideProduct(String productId) async {
    await toggleProductVisibility(productId, true);
  }

  // Load all hidden products (for HiddenProductsScreen)
  Future<void> loadHiddenProducts() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('products')
          .where('isHide', isEqualTo: true)
          .get();

      hiddenProducts.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return Product.fromMap(data, id: doc.id);
      }).toList();

      hiddenProducts.refresh();
    } catch (e) {
      print('Error loading hidden products: $e');
      MessageToast.showToast(msg: 'Failed to load hidden products');
    }
  }
}
