import 'dart:math' as math;

import 'package:get/get.dart';

import '../models/expense_record.dart';
import '../services/expense_service.dart';

enum ExpenseSort { newest, oldest, amountHigh, amountLow }

extension ExpenseSortLabel on ExpenseSort {
  String get label => switch (this) {
    ExpenseSort.newest => 'Newest first',
    ExpenseSort.oldest => 'Oldest first',
    ExpenseSort.amountHigh => 'Amount: high to low',
    ExpenseSort.amountLow => 'Amount: low to high',
  };

  /// Date sorts are shown grouped by day.
  bool get byDate => this == ExpenseSort.newest || this == ExpenseSort.oldest;
}

class ExpenseController extends GetxController {
  ExpenseController(this._service);

  final ExpenseService _service;

  static const pageSize = 40;

  /// First day of the month being viewed.
  final month = DateTime(DateTime.now().year, DateTime.now().month).obs;
  final monthExpenses = <ExpenseRecord>[].obs;
  final prevMonthExpenses = <ExpenseRecord>[].obs;
  final budgets = <String, double>{}.obs;

  final loading = true.obs;
  final loadedOnce = false.obs;
  final error = RxnString();

  // Filters (applied to the loaded month)
  final category = ''.obs; // '' means all categories
  final paidBy = ''.obs; // '' means any
  final search = ''.obs;
  final sort = ExpenseSort.newest.obs;
  final visible = pageSize.obs;

  int _version = 0;

  @override
  void onInit() {
    super.onInit();
    for (final rx in [category, paidBy, search]) {
      ever(rx, (_) => visible.value = pageSize);
    }
    ever(sort, (_) => visible.value = pageSize);
    reload();
  }

  // ----------------------------------------------------------------- loading

  Future<void> reload() async {
    final version = ++_version;
    loading.value = true;
    error.value = null;
    try {
      final m = month.value;
      final from = DateTime(m.year, m.month);
      final to = DateTime(m.year, m.month + 1);
      final current = _service.fetchRange(from, to);
      final previous = _service.fetchRange(DateTime(m.year, m.month - 1), from);
      final saved = _service.getBudgets();
      final currentRows = await current;
      final previousRows = await previous;
      final savedBudgets = await saved;
      if (version != _version) return; // a newer request replaced this one
      monthExpenses.assignAll(currentRows);
      prevMonthExpenses.assignAll(previousRows);
      budgets.assignAll(savedBudgets);
      loadedOnce.value = true;
      visible.value = pageSize;
    } catch (exception) {
      if (version == _version) error.value = exception.toString();
    } finally {
      if (version == _version) loading.value = false;
    }
  }

  void setMonth(DateTime value) {
    month.value = DateTime(value.year, value.month);
    reload();
  }

  void previousMonth() =>
      setMonth(DateTime(month.value.year, month.value.month - 1));

  void nextMonth() {
    if (!canGoNext) return;
    setMonth(DateTime(month.value.year, month.value.month + 1));
  }

  void thisMonth() => setMonth(DateTime.now());

  void showMore() => visible.value += pageSize;

  void clearFilters() {
    category.value = '';
    paidBy.value = '';
    search.value = '';
    sort.value = ExpenseSort.newest;
  }

  Future<void> save(ExpenseRecord expense) async {
    await _service.save(expense);
    // Jump to the month of the saved expense so the user sees it.
    final d = expense.createdAt;
    month.value = DateTime(d.year, d.month);
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

  bool get isCurrentMonth {
    final now = DateTime.now();
    return month.value.year == now.year && month.value.month == now.month;
  }

  bool get canGoNext {
    final now = DateTime.now();
    final m = month.value;
    return m.year < now.year || (m.year == now.year && m.month < now.month);
  }

  int get daysInMonth =>
      DateTime(month.value.year, month.value.month + 1, 0).day;

  /// Days that have passed in the viewed month (whole month if it is over).
  int get daysElapsed => isCurrentMonth ? DateTime.now().day : daysInMonth;

  double get monthTotal => monthExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get prevTotal =>
      prevMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Change vs last month in percent, or null when there is no last month data.
  double? get deltaPercent =>
      prevTotal <= 0 ? null : (monthTotal - prevTotal) / prevTotal * 100;

  double get todayTotal {
    if (!isCurrentMonth) return 0;
    final now = DateTime.now();
    return monthExpenses
        .where((e) => e.createdAt.day == now.day)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double get dailyAverage => monthTotal / math.max(1, daysElapsed);

  /// Expected total at the end of the month at the current pace.
  double get projected =>
      isCurrentMonth ? dailyAverage * daysInMonth : monthTotal;

  List<double> get dailyTotals {
    final totals = List<double>.filled(daysInMonth, 0);
    for (final e in monthExpenses) {
      final index = e.createdAt.day - 1;
      if (index >= 0 && index < totals.length) totals[index] += e.amount;
    }
    return totals;
  }

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

  /// Share of the whole monthly budget used so far (can exceed 1).
  double get budgetUsed => budgetTotal <= 0 ? 0 : monthTotal / budgetTotal;

  List<String> get categories => {
    ...kExpenseCategories,
    ...budgets.keys,
    ...monthExpenses.map((e) => e.category),
  }.toList();

  List<String> get paymentMethods =>
      {...kPaymentMethods, ...monthExpenses.map((e) => e.paidBy)}.toList();

  bool get hasFilters =>
      category.value.isNotEmpty ||
      paidBy.value.isNotEmpty ||
      search.value.trim().isNotEmpty;

  /// Month expenses after search, category and payment filters, sorted.
  List<ExpenseRecord> get filtered {
    final query = search.value.trim().toLowerCase();
    final selected = category.value;
    final method = paidBy.value;
    final list = monthExpenses.where((e) {
      if (selected.isNotEmpty && e.category != selected) return false;
      if (method.isNotEmpty && e.paidBy != method) return false;
      if (query.isEmpty) return true;
      return e.note.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.paidBy.toLowerCase().contains(query);
    }).toList();
    switch (sort.value) {
      case ExpenseSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ExpenseSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case ExpenseSort.amountHigh:
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case ExpenseSort.amountLow:
        list.sort((a, b) => a.amount.compareTo(b.amount));
    }
    return list;
  }

  double get filteredTotal => filtered.fold(0.0, (sum, e) => sum + e.amount);
}
