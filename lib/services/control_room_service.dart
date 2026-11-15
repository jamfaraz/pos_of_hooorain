import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_record.dart';
import '../models/offer_record.dart';
import '../models/order_record.dart';
import '../models/product_record.dart';
import '../models/rider_invite_record.dart';
import '../models/rider_record.dart';

class ControlRoomService {
  ControlRoomService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const pageSize = 30;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPage(
    String collection, {
    String orderBy = 'createdAt',
    bool descending = true,
  }) => _firestore
      .collection(collection)
      .orderBy(orderBy, descending: descending)
      .limit(pageSize)
      .snapshots();

  Future<QuerySnapshot<Map<String, dynamic>>> fetchPage(
    String collection, {
    DocumentSnapshot<Map<String, dynamic>>? after,
    String orderBy = 'createdAt',
    bool descending = true,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(collection)
        .orderBy(orderBy, descending: descending);
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(pageSize).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchSimplePage(
    String collection, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(collection);
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(pageSize).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOffers() =>
      _firestore.collection('offers').limit(pageSize).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCategories() =>
      _firestore.collection('categories').limit(pageSize).snapshots();

  Future<QuerySnapshot<Map<String, dynamic>>> fetchCategoryPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('categories')
        .orderBy(FieldPath.documentId);
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(pageSize).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProducts() => _firestore
      .collection('products')
      .orderBy('name')
      .limit(pageSize)
      .snapshots();

  Future<QuerySnapshot<Map<String, dynamic>>> fetchProductPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('products')
        .orderBy('name');
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(pageSize).get();
  }

  String newBillNumber() => _firestore.collection('bills').doc().id;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRiders() => _firestore
      .collection('riders')
      .orderBy('name')
      .limit(pageSize)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRiderInvites() => _firestore
      .collection('riderInvites')
      .orderBy('sentAt', descending: true)
      .limit(pageSize)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentOrders() =>
      _firestore.collection('orders').limit(pageSize).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOrdersByDateField(
    String field,
  ) => _firestore
      .collection('orders')
      .orderBy(field, descending: true)
      .limit(pageSize)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentBills() =>
      _firestore.collection('bills').limit(pageSize).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCustomers() =>
      _firestore.collection('users').limit(pageSize).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStockMovements() =>
      _firestore
          .collection('stockMovements')
          .orderBy('createdAt', descending: true)
          .limit(pageSize)
          .snapshots();

  Future<String> saveProduct(ProductRecord product) async {
    final ref = product.id == null
        ? _firestore.collection('products').doc()
        : _firestore.collection('products').doc(product.id);
    await ref.set({
      ...product.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteProduct(String id) =>
      _firestore.collection('products').doc(id).delete();

  Future<String> saveCategory(CategoryRecord category) async {
    final ref = category.id == null
        ? _firestore.collection('categories').doc()
        : _firestore.collection('categories').doc(category.id);
    final oldName = category.id == null
        ? null
        : (await ref.get()).data()?['name'] as String?;
    await ref.set(category.toMap(), SetOptions(merge: true));
    if (oldName != null && oldName != category.name) {
      await renameCategoryProducts(category.id!, oldName, category.name);
    }
    return ref.id;
  }

  Future<void> renameCategoryProducts(
    String categoryId,
    String oldName,
    String name,
  ) async {
    for (final field in ['categoryId', 'category']) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('products')
          .where(field, isEqualTo: field == 'categoryId' ? categoryId : oldName)
          .limit(400);
      while (true) {
        final page = await query.get();
        if (page.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.update(doc.reference, {
            field: field == 'categoryId' ? categoryId : name,
          });
        }
        await batch.commit();
        if (page.docs.length < 400) break;
        query = _firestore
            .collection('products')
            .where(
              field,
              isEqualTo: field == 'categoryId' ? categoryId : oldName,
            )
            .startAfterDocument(page.docs.last)
            .limit(400);
      }
    }
  }

  Future<bool> categoryHasProducts(String id) async {
    final results = await Future.wait([
      _firestore
          .collection('products')
          .where('categoryId', isEqualTo: id)
          .limit(1)
          .get(),
      _firestore
          .collection('products')
          .where('category', isEqualTo: id)
          .limit(1)
          .get(),
    ]);
    return results.any((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<bool> categoryHasBanners(String id) async =>
      (await _firestore
              .collection('banners')
              .where('targetCategoryId', isEqualTo: id)
              .limit(1)
              .get())
          .docs
          .isNotEmpty;

  Future<void> deleteCategory(String id) async {
    if (await categoryHasProducts(id) || await categoryHasBanners(id)) {
      throw StateError(
        'Move its products and banners before deleting this category.',
      );
    }
    await _firestore.collection('categories').doc(id).delete();
  }

  Future<String> saveOffer(OfferRecord offer) async {
    final ref = offer.id == null
        ? _firestore.collection('offers').doc()
        : _firestore.collection('offers').doc(offer.id);
    await ref.set(offer.toMap(), SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteOffer(String id) =>
      _firestore.collection('offers').doc(id).delete();

  Future<void> saveRider(RiderRecord rider) async {
    final ref = rider.id == null
        ? _firestore.collection('riders').doc()
        : _firestore.collection('riders').doc(rider.id);
    await ref.set(rider.toMap(), SetOptions(merge: true));
  }

  Future<String> createRiderInvite(RiderInviteRecord invite) async {
    final ref = _firestore.collection('riderInvites').doc();
    await ref.set(invite.toMap());
    return ref.id;
  }

  Future<void> cancelRiderInvite(String id) => _firestore
      .collection('riderInvites')
      .doc(id)
      .update({'status': 'cancelled'});

  Future<void> markInviteJoined(RiderInviteRecord invite) async {
    if (invite.id == null) throw StateError('Invite has no document ID.');
    await _firestore.runTransaction((transaction) async {
      final inviteRef = _firestore.collection('riderInvites').doc(invite.id);
      final inviteSnapshot = await transaction.get(inviteRef);
      if (!inviteSnapshot.exists ||
          inviteSnapshot.data()?['status'] != 'pending') {
        throw StateError('This invite is no longer pending.');
      }
      final riderRef = _firestore.collection('riders').doc();
      transaction.set(
        riderRef,
        RiderRecord(
          name: invite.name,
          phone: invite.phone,
          baseSalary: invite.baseSalary,
          perDeliveryBonus: invite.perDeliveryBonus,
          joinedAt: DateTime.now(),
        ).toMap(),
      );
      transaction.update(inviteRef, {'status': 'joined'});
    });
  }

  Future<int> getMonthlyDeliveryCount(String riderId, DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    Future<int> countFor(String status) async {
      final result = await _firestore
          .collection('orders')
          .where('riderId', isEqualTo: riderId)
          .where('status', isEqualTo: status)
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThan: end)
          .count()
          .get();
      return result.count ?? 0;
    }

    final counts = await Future.wait([
      countFor('Delivered'),
      countFor('delivered'),
    ]);
    return counts[0] + counts[1];
  }

  Future<bool> isSalaryPaid(String riderId, String monthId) async =>
      (await _firestore
              .collection('riders')
              .doc(riderId)
              .collection('salaryPayments')
              .doc(monthId)
              .get())
          .exists;

  Future<void> resendRiderInvite(String id) => _firestore
      .collection('riderInvites')
      .doc(id)
      .update({'sentAt': FieldValue.serverTimestamp()});

  Future<void> deleteRider(String id) =>
      _firestore.collection('riders').doc(id).delete();

  Future<List<Map<String, dynamic>>> getSalaryHistory(String riderId) async {
    final snapshot = await _firestore
        .collection('riders')
        .doc(riderId)
        .collection('salaryPayments')
        .orderBy('paidAt', descending: true)
        .limit(12)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> giveRiderAdvance(String riderId, double amount) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be positive.');
    }
    final ref = _firestore.collection('riders').doc(riderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Rider no longer exists.');
      final current = (snapshot.data()?['advance'] as num?)?.toDouble() ?? 0;
      transaction.update(ref, {'advance': current + amount});
    });
  }

  Future<void> payRiderSalary({
    required RiderRecord rider,
    required String monthId,
    required double amount,
  }) async {
    if (rider.id == null) throw StateError('Rider has no document ID.');
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'Cannot be negative.');
    }
    final riderRef = _firestore.collection('riders').doc(rider.id);
    final paymentRef = riderRef.collection('salaryPayments').doc(monthId);
    final expenseRef = _firestore.collection('expenses').doc();
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(riderRef);
      if (!snapshot.exists) throw StateError('Rider no longer exists.');
      if ((await transaction.get(paymentRef)).exists) {
        throw StateError('Salary for this month is already marked paid.');
      }
      transaction.set(paymentRef, {
        'month': monthId,
        'amount': amount,
        'paidAt': FieldValue.serverTimestamp(),
      });
      transaction.update(riderRef, {'advance': 0});
      transaction.set(expenseRef, {
        'category': 'Salaries',
        'note': 'Salary payment for ${rider.name} ($monthId)',
        'amount': amount,
        'paidBy': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> addStock(String productId, int quantity, String note) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be positive.');
    }
    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('products').doc(productId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Product no longer exists.');
      final stock =
          (snapshot.data()?['stock'] as num?)?.toInt() ??
          (snapshot.data()?['totalQuantity'] as num?)?.toInt() ??
          0;
      transaction.update(ref, {
        'stock': stock + quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final movement = _firestore.collection('stockMovements').doc();
      transaction.set(movement, {
        'productId': productId,
        'type': 'purchase',
        'qty': quantity,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> createOrder(OrderRecord order) async {
    final collection = _firestore.collection(
      order.channel == 'counter' ? 'bills' : 'orders',
    );
    final orderRef = order.number.isEmpty
        ? collection.doc()
        : collection.doc(order.number);
    await _firestore.runTransaction((transaction) async {
      final productSnapshots =
          <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final line in order.items) {
        if (productSnapshots.containsKey(line.productId)) continue;
        final productRef = _firestore
            .collection('products')
            .doc(line.productId);
        productSnapshots[line.productId] = await transaction.get(productRef);
      }
      final lines = <Map<String, dynamic>>[];
      final quantities = <String, int>{};
      for (final line in order.items) {
        final product = productSnapshots[line.productId];
        if (product == null || !product.exists) {
          throw StateError('A product in this sale no longer exists.');
        }
        final data = product.data()!;
        lines.add({
          ...line.toMap(),
          'costAtSale': (data['cost'] as num?)?.toDouble() ?? 0,
        });
        quantities.update(
          line.productId,
          (quantity) => quantity + line.qty,
          ifAbsent: () => line.qty,
        );
      }
      for (final entry in quantities.entries) {
        final product = productSnapshots[entry.key]!;
        final data = product.data()!;
        final stock =
            (data['stock'] as num?)?.toInt() ??
            (data['totalQuantity'] as num?)?.toInt() ??
            0;
        if (stock < entry.value) {
          throw StateError(
            'Insufficient stock for ${data['name'] ?? entry.key}.',
          );
        }
        transaction.update(product.reference, {
          'stock': stock - entry.value,
          'totalQuantity': stock - entry.value,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(orderRef, {
        ...order.toMap(),
        'number': order.number.isEmpty ? orderRef.id : order.number,
        'orderId': order.number.isEmpty ? orderRef.id : order.number,
        'items': lines,
        'productIds': order.items
            .map((line) => line.productId)
            .toSet()
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return orderRef.id;
  }

  Future<void> updateOrder(String id, Map<String, dynamic> changes) =>
      _firestore.collection('orders').doc(id).update(changes);

  Future<void> assignOrderRider(String orderId, String? riderId) => _firestore
      .collection('orders')
      .doc(orderId)
      .update({'riderId': riderId, 'updatedAt': FieldValue.serverTimestamp()});

  Future<bool> hasSalesHistory(String productId) async {
    final result = await Future.wait([
      _firestore
          .collection('orders')
          .where('productIds', arrayContains: productId)
          .limit(1)
          .get(),
      _firestore
          .collection('bills')
          .where('productIds', arrayContains: productId)
          .limit(1)
          .get(),
    ]);
    if (result.any((snapshot) => snapshot.docs.isNotEmpty)) return true;
    final legacyCollections = await Future.wait([
      _firestore.collection('orders').limit(1).get(),
      _firestore.collection('bills').limit(1).get(),
    ]);
    return legacyCollections.any((snapshot) => snapshot.docs.isNotEmpty);
  }
}
