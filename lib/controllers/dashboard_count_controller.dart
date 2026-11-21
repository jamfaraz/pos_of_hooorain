import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class DashboardCountsController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final customersCount = 0.obs;
  final productsCount = 0.obs;

  final isLoadingCustomers = true.obs;
  final isLoadingProducts = true.obs;

  StreamSubscription<QuerySnapshot>? _customersSub;
  StreamSubscription<QuerySnapshot>? _productsSub;

  @override
  void onInit() {
    super.onInit();
    _listenCustomers();
    _listenProducts();
  }

  void _listenCustomers() {
    isLoadingCustomers.value = true;
    _customersSub?.cancel();
    _customersSub = _firestore
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
            customersCount.value = snapshot.size;
            isLoadingCustomers.value = false;
          },
          onError: (e) {
            print('Error listening to customers count: $e');
            isLoadingCustomers.value = false;
          },
        );
  }

  void _listenProducts() {
    isLoadingProducts.value = true;
    _productsSub?.cancel();
    _productsSub = _firestore
        .collection('products')
        .snapshots()
        .listen(
          (snapshot) {
            productsCount.value = snapshot.size;
            isLoadingProducts.value = false;
          },
          onError: (e) {
            print('Error listening to products count: $e');
            isLoadingProducts.value = false;
          },
        );
  }

  /// Optional: manual refresh (e.g. pull-to-refresh)
  void refreshCounts() {
    _listenCustomers();
    _listenProducts();
  }

  @override
  void onClose() {
    _customersSub?.cancel();
    _productsSub?.cancel();
    super.onClose();
  }
}
