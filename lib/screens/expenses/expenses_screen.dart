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
import '../../widgets/app_loader.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/side_drawer.dart';
import '../../widgets/status_chip.dart';

class ExpensesScreen extends GetView<ExpenseController> {
  const ExpensesScreen({super.key});

  static const _subtitle =
      'Everything you spend to run the shop, so profit is real.';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Obx(() {
      final wide = constraints.maxWidth >= 1000;
      final tableWidth = wide
          ? constraints.maxWidth - 376
          : constraints.maxWidth;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Expenses',
              subtitle: _subtitle,
              bottomSpacing: 18,
              titleFontSize: 30,
              actions: [
                AppButton(
                  label: 'Add expense',
                  icon: const Icon(PhosphorIconsRegular.plus),
                  onPressed: () => _openEditor(context),
                ),
              ],
            ),
            if (controller.loading.value && controller.expenses.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            if (controller.error.value != null &&
                controller.expenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Could not refresh expenses: ${controller.error.value}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (controller.error.value != null && controller.expenses.isEmpty)
              SizedBox(
                height: 360,
                child: ErrorRetryWidget(
                  errorMessage: controller.error.value!,
                  onRetry: controller.reload,
                ),
              )
            else if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: tableWidth, child: _tableSection(context)),
                  const SizedBox(width: 16),
                  SizedBox(width: 360, child: _budgetCard(context)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _tableSection(context),
                  const SizedBox(height: 16),
                  _budgetCard(context),
                ],
              ),
          ],
        ),
      );
    }),
  );

  Widget _tableSection(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (controller.loading.value && controller.expenses.isEmpty)
        const SizedBox(
          height: 320,
          child: AppLoader(label: 'Loading expenses...'),
        )
      else
        _tableCard(context),
      if (controller.loadMoreError.value != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Could not load more expenses: ${controller.loadMoreError.value}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      if (controller.canLoadMore.value || controller.loadingMore.value)
        Align(
          alignment: Alignment.center,
          child: TextButton.icon(
            onPressed: controller.loadingMore.value
                ? null
                : controller.loadMore,
            icon: controller.loadingMore.value
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.arrowDown, size: 17),
            label: Text(
              controller.loadingMore.value
                  ? 'Loading expenses...'
                  : 'Load more expenses',
            ),
          ),
        ),
    ],
  );

  Widget _tableCard(BuildContext context) {
    final rows = controller.filtered;
    const headingHeight = 46.0;
    const rowHeight = 64.0;
    final tableHeight = rows.isEmpty
        ? 300.0
        : headingHeight + rowHeight * rows.length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: tableHeight,
        child: AppTable(
          minWidth: 780,
          headingRowHeight: headingHeight,
          dataRowHeight: rowHeight,
          horizontalMargin: 16,
          columnSpacing: 12,
          emptyState: EmptyState(
            title: 'No expenses yet',
            message: 'Add an expense to keep your costs up to date.',
            icon: PhosphorIconsRegular.wallet,
            actionLabel: 'Add expense',
            onAction: () => _openEditor(context),
          ),
          columns: const [
            DataColumn2(label: Text('Date'), fixedWidth: 70),
            DataColumn2(label: Text('Category'), fixedWidth: 150),
            DataColumn2(label: Text('Note'), size: ColumnSize.L),
            DataColumn2(label: Text('Paid by'), fixedWidth: 100),
            DataColumn2(label: Text('Amount'), numeric: true, fixedWidth: 160),
          ],
          rows: [
            for (final e in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      DateFormat('d MMM').format(e.createdAt),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            Money.rs(e.amount),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Expense actions',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            PhosphorIconsRegular.dotsThree,
                            size: 19,
                          ),
                          onSelected: (action) =>
                              _handleExpenseAction(context, action, e),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit expense'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete expense'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExpenseAction(
    BuildContext context,
    String action,
    ExpenseRecord expense,
  ) async {
    if (action == 'edit') {
      await _openEditor(context, expense);
      return;
    }
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Delete expense?',
      message: 'This expense will be removed and profit reports will change.',
      icon: PhosphorIconsRegular.trash,
      iconColor: Theme.of(context).colorScheme.error,
      positiveButtonText: 'Delete',
    );
    if (confirmed != true) return;
    try {
      await controller.delete(expense);
    } catch (exception) {
      Get.snackbar('Could not delete expense', exception.toString());
    }
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Usual spend per month',
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
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                Money.rs(controller.budgetTotal),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                Money.rs(budget),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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

  String _plain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Future<void> _openEditor(
    BuildContext context, [
    ExpenseRecord? existing,
  ]) async {
    final note = TextEditingController(text: existing?.note ?? '');
    final amount = TextEditingController(
      text: existing == null ? '' : _plain(existing.amount),
    );
    final category = (existing?.category ?? kExpenseCategories.first).obs;
    final method = (existing?.paidBy ?? kPaymentMethods.first).obs;
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
      final value =
          double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
      if (value <= 0) {
        error.value = 'Enter an amount greater than zero.';
        return;
      }
      saving.value = true;
      error.value = null;
      try {
        await controller.save(
          ExpenseRecord(
            id: existing?.id,
            category: category.value,
            note: note.text.trim(),
            amount: value,
            paidBy: method.value,
            createdAt: existing?.createdAt ?? DateTime.now(),
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
      width: 680,
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
                    fieldType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
              onPressed: saving.value
                  ? null
                  : () => Navigator.of(context).pop(),
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
    final categories = {
      ...kExpenseCategories,
      ...controller.budgets.keys,
    }.toList();
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
              onPressed: saving.value
                  ? null
                  : () => Navigator.of(context).pop(),
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
