import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_record.dart';

class InventoryService {
  InventoryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProducts() =>
      _firestore.collection('products').orderBy('name').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchStockMovements() =>
      _firestore
          .collection('stockMovements')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<void> addStock(String productId, int quantity, String note) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be positive.');
    }
    await _firestore.runTransaction((transaction) async {
      final ref = _firestore.collection('products').doc(productId);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw StateError('Product no longer exists.');
      final data = snapshot.data();
      final stock =
          (data?['stock'] as num?)?.toInt() ??
          (data?['totalQuantity'] as num?)?.toInt() ??
          0;
      transaction.update(ref, {
        'stock': stock + quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(_firestore.collection('stockMovements').doc(), {
        'productId': productId,
        'type': 'purchase',
        'qty': quantity,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static double stockValue(Iterable<ProductRecord> products) => products.fold(
    0.0,
    (total, product) =>
        total +
        (product.stock > 0
            ? product.stock.toDouble() * product.inventoryCost
            : 0.0),
  );
}
