import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/expense_record.dart';
import '../services/expense_service.dart';

class ExpenseController extends GetxController {
  ExpenseController(this._service);

  final ExpenseService _service;

  final expenses = <ExpenseRecord>[].obs; // paged list for the table
  final monthExpenses =
      <ExpenseRecord>[].obs; // this month, for KPIs and budgets
  final budgets = <String, double>{}.obs;

  final loading = true.obs;
  final loadingMore = false.obs;
  final canLoadMore = false.obs;
  final error = RxnString();
  final loadMoreError = RxnString();

  final category = ''.obs; // '' means all categories
  final search = ''.obs;

  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    loading.value = true;
    error.value = null;
    loadMoreError.value = null;
    _cursor = null;
    try {
      final now = DateTime.now();
      final page = await _service.fetchPage();
      final month = await _service.fetchRange(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      );
      final saved = await _service.getBudgets();
      expenses.assignAll(page.items);
      monthExpenses.assignAll(month);
      budgets.assignAll(saved);
      _cursor = page.cursor;
      canLoadMore.value = page.hasMore;
    } catch (exception) {
      error.value = exception.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !canLoadMore.value) return;
    loadingMore.value = true;
    loadMoreError.value = null;
    try {
      final page = await _service.fetchPage(after: _cursor);
      expenses.addAll(page.items);
      _cursor = page.cursor;
      canLoadMore.value = page.hasMore;
    } catch (exception) {
      loadMoreError.value = exception.toString();
    } finally {
      loadingMore.value = false;
    }
  }

  Future<void> save(ExpenseRecord expense) async {
    await _service.save(expense);
    await reload();
  }

  Future<void> delete(ExpenseRecord expense) async {
    final id = expense.id;
    if (id == null) return;
    await _service.delete(id);
    await reload();
  }

  Future<void> saveBudgets(Map<String, double> values) async {
    await _service.saveBudgets(values);
    budgets.assignAll(values);
  }

  // ---------------------------------------------------------------- derived

  List<ExpenseRecord> get filtered {
    final query = search.value.trim().toLowerCase();
    final selected = category.value;
    return expenses.where((e) {
      if (selected.isNotEmpty && e.category != selected) return false;
      if (query.isEmpty) return true;
      return e.note.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.paidBy.toLowerCase().contains(query);
    }).toList();
  }

  List<String> get categories => {
    ...kExpenseCategories,
    ...expenses.map((e) => e.category),
    ...monthExpenses.map((e) => e.category),
  }.toList();

  double get monthTotal => monthExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get todayTotal {
    final now = DateTime.now();
    return monthExpenses
        .where(
          (e) =>
              e.createdAt.year == now.year &&
              e.createdAt.month == now.month &&
              e.createdAt.day == now.day,
        )
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get dailyAverage => monthTotal / DateTime.now().day;

  Map<String, double> get spentByCategory {
    final result = <String, double>{};
    for (final e in monthExpenses) {
      result[e.category] = (result[e.category] ?? 0) + e.amount;
    }
    return result;
  }

  MapEntry<String, double>? get topCategory {
    final spent = spentByCategory;
    if (spent.isEmpty) return null;
    return spent.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  double get budgetTotal => budgets.values.fold(0.0, (sum, v) => sum + v);
}
