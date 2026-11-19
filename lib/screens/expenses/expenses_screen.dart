import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/expense_controller.dart';
import '../../models/expense_record.dart';
import '../../services/report_export_service.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/side_drawer.dart';

// ============================================================================
// Helpers (all colours come from the app theme)
// ============================================================================

Color _muted(BuildContext c) =>
    Theme.of(c).inputDecorationTheme.labelStyle?.color ??
    Theme.of(c).colorScheme.onSurfaceVariant;

/// A stable colour per category, taken from the theme palette.
Color _catColor(BuildContext c, String category) {
  final cs = Theme.of(c).colorScheme;
  final palette = [
    cs.primary,
    AppColors.info,
    cs.secondary,
    cs.tertiary,
    AppColors.warning,
    _muted(c),
  ];
  final index = kExpenseCategories.indexOf(category);
  return palette[(index < 0 ? category.hashCode.abs() : index) % palette.length];
}

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) {
    final k = v / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '')}k';
  }
  return v.toStringAsFixed(0);
}

String _plain(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEEE, d MMM').format(d);
}

// Table column widths (the Note column takes the rest).
const double _wDate = 84;
const double _wCat = 190;
const double _wPaid = 120;
const double _wAmount = 132;
const double _wAction = 48;

class ExpensesScreen extends GetView<ExpenseController> {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth;
      final wide = w >= 1100;
      return Obx(() {
        final c = controller;
        if (!c.loadedOnce.value && c.error.value == null) {
          return const Center(child: AppLoader(label: 'Loading expenses...'));
        }
        if (c.error.value != null && !c.loadedOnce.value) {
          return ErrorRetryWidget(
            errorMessage: c.error.value!,
            onRetry: c.reload,
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, w),
              SizedBox(
                height: 4,
                child: c.loading.value
                    ? const LinearProgressIndicator(minHeight: 2)
                    : null,
              ),
              if (c.error.value != null) _errorBanner(context),
              const SizedBox(height: 12),
              _kpis(context, w),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _chartCard(context),
                          const SizedBox(height: 16),
                          _tableCard(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: _budgetCard(context)),
                  ],
                )
              else
                Column(
                  children: [
                    _chartCard(context),
                    const SizedBox(height: 16),
                    _budgetCard(context),
                    const SizedBox(height: 16),
                    _tableCard(context),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      });
    },
  );

  // --------------------------------------------------------------------
  // Header + month switcher
  // --------------------------------------------------------------------

  Widget _header(BuildContext context, double w) {
    return PageHeader(
      title: 'Expenses',
      subtitle: 'Everything you spend to run the shop, so profit is real.',
      bottomSpacing: 14,
      titleFontSize: w < 560 ? 22 : 28,
      actions: [
        _monthSwitcher(context),
        AppButton(
          label: 'Export',
          style: AppButtonStyle.ghost,
          icon: const Icon(PhosphorIconsRegular.fileCsv),
          onPressed: () => _export(context),
        ),
        AppButton(
          label: 'Add expense',
          icon: const Icon(PhosphorIconsRegular.plus),
          onPressed: () => _openEditor(context),
        ),
      ],
    );
  }

  Widget _monthSwitcher(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final label = DateFormat('MMMM yyyy').format(c.month.value);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: c.previousMonth,
            visualDensity: VisualDensity.compact,
            icon: const Icon(PhosphorIconsRegular.caretLeft, size: 16),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pickMonth(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.calendarBlank,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: c.canGoNext ? c.nextMonth : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(PhosphorIconsRegular.caretRight, size: 16),
          ),
          if (!c.isCurrentMonth)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: c.thisMonth,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Text('This month'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.month.value,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Pick any day in the month',
    );
    if (picked != null) controller.setMonth(picked);
  }

  Widget _errorBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsFill.warningCircle, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not refresh: ${controller.error.value}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          TextButton(onPressed: controller.reload, child: const Text('Retry')),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // KPI cards
  // --------------------------------------------------------------------

  Widget _kpis(BuildContext context, double w) {
    final theme = Theme.of(context);
    final c = controller;
    final monthName = DateFormat('MMM').format(c.month.value);
    final delta = c.deltaPercent;
    final up = (delta ?? 0) > 0;
    final top = c.topCategory;
    final budgetLeft = c.budgetTotal - c.monthTotal;

    final cards = <Widget>[
      _kpi(
        context,
        icon: PhosphorIconsRegular.wallet,
        label: 'Spent in $monthName',
        value: Money.rs(c.monthTotal),
        color: theme.colorScheme.primary,
        chip: delta == null
            ? null
            : _deltaChip(
                context,
                '${up ? '+' : ''}${delta.toStringAsFixed(0)}%',
                bad: up,
              ),
        note: c.prevTotal > 0
            ? 'vs ${Money.rs(c.prevTotal)} last month'
            : 'No data last month',
      ),
      _kpi(
        context,
        icon: PhosphorIconsRegular.target,
        label: 'Budget used',
        value: '${(c.budgetUsed * 100).toStringAsFixed(0)}%',
        color: c.budgetUsed > 1 ? theme.colorScheme.error : AppColors.info,
        progress: c.budgetUsed,
        note: c.budgetTotal <= 0
            ? 'No budget set'
            : budgetLeft >= 0
            ? '${Money.rs(budgetLeft)} left of ${Money.rs(c.budgetTotal)}'
            : '${Money.rs(-budgetLeft)} over budget',
      ),
      _kpi(
        context,
        icon: PhosphorIconsRegular.chartLineUp,
        label: 'Daily average',
        value: Money.rs(c.dailyAverage),
        color: theme.colorScheme.secondary,
        note: c.isCurrentMonth
            ? 'Today ${Money.rs(c.todayTotal)} · on pace for ${Money.rs(c.projected)}'
            : 'Across ${c.daysInMonth} days',
      ),
      _kpi(
        context,
        icon: PhosphorIconsRegular.crown,
        label: 'Top category',
        value: top?.key ?? '—',
        color: top == null ? _muted(context) : _catColor(context, top.key),
        note: top == null || c.monthTotal <= 0
            ? 'Nothing spent yet'
            : '${Money.rs(top.value)} · ${(top.value / c.monthTotal * 100).toStringAsFixed(0)}% of spend',
      ),
    ];

    final cols = w >= 1100 ? 4 : (w >= 700 ? 2 : 1);
    const gap = 14.0;
    final itemW = (w - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final card in cards) SizedBox(width: itemW, child: card)],
    );
  }

  Widget _deltaChip(BuildContext context, String text, {required bool bad}) {
    final theme = Theme.of(context);
    final color = bad ? theme.colorScheme.error : AppColors.ok;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            bad ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String note,
    required Color color,
    Widget? chip,
    double? progress,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _muted(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (chip != null) chip,
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: _muted(context)),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Daily spending chart
  // --------------------------------------------------------------------

  Widget _chartCard(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final values = c.dailyTotals;
    final maxV = values.fold(0.0, (a, b) => a > b ? a : b);
    final today = c.isCurrentMonth ? DateTime.now().day : -1;
    final primary = theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
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
                        'Daily spending',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(c.month.value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.rs(c.monthTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: maxV <= 0
                  ? Center(
                      child: Text(
                        'No spending recorded this month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted(context),
                        ),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        maxY: maxV * 1.2,
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, _) => Text(
                                _compact(value),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _muted(context),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, _) {
                                final day = value.toInt() + 1;
                                if (day != 1 && day % 5 != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '$day',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _muted(context),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < values.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: values[i],
                                  width: 9,
                                  borderRadius: BorderRadius.circular(3),
                                  color: (i + 1 == today)
                                      ? primary
                                      : primary.withValues(alpha: 0.38),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Budget card
  // --------------------------------------------------------------------

  Widget _budgetCard(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final spent = c.spentByCategory;
    final categories = c.categories;
    final left = c.budgetTotal - c.monthTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'Spent vs planned, per category',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _muted(context),
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
            const SizedBox(height: 16),
            for (final category in categories)
              _budgetRow(
                context,
                category,
                spent[category] ?? 0,
                c.budgets[category] ?? 0,
              ),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total spent',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  Money.rs(c.monthTotal),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    left >= 0 ? 'Left in budget' : 'Over budget',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _muted(context),
                    ),
                  ),
                ),
                Text(
                  Money.rs(left.abs()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: left >= 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final hasBudget = budget > 0;
    final ratio = hasBudget ? spent / budget : (spent > 0 ? 1.0 : 0.0);
    final over = hasBudget && spent > budget;
    final barColor = !hasBudget
        ? _muted(context)
        : over
        ? theme.colorScheme.error
        : ratio > 0.8
        ? AppColors.warning
        : _catColor(context, category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _catColor(context, category),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (over)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Over',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Text(
                hasBudget
                    ? '${_compact(spent)} / ${_compact(budget)}'
                    : '${_compact(spent)} · no budget',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _muted(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: barColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Table card (filters + rows grouped by day)
  // --------------------------------------------------------------------

  Widget _tableCard(BuildContext context) {
    final theme = Theme.of(context);
    final c = controller;
    final rows = c.filtered;
    final shown = rows.take(c.visible.value).toList();
    final grouped = c.sort.value.byDate;

    // Total per day (over all filtered rows) for the day headers.
    final dayTotals = <String, double>{};
    for (final e in rows) {
      final key = DateFormat('yyyyMMdd').format(e.createdAt);
      dayTotals[key] = (dayTotals[key] ?? 0) + e.amount;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 720;
          final children = <Widget>[];
          String? lastKey;
          for (final e in shown) {
            if (grouped) {
              final key = DateFormat('yyyyMMdd').format(e.createdAt);
              if (key != lastKey) {
                lastKey = key;
                children.add(_dayHeader(context, e.createdAt, dayTotals[key] ?? 0));
              }
            }
            children.add(
              compact
                  ? _cardRow(context, e, grouped)
                  : _tableRow(context, e, grouped),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _toolbar(context, compact),
              Divider(height: 1, color: theme.dividerColor),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: EmptyState(
                    title: c.monthExpenses.isEmpty
                        ? 'No expenses this month'
                        : 'No matching expenses',
                    message: c.monthExpenses.isEmpty
                        ? 'Add an expense to keep your costs up to date.'
                        : 'Try a different search or clear the filters.',
                    icon: PhosphorIconsRegular.wallet,
                    actionLabel: c.monthExpenses.isEmpty
                        ? 'Add expense'
                        : 'Clear filters',
                    onAction: c.monthExpenses.isEmpty
                        ? () => _openEditor(context)
                        : c.clearFilters,
                  ),
                )
              else ...[
                if (!compact) _tableHead(context, grouped),
                ...children,
                _footer(context, shown.length, rows.length),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _toolbar(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    final c = controller;

    Widget pill(String label, IconData icon, {bool active = false}) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: active ? theme.colorScheme.primary : _muted(context)),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: active ? theme.colorScheme.primary : null,
            ),
          ),
          const SizedBox(width: 4),
          Icon(PhosphorIconsRegular.caretDown, size: 12, color: _muted(context)),
        ],
      ),
    );

    final search = SizedBox(
      height: 40,
      child: TextField(
        onChanged: (value) => c.search.value = value,
        style: theme.textTheme.bodyMedium,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
          prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
          hintText: 'Search note, category or payment',
        ),
      ),
    );

    final sort = PopupMenuButton<ExpenseSort>(
      tooltip: 'Sort',
      onSelected: (value) => c.sort.value = value,
      itemBuilder: (_) => [
        for (final s in ExpenseSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == c.sort.value ? PhosphorIconsBold.check : null,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: pill(c.sort.value.label, PhosphorIconsRegular.sortAscending),
    );

    final method = PopupMenuButton<String>(
      tooltip: 'Paid by',
      onSelected: (value) => c.paidBy.value = value,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '',
          child: Text(
            'Any payment method',
            style: TextStyle(fontWeight: c.paidBy.value.isEmpty ? FontWeight.w800 : null),
          ),
        ),
        for (final m in c.paymentMethods)
          PopupMenuItem(
            value: m,
            child: Text(
              m,
              style: TextStyle(fontWeight: c.paidBy.value == m ? FontWeight.w800 : null),
            ),
          ),
      ],
      child: pill(
        c.paidBy.value.isEmpty ? 'Paid by' : c.paidBy.value,
        PhosphorIconsRegular.creditCard,
        active: c.paidBy.value.isNotEmpty,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            search,
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [sort, method]),
          ] else
            Row(
              children: [
                Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: search)),
                const SizedBox(width: 10),
                method,
                const SizedBox(width: 8),
                sort,
                const Spacer(),
                if (c.hasFilters)
                  TextButton.icon(
                    onPressed: c.clearFilters,
                    icon: const Icon(PhosphorIconsRegular.x, size: 14),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _catChip(context, 'All', '', null),
                for (final cat in c.categories)
                  _catChip(context, cat, cat, _catColor(context, cat)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(BuildContext context, String label, String value, Color? color) {
    final theme = Theme.of(context);
    final selected = controller.category.value == value;
    final tint = color ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => controller.category.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? tint : theme.dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (color != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? tint : _muted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableHead(BuildContext context, bool grouped) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: _muted(context),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    );
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        children: [
          SizedBox(width: _wDate, child: Text(grouped ? 'TIME' : 'DATE', style: style)),
          SizedBox(width: _wCat, child: Text('CATEGORY', style: style)),
          Expanded(child: Text('NOTE', style: style)),
          SizedBox(width: _wPaid, child: Text('PAID BY', style: style)),
          SizedBox(
            width: _wAmount,
            child: Text('AMOUNT', textAlign: TextAlign.right, style: style),
          ),
          const SizedBox(width: _wAction),
        ],
      ),
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day, double total) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Text(
            _dayLabel(day),
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('d MMM').format(day),
            style: theme.textTheme.bodySmall?.copyWith(color: _muted(context)),
          ),
          const Spacer(),
          Text(
            Money.rs(total),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: _muted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, String category) {
    final color = _catColor(context, category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Created from Riders. Manage it there.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsFill.lockSimple, size: 10, color: _muted(context)),
            const SizedBox(width: 4),
            Text(
              'Auto',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowMenu(BuildContext context, ExpenseRecord e) {
    if (e.isAuto) {
      return Tooltip(
        message: 'Managed from Riders',
        child: Icon(PhosphorIconsRegular.lockSimple, size: 17, color: _muted(context)),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Expense actions',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: const Icon(PhosphorIconsRegular.dotsThree, size: 19),
      onSelected: (action) => _handleAction(context, action, e),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit expense')),
        PopupMenuItem(value: 'delete', child: Text('Delete expense')),
      ],
    );
  }

  Widget _tableRow(BuildContext context, ExpenseRecord e, bool grouped) {
    final theme = Theme.of(context);
    return _HoverRow(
      onTap: e.isAuto ? null : () => _openEditor(context, e),
      builder: (hovering) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: hovering
              ? theme.colorScheme.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _wDate,
              child: Text(
                grouped
                    ? DateFormat('hh:mm a').format(e.createdAt)
                    : DateFormat('d MMM').format(e.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: _muted(context)),
              ),
            ),
            SizedBox(
              width: _wCat,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _categoryChip(context, e.category),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      e.note.isEmpty ? '—' : e.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (e.isAuto) ...[const SizedBox(width: 8), _autoBadge(context)],
                ],
              ),
            ),
            SizedBox(
              width: _wPaid,
              child: Text(e.paidBy, style: theme.textTheme.bodySmall),
            ),
            SizedBox(
              width: _wAmount,
              child: Text(
                Money.rs(e.amount),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(
              width: _wAction,
              child: Align(alignment: Alignment.centerRight, child: _rowMenu(context, e)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardRow(BuildContext context, ExpenseRecord e, bool grouped) {
    final theme = Theme.of(context);
    final color = _catColor(context, e.category);
    return InkWell(
      onTap: e.isAuto ? null : () => _openEditor(context, e),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6))),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.note.isEmpty ? e.category : e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (e.isAuto) ...[const SizedBox(width: 6), _autoBadge(context)],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${e.category} · ${e.paidBy} · '
                    '${grouped ? DateFormat('hh:mm a').format(e.createdAt) : DateFormat('d MMM').format(e.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: _muted(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Money.rs(e.amount),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            _rowMenu(context, e),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, int shown, int total) {
    final theme = Theme.of(context);
    final c = controller;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 14,
        runSpacing: 6,
        children: [
          Text(
            'Showing $shown of $total',
            style: theme.textTheme.bodySmall?.copyWith(color: _muted(context)),
          ),
          if (shown < total)
            TextButton.icon(
              onPressed: c.showMore,
              icon: const Icon(PhosphorIconsRegular.arrowDown, size: 15),
              label: const Text('Show more'),
            ),
          Text(
            c.hasFilters
                ? 'Filtered total ${Money.rs(c.filteredTotal)}'
                : 'Month total ${Money.rs(c.monthTotal)}',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Actions
  // --------------------------------------------------------------------

  Future<void> _handleAction(
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
      message:
          '${Money.rs(expense.amount)} (${expense.category}) will be removed and profit reports will change.',
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

  Future<void> _export(BuildContext context) async {
    final c = controller;
    final label = DateFormat('MMMM yyyy').format(c.month.value);
    final rows = c.filtered;
    if (rows.isEmpty) {
      Get.snackbar('Nothing to export', 'There are no expenses for $label.');
      return;
    }
    try {
      final path = await ReportExportService().export('Hoorain expenses · $label', {
        'Expenses': [
          ['Date', 'Category', 'Note', 'Paid by', 'Amount'],
          for (final e in rows)
            [
              DateFormat('yyyy-MM-dd').format(e.createdAt),
              e.category,
              e.note,
              e.paidBy,
              Money.rs(e.amount),
            ],
          ['', '', '', 'Total', Money.rs(c.filteredTotal)],
        ],
      });
      if (path != null) Get.snackbar('Expenses exported', path);
    } catch (exception) {
      Get.snackbar('Could not export', exception.toString());
    }
  }

  // --------------------------------------------------------------------
  // Add / edit drawer
  // --------------------------------------------------------------------

  Widget _label(BuildContext context, String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: _muted(context),
            ),
          ),
          if (required)
            Text(
              ' *',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _choiceChips(
    BuildContext context, {
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    bool colored = false,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Builder(
            builder: (_) {
              final isSelected = option == selected;
              final tint = colored
                  ? _catColor(context, option)
                  : theme.colorScheme.primary;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? tint.withValues(alpha: 0.12) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? tint : theme.dividerColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? tint : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, [ExpenseRecord? existing]) async {
    final amount = TextEditingController(
      text: existing == null ? '' : _plain(existing.amount),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final date = (existing?.createdAt ?? DateTime.now()).obs;
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

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date.value.isAfter(DateTime.now()) ? DateTime.now() : date.value,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        final old = date.value;
        date.value = DateTime(picked.year, picked.month, picked.day, old.hour, old.minute);
      }
    }

    Future<void> save() async {
      final value = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
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
            createdAt: date.value,
            source: existing?.source ?? '',
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
      subtitle: 'Costs recorded here feed your profit reports.',
      width: 560,
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(context, 'Amount', required: true),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                prefixText: 'Rs. ',
                hintText: '0',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            _label(context, 'Date'),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  isDense: true,
                  suffixIcon: Icon(PhosphorIconsRegular.calendarBlank, size: 18),
                ),
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy').format(date.value),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label(context, 'Category'),
            _choiceChips(
              context,
              options: categoryOptions,
              selected: category.value,
              onSelected: (v) => category.value = v,
              colored: true,
            ),
            const SizedBox(height: 20),
            _label(context, 'Paid by'),
            _choiceChips(
              context,
              options: methodOptions,
              selected: method.value,
              onSelected: (v) => method.value = v,
            ),
            const SizedBox(height: 20),
            _label(context, 'Note (optional)'),
            TextField(
              controller: note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'What was it for?',
              ),
            ),
            if (error.value != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  error.value!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
              small: true,
              onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            AppButton(
              label: saving.value ? 'Saving…' : 'Save expense',
              icon: const Icon(PhosphorIconsRegular.check, size: 18),
              small: true,
              onPressed: saving.value ? null : save,
            ),
          ],
        ),
      ),
    );
    await SideDrawer.show<void>(drawer);
    amount.dispose();
    note.dispose();
  }

  // --------------------------------------------------------------------
  // Budgets drawer
  // --------------------------------------------------------------------

  Future<void> _openBudgets(BuildContext context) async {
    final categories = controller.categories;
    final fields = {
      for (final c in categories)
        c: TextEditingController(text: _plain(controller.budgets[c] ?? 0)),
    };
    final saving = false.obs;

    double total() => fields.values.fold(
      0.0,
      (sum, f) => sum + (double.tryParse(f.text.replaceAll(',', '').trim()) ?? 0),
    );

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
      subtitle: 'The planned spend per category, in Rs.',
      width: 480,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _catColor(context, c),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _muted(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    controller: fields[c],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: 'Rs. ',
                      hintText: '0',
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          ListenableBuilder(
            listenable: Listenable.merge(fields.values.toList()),
            builder: (context, _) => Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total monthly budget',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  Money.rs(total()),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
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
              small: true,
              onPressed: saving.value ? null : () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 10),
            AppButton(
              label: saving.value ? 'Saving…' : 'Save budgets',
              icon: const Icon(PhosphorIconsRegular.check, size: 18),
              small: true,
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

/// Row wrapper that reports hover state and handles clicks on desktop/web.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.builder, this.onTap});

  final Widget Function(bool hovering) builder;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_hovering),
      ),
    );
  }
}