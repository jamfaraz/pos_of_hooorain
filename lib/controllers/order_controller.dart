import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_model.dart';
import '../utils/toas_message.dart';
import 'notifications.dart'; // LocalNotificationService

class OrderController extends GetxController {
  static const int pageSize = 20;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final RxList<OrderModel> allOrders = <OrderModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMoreOrders = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString loadMoreError = ''.obs;
  DocumentSnapshot<Map<String, dynamic>>? _lastOrderDocument;
  int _ordersRequestId = 0;
  final Map<String, Future<String?>> _customerImageCache = {};

  /// Statuses after which an order is closed and cannot be changed again.
  static const Set<String> closedStatuses = {
    'Cancelled',
    'Rejected',
    'Returned',
  };

  // --------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------

  Future<String?> _getUserToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('fcmToken')) {
        return userDoc.data()!['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching device token for user $userId: $e');
      return null;
    }
  }

  Future<String?> getCustomerImage(String userId) {
    if (userId.isEmpty) return Future.value(null);
    return _customerImageCache.putIfAbsent(userId, () async {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final image = userDoc.data()?['image'];
      return image is String && image.isNotEmpty ? image : null;
    });
  }

  /// Product id -> quantity to put back, read from the order document.
  Map<String, int> _quantitiesFrom(Map<String, dynamic> orderData) {
    var quantities = <String, int>{};
    if (orderData['productQuantities'] != null) {
      quantities = Map<String, int>.from(orderData['productQuantities']);
    }
    if (quantities.isEmpty && orderData['items'] != null) {
      final items = List<Map<String, dynamic>>.from(orderData['items']);
      for (final item in items) {
        final productId = item['productId'];
        final quantity = (item['quantity'] ?? item['qty'] ?? 0) as int;
        quantities[productId] = (quantities[productId] ?? 0) + quantity;
      }
    }
    return quantities;
  }

  Future<void> _notifyCustomer({
    required String userId,
    required String orderDocId,
    required String title,
    required String body,
  }) async {
    final token = await _getUserToken(userId);
    if (token != null) {
      await LocalNotificationService.sendNotificationUsingApi(
        token: token,
        title: title,
        body: body,
        data: {'screen': 'order_detail', 'orderId': orderDocId},
      );
    }
  }

  // --------------------------------------------------------------------
  // Fetching / filtering
  // --------------------------------------------------------------------

  Future<void> fetchOrders({required String orderStatus}) async {
    final requestId = ++_ordersRequestId;
    try {
      isLoading(true);
      isLoadingMore(false);
      hasError(false);
      errorMessage('');
      loadMoreError('');
      hasMoreOrders(false);
      _lastOrderDocument = null;
      allOrders.clear();
      orders.clear();

      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: orderStatus)
          .orderBy('orderDate', descending: true)
          .limit(pageSize)
          .get();

      if (requestId != _ordersRequestId) return;
      final page = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      allOrders.assignAll(page);
      orders.assignAll(page);
      _lastOrderDocument = snapshot.docs.isEmpty ? null : snapshot.docs.last;
      hasMoreOrders.value = snapshot.docs.length == pageSize;
    } catch (e) {
      if (requestId != _ordersRequestId) return;
      hasError(true);
      errorMessage.value = e.toString();
      rethrow;
    } finally {
      if (requestId == _ordersRequestId) isLoading(false);
    }
  }

  Future<void> loadMoreOrders({required String orderStatus}) async {
    final cursor = _lastOrderDocument;
    if (cursor == null ||
        !hasMoreOrders.value ||
        isLoadingMore.value ||
        isLoading.value) {
      return;
    }

    final requestId = _ordersRequestId;
    isLoadingMore(true);
    loadMoreError('');
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('status', isEqualTo: orderStatus)
          .orderBy('orderDate', descending: true)
          .startAfterDocument(cursor)
          .limit(pageSize)
          .get();

      if (requestId != _ordersRequestId) return;
      final page = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
          .toList();
      allOrders.addAll(page);
      orders.addAll(page);
      if (snapshot.docs.isNotEmpty) _lastOrderDocument = snapshot.docs.last;
      hasMoreOrders.value = snapshot.docs.length == pageSize;
    } catch (e) {
      if (requestId != _ordersRequestId) return;
      loadMoreError.value = e.toString();
    } finally {
      if (requestId == _ordersRequestId) isLoadingMore(false);
    }
  }

  void filterOrdersByDateRange(DateTime startDate, DateTime endDate) {
    final adjustedEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23,
      59,
      59,
    );
    orders.value = allOrders.where((order) {
      return order.orderDate.isAfter(
            startDate.subtract(const Duration(days: 1)),
          ) &&
          order.orderDate.isBefore(
            adjustedEndDate.add(const Duration(days: 1)),
          );
    }).toList();
  }

  // --------------------------------------------------------------------
  // Closing an order (Cancelled / Rejected / Returned)
  // --------------------------------------------------------------------

  /// Shared logic: checks the current status, optionally puts the products
  /// back into stock, writes the new status + reason and notifies the customer.
  Future<bool> _closeOrder({
    required String id,
    required String status,
    required Set<String> allowedFrom,
    required String reason,
    required bool restock,
    required String title,
    required String Function(String displayId) body,
    required String successMessage,
  }) async {
    try {
      isLoading(true);
      final orderDoc = await _firestore.collection('orders').doc(id).get();
      if (!orderDoc.exists) throw Exception('Order not found');
      final data = orderDoc.data();
      if (data == null) throw Exception('Order data is null');

      final current = (data['status'] ?? '').toString();
      if (!allowedFrom.contains(current)) {
        MessageToast.showToast(
          msg: closedStatuses.contains(current)
              ? 'This order is already $current.'
              : 'An order that is $current cannot be marked $status.',
        );
        return false;
      }

      final userId = data['userId'] as String;
      final displayId = (data['orderId'] ?? id).toString();

      if (restock) {
        final quantities = _quantitiesFrom(data);
        if (quantities.isNotEmpty) await _revertProductQuantities(quantities);
      }

      await _firestore.collection('orders').doc(id).update({
        'status': status,
        'statusReason': reason,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      await _notifyCustomer(
        userId: userId,
        orderDocId: id,
        title: title,
        body: body(displayId),
      );

      MessageToast.showToast(msg: successMessage);
      return true;
    } catch (e) {
      print('Error closing order as $status: $e');
      MessageToast.showToast(msg: 'Failed to update order: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  /// Admin cancels an accepted order. Stock is restored.
  Future<bool> cancelOrder(String orderId, {String? reason}) => _closeOrder(
    id: orderId,
    status: 'Cancelled',
    allowedFrom: const {'Pending', 'Accepted'},
    reason: reason ?? 'Cancelled by admin',
    restock: true,
    title: 'Order Cancelled.',
    body: (id) => 'Your order #$id has been cancelled.',
    successMessage: 'Order cancelled. Quantities restored.',
  );

  /// Admin declines a pending order. Stock is restored.
  Future<bool> rejectOrder(String orderId, {required String reason}) =>
      _closeOrder(
        id: orderId,
        status: 'Rejected',
        allowedFrom: const {'Pending'},
        reason: reason,
        restock: true,
        title: 'Order Rejected 😔',
        body: (id) => 'Your order #$id could not be fulfilled at this time.',
        successMessage: 'Order rejected. Quantities restored.',
      );

  /// A delivered order comes back. Stock is only restored when [restock].
  Future<bool> returnOrder(
    String orderId, {
    required String reason,
    required bool restock,
  }) => _closeOrder(
    id: orderId,
    status: 'Returned',
    allowedFrom: const {'Delivered'},
    reason: reason,
    restock: restock,
    title: 'Return Received',
    body: (id) => 'We have received the return for your order #$id.',
    successMessage: restock
        ? 'Return recorded. Items added back to stock.'
        : 'Return recorded. Stock was not changed.',
  );

  Future<void> _revertProductQuantities(
    Map<String, int> productQuantities,
  ) async {
    final batch = _firestore.batch();

    for (final entry in productQuantities.entries) {
      final productRef = _firestore.collection('products').doc(entry.key);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final data = productDoc.data()!;
        final currentTotal =
            (data['totalQuantity'] as num?)?.toInt() ??
            (data['stock'] as num?)?.toInt() ??
            0;
        final currentStock = (data['stock'] as num?)?.toInt() ?? currentTotal;
        final newTotal = currentTotal + entry.value;
        final newStock = currentStock + entry.value;

        batch.update(productRef, {
          'stock': newStock,
          'totalQuantity': newTotal,
          'isOutOfStock': newStock == 0,
        });
      }
    }

    await batch.commit();
  }

  // --------------------------------------------------------------------
  // Forward status updates (Accepted / Delivered)
  // --------------------------------------------------------------------

  Future<void> updateOrderStatus({
    required String id,
    required String orderId,
    required String status,
  }) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(id).get();
      if (!orderDoc.exists) throw Exception('Order not found.');
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final String userId = orderData['userId'] as String;

      await _firestore.collection('orders').doc(id).update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      String title;
      String body;
      switch (status) {
        case 'Accepted':
          title = 'Order Accepted! 🎉';
          body =
              'Your order #$orderId has been accepted and is being prepared.';
          break;
        case 'Delivered':
          title = 'Order Delivered! 🚚';
          body = 'Your order #$orderId has been successfully delivered.';
          break;
        default:
          title = 'Order Update';
          body = 'Your order #$orderId status updated to $status.';
      }

      await _notifyCustomer(
        userId: userId,
        orderDocId: id,
        title: title,
        body: body,
      );

      // The detail screen listens to the order live, so it stays open and
      // shows the new status by itself.
      MessageToast.showToast(
        msg: 'Order status updated to $status successfully.',
      );
    } catch (e) {
      MessageToast.showToast(
        msg: 'Failed to update order status: ${e.toString()}',
      );
    }
  }
}
