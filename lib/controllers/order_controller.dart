import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_model.dart';
import '../utils/toas_message.dart';
import 'notifications.dart'; // Assuming this is LocalNotificationService
import 'data_controller.dart'; // Import the DataController

class OrderController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Initialize DataController for creating in-app notifications
  final DataController _dataController = Get.put(DataController());

  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final RxList<OrderModel> allOrders =
      <OrderModel>[].obs; // Store all orders for filtering
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  // --- Helper to fetch User Token (fcmToken assumed) ---
  Future<String?> _getUserToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      // Ensure you check the correct field name, using 'fcmToken' as per your provided code
      if (userDoc.exists && userDoc.data()!.containsKey('fcmToken')) {
        return userDoc.data()!['fcmToken'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching device token for user $userId: $e');
      return null;
    }
  }

  // --- Order Fetching/Filtering (Unchanged) ---
  Future<void> fetchOrders({required String orderStatus}) async {
    // ... (Your fetchOrders implementation is unchanged)
    try {
      isLoading(true);
      hasError(false);

      Query query = _firestore
          .collection('orders')
          .where('status', isEqualTo: orderStatus)
          .orderBy('orderDate', descending: true);

      final snapshot = await query.get();

      print(snapshot.docs.length);
      allOrders.assignAll(
        snapshot.docs
            .map(
              (doc) => OrderModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ),
            )
            .toList(),
      );
      orders.assignAll(allOrders); // Initially show all orders
    } catch (e) {
      hasError(true);
      errorMessage.value = e.toString();
      rethrow;
    } finally {
      isLoading(false);
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

  // --- Status Update Functions (Modified) ---

  // Updated cancelOrder method with quantity reversion
  Future<bool> cancelOrder(String orderId) async {
    try {
      isLoading(true);

      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (!orderDoc.exists) throw Exception('Order not found');

      final orderData = orderDoc.data();
      if (orderData == null) throw Exception('Order data is null');

      final currentStatus = orderData['status'];
      if (currentStatus == 'Cancelled') {
        MessageToast.showToast(msg: 'Order is already cancelled');
        return false;
      }

      // Extract userId for notifications
      final String userId = orderData['userId'] as String;
      final String displayOrderId =
          orderData['orderId'] ?? orderId; // human-readable ID

      // Revert product quantities
      Map<String, int> productQuantities = {};

      if (orderData.containsKey('productQuantities') &&
          orderData['productQuantities'] != null) {
        productQuantities = Map<String, int>.from(
          orderData['productQuantities'],
        );
      }

      if (productQuantities.isEmpty && orderData.containsKey('items')) {
        final items = List<Map<String, dynamic>>.from(orderData['items']);
        for (var item in items) {
          final productId = item['productId'];
          final quantity = item['quantity'] as int;
          productQuantities[productId] =
              (productQuantities[productId] ?? 0) + quantity;
        }
      }

      if (productQuantities.isNotEmpty) {
        await _revertProductQuantities(productQuantities);
      }

      // Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'Cancelled',
      });

      // Notification content
      const String title = 'Order Cancelled.';
      final String body = 'Your order #$displayOrderId has been cancelled.';

      // Send push notification
      final String? userToken = await _getUserToken(userId);
      if (userToken != null) {
        await LocalNotificationService.sendNotificationUsingApi(
          token: userToken,
          title: title,
          body: body,
          data: {'screen': 'order_detail', 'orderId': orderId},
        );
      } else {
        print('User token not found, skipping push notification.');
      }

      // Create in-app notification
      await _dataController.createNotification(
        message: body,
        userId: userId,
        orderId: orderId,
        isChat: false,
      );

      MessageToast.showToast(
        msg: 'Order cancelled successfully. Quantities restored.',
      );
      return true;
    } catch (e) {
      print('Error cancelling order: $e');
      MessageToast.showToast(msg: 'Failed to cancel order: ${e.toString()}');
      return false;
    } finally {
      isLoading(false);
    }
  }

  // Method to revert product quantities
  Future<void> _revertProductQuantities(
    Map<String, int> productQuantities,
  ) async {
    final batch = _firestore.batch();

    for (var entry in productQuantities.entries) {
      final productId = entry.key;
      final cancelledQuantity = entry.value;

      final productRef = _firestore.collection('products').doc(productId);
      final productDoc = await productRef.get();

      if (productDoc.exists) {
        final data = productDoc.data()!;
        final currentTotal =
            (data['totalQuantity'] as num?)?.toInt() ??
            (data['stock'] as num?)?.toInt() ??
            0;
        final currentStock = (data['stock'] as num?)?.toInt() ?? currentTotal;
        final newTotal = currentTotal + cancelledQuantity;
        final newStock = currentStock + cancelledQuantity;

        batch.update(productRef, {
          'stock': newStock,
          'totalQuantity': newTotal,
          'isOutOfStock': newStock == 0,
        });
      }
    }

    await batch.commit();
    print('Successfully reverted ${productQuantities.length} product(s)');
  }

  Future<void> updateOrderStatus({
    required String id,
    required String orderId,
    required String status,
  }) async {
    try {
      // 1. Fetch Order to get userId
      final orderDoc = await _firestore.collection('orders').doc(id).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found.');
      }
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final String userId = orderData['userId'] as String;

      // 2. Update status in Firestore
      await _firestore.collection('orders').doc(id).update({'status': status});

      // 3. Define Notification Content
      String title;
      String body;

      switch (status) {
        case 'Accepted':
          title = 'Order Accepted! 🎉';
          body =
              'Your order #$orderId has been accepted and is being prepared.';
          break;
        case 'Rejected':
          title = 'Order Rejected 😔';
          body = 'Your order #$orderId could not be fulfilled at this time.';
          break;
        case 'Delivered':
          title = 'Order Delivered! 🚚';
          body = 'Your order #$orderId has been successfully delivered.';
          break;
        case 'Cancelled':
          title = 'Order Cancelled.';
          body = 'Your order #$orderId has been successfully cancelled.';
          break;
        default:
          title = 'Order Update';
          body = 'Your order #$orderId status updated to $status.';
      }

      // 4. Send Push Notification
      final String? userToken = await _getUserToken(userId);
      if (userToken != null) {
        // Assuming LocalNotificationService is imported as 'notifications'
        await LocalNotificationService.sendNotificationUsingApi(
          token: userToken,
          title: title,
          body: body,
          data: {
            'screen': 'order_detail', // For deep-linking
            'orderId': id, // Send the Firestore Document ID
          },
        );
      } else {
        print('User token not found, skipping push notification.');
      }

      // 5. Create In-App Notification Record (for DataController listener)
      await _dataController.createNotification(
        message: body,
        userId: userId,
        orderId: id,
        isChat: false, // This is an order update, not a chat message
      );

      // 6. UI Feedback
      Get.back();
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
