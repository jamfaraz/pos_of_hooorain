import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_record.dart';

class ExpensePage {
  const ExpensePage({required this.items, required this.cursor, required this.hasMore});

  final List<ExpenseRecord> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

/// All Firestore access for expenses. Controllers never call Firestore directly.
/// Queries use a single field (createdAt), so no composite index is needed.
class ExpenseService {
  ExpenseService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _expenses => _db.collection('expenses');
  DocumentReference<Map<String, dynamic>> get _budgetDoc =>
      _db.collection('settings').doc('expense_budgets');

  Future<ExpensePage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _expenses
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (after != null) query = query.startAfterDocument(after);
    final snapshot = await query.get();
    return ExpensePage(
      items: [
        for (final doc in snapshot.docs) ExpenseRecord.fromMap(doc.data(), id: doc.id),
      ],
      cursor: snapshot.docs.isEmpty ? after : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }

  /// Expenses from [from] (inclusive) to [to] (exclusive), newest first.
  Future<List<ExpenseRecord>> fetchRange(
    DateTime from,
    DateTime to, {
    int limit = 500,
  }) async {
    final snapshot = await _expenses
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('createdAt', isLessThan: Timestamp.fromDate(to))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [
      for (final doc in snapshot.docs) ExpenseRecord.fromMap(doc.data(), id: doc.id),
    ];
  }

  Future<void> save(ExpenseRecord expense) async {
    if (expense.id == null) {
      await _expenses.add(expense.toMap());
    } else {
      await _expenses.doc(expense.id).update(expense.toMap());
    }
  }

  Future<void> delete(String id) => _expenses.doc(id).delete();

  Future<Map<String, double>> getBudgets() async {
    final snapshot = await _budgetDoc.get();
    final raw = snapshot.data()?['budgets'];
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          '${entry.key}': (entry.value as num?)?.toDouble() ?? 0,
      };
    }
    return {...kDefaultExpenseBudgets};
  }

  Future<void> saveBudgets(Map<String, double> budgets) => _budgetDoc.set({
    'budgets': budgets,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
