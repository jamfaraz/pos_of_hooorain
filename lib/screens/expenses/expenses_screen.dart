import 'dart:math' as math;

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/expense_controller.dart';
import '../../models/expense_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_table.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/shimmer_skeletons.dart';
import '../../widgets/side_drawer.dart';
import '../../widgets/status_chip.dart';

class ExpensesScreen extends GetView<ExpenseController> {
  const ExpensesScreen({super.key});

  static const _subtitle = 'Everything you spend to run the shop, so profit is real.';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Obx(() {
      if (controller.loading.value) return _skeleton();
      if (controller.error.value != null && controller.expenses.isEmpty) {
        return ErrorRetryWidget(
          errorMessage: controller.error.value!,
          onRetry: controller.reload,
        );
      }
      final wide = constraints.maxWidth >= 1000;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Expenses',
            subtitle: _subtitle,
            actions: [
              AppButton(
                label: 'Add expense',
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => _openEditor(context),
              ),
            ],
          ),
          _kpis(constraints.maxWidth),
          const SizedBox(height: 16),
          _filters(),
          const SizedBox(height: 12),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _tableCard(context)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 360,
                        child: SingleChildScrollView(child: _budgetCard(context)),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      SizedBox(height: 560, child: _tableCard(context)),
                      const SizedBox(height: 16),
                      _budgetCard(context),
                    ],
                  ),
          ),
        ],
      );
    }),
  );

  // ------------------------------------------------------------------ pieces

  Widget _skeleton() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeader(title: 'Expenses', subtitle: _subtitle),
      ShimmerKpiRow(),
      SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(child: ShimmerTable())),
    ],
  );

  Widget _kpis(double width) {
    final cols = width > 1000
        ? 4
        : width > 620
        ? 2
        : 1;
    final top = controller.topCategory;
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: cols == 1 ? 3.2 : 2.2,
      children: [
        KpiCard(
          label: 'Spent this month',
          value: Money.rs(controller.monthTotal),
          caption: '${controller.monthExpenses.length} entries',
          icon: PhosphorIconsRegular.wallet,
        ),
        KpiCard(
          label: 'Spent today',
          value: Money.rs(controller.todayTotal),
          icon: PhosphorIconsRegular.calendarBlank,
        ),
        KpiCard(
          label: 'Biggest cost',
          value: top == null ? '—' : Money.rs(top.value),
          caption: top?.key,
          icon: PhosphorIconsRegular.chartPieSlice,
        ),
        KpiCard(
          label: 'Daily average',
          value: Money.rs(controller.dailyAverage),
          caption: 'This month so far',
          icon: PhosphorIconsRegular.trendUp,
        ),
      ],
    );
  }

  Widget _filters() {
    final tabs = ['All', ...controller.categories];
    final selected = controller.category.value.isEmpty
        ? 0
        : math.max(0, tabs.indexOf(controller.category.value));
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: (value) => controller.search.value = value,
            decoration: const InputDecoration(
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              hintText: 'Search note, category, payment',
              isDense: true,
            ),
          ),
        ),
        SegmentedTabs(
          tabs: tabs,
          selectedIndex: selected,
          onChanged: (index) =>
              controller.category.value = index == 0 ? '' : tabs[index],
        ),
      ],
    );
  }

  Widget _tableCard(BuildContext context) {
    final theme = Theme.of(context);
    final rows = controller.filtered;
    final dateFormat = DateFormat('d MMM yyyy');
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All expenses',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${rows.length} shown',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: AppTable(
              minWidth: 860,
              emptyState: EmptyState(
                title: 'No expenses found',
                message: 'Add an expense, or clear the filters.',
                icon: PhosphorIconsRegular.wallet,
                actionLabel: 'Add expense',
                onAction: () => _openEditor(context),
              ),
              columns: const [
                DataColumn2(label: Text('Date'), size: ColumnSize.S),
                DataColumn2(label: Text('Category'), size: ColumnSize.M),
                DataColumn2(label: Text('Note'), size: ColumnSize.L),
                DataColumn2(label: Text('Paid by'), size: ColumnSize.S),
                DataColumn2(label: Text('Amount'), numeric: true),
                DataColumn2(label: Text('Actions'), fixedWidth: 190),
              ],
              rows: [
                for (final e in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(dateFormat.format(e.createdAt))),
                      DataCell(
                        StatusChip(
                          label: e.category,
                          tone: e.category == 'Salaries'
                              ? StatusTone.info
                              : StatusTone.primary,
                        ),
                      ),
                      DataCell(
                        Text(
                          e.note.isEmpty ? '—' : e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(Text(e.paidBy)),
                      DataCell(
                        Text(
                          Money.rs(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit expense',
                              onPressed: () => _openEditor(context, e),
                              icon: const Icon(PhosphorIconsRegular.pencilSimple),
                            ),
                            const SizedBox(width: 4),
                            ConfirmTapButton(
                              label: 'Delete',
                              confirmLabel: 'Delete',
                              confirmTitle: 'Delete expense?',
                              confirmMessage:
                                  'This expense will be removed and profit reports will change.',
                              onConfirmed: () async {
                                try {
                                  await controller.delete(e);
                                } catch (exception) {
                                  Get.snackbar(
                                    'Could not delete expense',
                                    exception.toString(),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (controller.canLoadMore.value)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: controller.loadingMore.value ? null : controller.loadMore,
                child: Text(
                  controller.loadingMore.value ? 'Loading…' : 'Load more expenses',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context) {
    final theme = Theme.of(context);
    final spent = controller.spentByCategory;
    final categories = {
      ...kExpenseCategories,
      ...spent.keys,
      ...controller.budgets.keys,
    }.toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly budget',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Spent this month vs usual spend',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _openBudgets(context),
                icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final category in categories)
            _budgetRow(
              context,
              category,
              spent[category] ?? 0,
              controller.budgets[category] ?? 0,
            ),
          const Divider(),
          Row(
            children: [
              const Expanded(
                child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text(
                '${Money.rs(controller.monthTotal)} / ${Money.rs(controller.budgetTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _budgetRow(
    BuildContext context,
    String category,
    double spent,
    double budget,
  ) {
    final theme = Theme.of(context);
    final ratio = budget > 0 ? spent / budget : (spent > 0 ? 1.0 : 0.0);
    final color = ratio > 1
        ? theme.colorScheme.error
        : ratio > .8
        ? const Color(0xFFE9A23B)
        : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${Money.rs(spent)} / ${Money.rs(budget)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- drawers

  String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _openEditor(BuildContext context, [ExpenseRecord? existing]) async {
    final note = TextEditingController(text: existing?.note ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : _plain(existing.amount),
    );
    final category = (existing?.category ?? kExpenseCategories.first).obs;
    final method = (existing?.paidBy ?? kPaymentMethods.first).obs;
    final date = (existing?.createdAt ?? DateTime.now()).obs;
    final error = RxnString();
    final saving = false.obs;
    final categoryOptions = <String>{
      ...kExpenseCategories,
      if (existing != null) existing.category,
    }.toList();
    final methodOptions = <String>{
      ...kPaymentMethods,
      if (existing != null) existing.paidBy,
    }.toList();

    Future<void> save() async {
      final value = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
      if (value <= 0) {
        error.value = 'Enter an amount greater than zero.';
        return;
      }
      saving.value = true;
      error.value = null;
      try {
        final picked = date.value;
        final base = existing?.createdAt ?? DateTime.now();
        await controller.save(
          ExpenseRecord(
            id: existing?.id,
            category: category.value,
            note: note.text.trim(),
            amount: value,
            paidBy: method.value,
            createdAt: DateTime(
              picked.year,
              picked.month,
              picked.day,
              base.hour,
              base.minute,
            ),
          ),
        );
        if (context.mounted) Navigator.of(context).pop();
      } catch (exception) {
        error.value = exception.toString();
      } finally {
        saving.value = false;
      }
    }

    final drawer = SideDrawer(
      title: existing == null ? 'Add expense' : 'Edit expense',
      subtitle: 'Expenses are subtracted from profit in reports.',
      width: 520,
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommonDropdown<String>(
              label: 'Category',
              value: category.value,
              items: [
                for (final c in categoryOptions)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (value) {
                if (value != null) category.value = value;
              },
            ),
            PrimaryTextField(
              controller: note,
              headerText: 'Note',
              hintText: 'What was it for?',
              optional: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PrimaryTextField(
                    controller: amount,
                    headerText: 'Amount (Rs)',
                    hintText: '0',
                    required: true,
                    fieldType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CommonDropdown<String>(
                    label: 'Paid by',
                    value: method.value,
                    bottomSpacing: 0,
                    items: [
                      for (final m in methodOptions)
                        DropdownMenuItem(value: m, child: Text(m)),
                    ],
                    onChanged: (value) {
                      if (value != null) method.value = value;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Date', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date.value,
                  firstDate: DateTime(now.year - 3),
                  lastDate: now.add(const Duration(days: 1)),
                );
                if (picked != null) date.value = picked;
              },
              icon: const Icon(PhosphorIconsRegular.calendarBlank, size: 18),
              label: Text(DateFormat('EEE, d MMM yyyy').format(date.value)),
            ),
            if (error.value != null) ...[
              const SizedBox(height: 12),
              Text(
                error.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      footer: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Cancel',
              style: AppButtonStyle.ghost,
              onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: saving.value ? 'Saving…' : 'Save expense',
              icon: const Icon(PhosphorIconsRegular.check),
              onPressed: saving.value ? null : save,
            ),
          ],
        ),
      ),
    );
    await SideDrawer.show<void>(drawer);
    note.dispose();
    amount.dispose();
  }

  Future<void> _openBudgets(BuildContext context) async {
    final categories = {...kExpenseCategories, ...controller.budgets.keys}.toList();
    final fields = {
      for (final c in categories)
        c: TextEditingController(text: _plain(controller.budgets[c] ?? 0)),
    };
    final saving = false.obs;

    Future<void> save() async {
      saving.value = true;
      try {
        await controller.saveBudgets({
          for (final c in categories)
            c: double.tryParse(fields[c]!.text.replaceAll(',', '').trim()) ?? 0,
        });
        if (context.mounted) Navigator.of(context).pop();
      } catch (exception) {
        Get.snackbar('Could not save budgets', exception.toString());
      } finally {
        saving.value = false;
      }
    }

    final drawer = SideDrawer(
      title: 'Monthly budgets',
      subtitle: 'The usual spend per category, in Rs.',
      width: 480,
      body: Column(
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PrimaryTextField(
                controller: fields[c]!,
                headerText: c,
                hintText: '0',
                fieldType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
        ],
      ),
      footer: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              label: 'Cancel',
              style: AppButtonStyle.ghost,
              onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: saving.value ? 'Saving…' : 'Save budgets',
              icon: const Icon(PhosphorIconsRegular.check),
              onPressed: saving.value ? null : save,
            ),
          ],
        ),
      ),
    );
    await SideDrawer.show<void>(drawer);
    for (final field in fields.values) {
      field.dispose();
    }
  }
}
