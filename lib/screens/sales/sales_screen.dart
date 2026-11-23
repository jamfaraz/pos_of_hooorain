import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/sales_controller.dart';
import '../../models/order_model.dart';
import '../../utils/money.dart';
import '../../widgets/order_card.dart';
import '../../widgets/order_history_table.dart';

/// TODO: point this at your real "verified customer" field.
/// Example: `order.isVerified` or `user.isVerified` (via controller.getCustomer).
/// Kept in ONE place so the blue tick next to the customer name is easy to wire.
bool isCustomerVerified(OrderModel order) => false;

class SalesScreen extends StatelessWidget {
  SalesScreen({super.key});

  final SalesController controller = Get.put(SalesController());
  final _dateFormat = DateFormat('dd MMM, HH:mm');

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.textTheme,
      ).apply(fontSizeFactor: 0.9),
    );

    return Theme(
      data: theme,
      child: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _Header(controller: controller)),
            SliverToBoxAdapter(child: _RangeControls(controller: controller)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            // ---------- Summary area ----------
            Obx(() {
              if (controller.isLoading.value || controller.isComputing.value) {
                return const SliverToBoxAdapter(child: _SalesSkeleton());
              }
              if (controller.hasError.value) {
                return SliverToBoxAdapter(
                  child: _ErrorState(
                    message: controller.errorMessage.value,
                    onRetry: controller.refresh,
                  ),
                );
              }
              if (controller.filteredOrders.isEmpty) {
                return const SliverToBoxAdapter(child: _EmptyState());
              }
              return SliverToBoxAdapter(
                child: _Summary(controller: controller),
              );
            }),
            // ---------- Orders list (lazy) ----------
            Obx(() {
              final busy =
                  controller.isLoading.value || controller.isComputing.value;
              if (busy ||
                  controller.hasError.value ||
                  controller.filteredOrders.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              final orders = controller.filteredOrders;
              final visible = controller.visibleCount.value.clamp(
                0,
                orders.length,
              );
              final hasMore = visible < orders.length;

              return SliverLayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.crossAxisExtent >= 900;
                  final headerCount = wide ? 1 : 0;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (wide && index == 0) {
                        return const OrderHistoryTableHeader();
                      }
                      final orderIndex = index - headerCount;
                      if (orderIndex >= visible) {
                        return _LoadMore(
                          shown: visible,
                          total: orders.length,
                          onTap: controller.loadMore,
                        );
                      }
                      final order = orders[orderIndex];
                      if (wide) {
                        return OrderHistoryTableRow(
                          order: order,
                          placedAt: _dateFormat.format(order.orderDate),
                          loadCustomerImage: () async =>
                              (await controller.getCustomer(
                                order.userId,
                              ))?.image,
                          onTap: () =>
                              Get.toNamed('/orders/detail', arguments: order),
                          isLast: orderIndex == visible - 1,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OrderCard(
                          order: order,
                          compact: true,
                          loadCustomerImage: () async =>
                              (await controller.getCustomer(
                                order.userId,
                              ))?.image,
                          onTap: () =>
                              Get.toNamed('/orders/detail', arguments: order),
                        ),
                      );
                    }, childCount: headerCount + visible + (hasMore ? 1 : 0)),
                  );
                },
              );
            }),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Header

class _Header extends StatelessWidget {
  const _Header({required this.controller});
  final SalesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales & profit',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Counter and online sales across the selected period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Obx(() {
            final busy =
                controller.isLoading.value || controller.isComputing.value;
            return OutlinedButton.icon(
              onPressed: busy ? null : controller.refresh,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================ Range controls

class _RangeControls extends StatelessWidget {
  const _RangeControls({required this.controller});
  final SalesController controller;

  Future<void> _selectDay(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: controller.singleDate.value ?? now,
    );
    if (date != null) controller.setSingleDate(date);
  }

  Future<void> _selectRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          controller.customRange.value ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (range != null) controller.setCustomRange(range);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sel = controller.selectedRange.value;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Segmented(
            items: const [
              (SalesRange.today, 'Today'),
              (SalesRange.thisWeek, '7 days'),
              (SalesRange.thisMonth, '30 days'),
            ],
            selected: sel,
            onChanged: controller.applyRange,
          ),
          _ToolButton(
            icon: PhosphorIconsRegular.calendarBlank,
            label:
                sel == SalesRange.singleDay &&
                    controller.singleDate.value != null
                ? DateFormat('dd MMM yyyy').format(controller.singleDate.value!)
                : 'Pick a day',
            selected: sel == SalesRange.singleDay,
            onTap: () => _selectDay(context),
          ),
          _ToolButton(
            icon: PhosphorIconsRegular.calendarDots,
            label: sel == SalesRange.custom
                ? controller.rangeLabel
                : 'Custom range',
            selected: sel == SalesRange.custom,
            onTap: () => _selectRange(context),
          ),
        ],
      );
    });
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.items,
    required this.selected,
    required this.onChanged,
  });
  final List<(SalesRange, String)> items;
  final SalesRange selected;
  final ValueChanged<SalesRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final it in items)
            GestureDetector(
              onTap: () => onChanged(it.$1),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == it.$1 ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: selected == it.$1
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    it.$2,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected == it.$1
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        foregroundColor: selected ? cs.primary : cs.onSurface,
        backgroundColor: selected ? cs.primary.withValues(alpha: 0.07) : null,
        side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============================================================ Summary

class _Summary extends StatelessWidget {
  const _Summary({required this.controller});
  final SalesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trend = controller.dailyTotals.toList();
    final breakdown = Map<String, int>.from(controller.statusBreakdown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KpiStrip(controller: controller),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final hasTrend = trend.length > 1;
            final status = _StatusCard(breakdown: breakdown);
            if (!hasTrend) return status;
            final chart = _TrendCard(data: trend);
            if (!wide) {
              return Column(
                children: [chart, const SizedBox(height: 14), status],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: chart),
                  const SizedBox(width: 14),
                  Expanded(child: status),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Order history',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${controller.filteredOrders.length} orders',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// One card, four KPIs separated by hairlines (2x2 on narrow screens).
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.controller});
  final SalesController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cells = [
      _Kpi(
        label: 'Total sales',
        value: Money.rs(controller.totalSales.value),
        note: controller.rangeLabel,
        icon: PhosphorIconsFill.wallet,
        color: cs.primary,
        emphasize: true,
      ),
      _Kpi(
        label: 'Orders',
        value: '${controller.totalOrders.value}',
        note: 'In this period',
        icon: PhosphorIconsFill.receipt,
        color: const Color(0xFFE8590C),
      ),
      _Kpi(
        label: 'Delivered sales',
        value: Money.rs(controller.deliveredRevenue.value),
        note: 'Completed orders',
        icon: PhosphorIconsFill.checkCircle,
        color: AppColors.ok,
      ),
      _Kpi(
        label: 'Avg. order value',
        value: Money.rs(controller.averageOrder.value),
        note: 'Per order',
        icon: PhosphorIconsFill.chartBar,
        color: AppColors.info,
      ),
    ];
    final divider = cs.outlineVariant.withValues(alpha: 0.6);

    return _Surface(
      padding: EdgeInsets.zero,
      radius: 16,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) {
            return IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) VerticalDivider(width: 1, color: divider),
                    Expanded(child: cells[i]),
                  ],
                ],
              ),
            );
          }
          final half = c.maxWidth >= 480;
          return Wrap(
            children: [
              for (var i = 0; i < cells.length; i++)
                SizedBox(
                  width: half ? c.maxWidth / 2 : c.maxWidth,
                  child: cells[i],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.emphasize = false,
  });
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: emphasize ? 22 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: emphasize ? cs.primary : cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.data});
  final List<MapEntry<DateTime, double>> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final maxV = data.fold<double>(0, (m, e) => e.value > m ? e.value : m);
    final fmt = DateFormat('dd MMM');
    final labelEvery = data.length > 14 ? (data.length / 7).ceil() : 1;

    return _Surface(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sales trend',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'Peak ${Money.rs(maxV)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < data.length; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${fmt.format(data[i].key)}\n${Money.rs(data[i].value)}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: data.length > 40 ? 0.8 : 3,
                              ),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin: 0,
                                  end: maxV == 0 ? 0 : data[i].value / maxV,
                                ),
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => FractionallySizedBox(
                                  heightFactor: v.clamp(0.03, 1.0),
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: data[i].value == maxV
                                          ? cs.primary
                                          : cs.primary.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 14,
                            child: i % labelEvery == 0
                                ? OverflowBox(
                                    maxWidth: 60,
                                    child: Text(
                                      fmt.format(data[i].key),
                                      maxLines: 1,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontSize: 10.5,
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.breakdown});
  final Map<String, int> breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Surface(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Order status',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$total total',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: e.value,
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          color: _statusColor(context, e.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 10,
            children: [
              for (final e in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _statusColor(context, e.key),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${e.value}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${(e.value * 100 / total).round()}%)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================ Loading skeleton

// Column proportions keep the desktop loading skeleton aligned.
const List<int> _flex = [2, 3, 4, 2, 1, 2, 3];
const double _hPad = 24;

class _LoadMore extends StatelessWidget {
  const _LoadMore({
    required this.shown,
    required this.total,
    required this.onTap,
  });
  final int shown;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(PhosphorIconsRegular.caretDoubleDown, size: 16),
          label: Text('Load more  ($shown of $total)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================ Small widgets

Color _statusColor(BuildContext context, String status) {
  switch (status.toLowerCase().trim()) {
    case 'delivered':
      return AppColors.ok;
    case 'accepted':
    case 'packed':
      return AppColors.info;
    case 'out for delivery':
      return const Color(0xFF0B7A5E);
    case 'pending':
      return AppColors.warning;
    case 'cancelled':
      return Theme.of(context).colorScheme.error;
    default:
      return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

/// Soft elevated card used across the screen.
class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ============================================================ States

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsDuotone.receipt,
                size: 40,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No sales in this period',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a different date range to view sales.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(PhosphorIconsDuotone.warningCircle, size: 54, color: cs.error),
            const SizedBox(height: 14),
            Text(
              'Could not load sales',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ Skeleton loader

class _SalesSkeleton extends StatefulWidget {
  const _SalesSkeleton();

  @override
  State<_SalesSkeleton> createState() => _SalesSkeletonState();
}

class _SalesSkeletonState extends State<_SalesSkeleton>
    with SingleTickerProviderStateMixin {
  // Soft pulse (fade between two tones) - calmer and cheaper than a sweep.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone1 = cs.surfaceContainerHighest.withValues(alpha: 0.9);
    final tone2 = cs.surfaceContainerHighest.withValues(alpha: 0.45);
    final line = cs.outlineVariant.withValues(alpha: 0.6);

    Widget bone(double w, double h, {double r = 8}) => AnimatedBuilder(
      animation: _t,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Color.lerp(tone1, tone2, _t.value),
          borderRadius: BorderRadius.circular(r),
        ),
      ),
    );

    Widget card({required Widget child, double? height}) => Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: child,
    );

    Widget kpiCell() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          bone(40, 40, r: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bone(64, 9),
                const SizedBox(height: 8),
                bone(110, 16),
                const SizedBox(height: 8),
                bone(76, 8),
              ],
            ),
          ),
        ],
      ),
    );

    Widget tableRow() => Container(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _flex[0],
            child: Align(alignment: Alignment.centerLeft, child: bone(70, 11)),
          ),
          Expanded(
            flex: _flex[1],
            child: Align(alignment: Alignment.centerLeft, child: bone(92, 11)),
          ),
          Expanded(
            flex: _flex[2],
            child: Row(
              children: [
                bone(28, 28, r: 14),
                const SizedBox(width: 10),
                bone(120, 11),
              ],
            ),
          ),
          Expanded(
            flex: _flex[3],
            child: Align(alignment: Alignment.centerLeft, child: bone(58, 22)),
          ),
          Expanded(
            flex: _flex[4],
            child: Center(child: bone(16, 11)),
          ),
          Expanded(
            flex: _flex[5],
            child: Align(alignment: Alignment.centerRight, child: bone(70, 12)),
          ),
          Expanded(
            flex: _flex[6],
            child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Align(
                alignment: Alignment.centerLeft,
                child: bone(72, 24, r: 12),
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI strip
            card(
              child: wide
                  ? IntrinsicHeight(
                      child: Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) VerticalDivider(width: 1, color: line),
                            Expanded(child: kpiCell()),
                          ],
                        ],
                      ),
                    )
                  : Column(children: [kpiCell(), kpiCell()]),
            ),
            const SizedBox(height: 14),
            // Chart + status
            if (wide)
              SizedBox(
                height: 176,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bone(90, 12),
                              const Spacer(),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final h in [
                                    50.0,
                                    80.0,
                                    40.0,
                                    100.0,
                                    64.0,
                                    86.0,
                                    58.0,
                                  ]) ...[
                                    Expanded(
                                      child: bone(double.infinity, h, r: 5),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              bone(90, 12),
                              const SizedBox(height: 18),
                              bone(double.infinity, 10, r: 6),
                              const SizedBox(height: 18),
                              bone(150, 10),
                              const SizedBox(height: 10),
                              bone(120, 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              card(
                height: 120,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bone(90, 12),
                      const SizedBox(height: 18),
                      bone(double.infinity, 10, r: 6),
                      const SizedBox(height: 18),
                      bone(150, 10),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            // Order history title row
            Row(children: [bone(110, 16), const Spacer(), bone(70, 24, r: 12)]),
            const SizedBox(height: 12),
            if (wide)
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      height: 44,
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    ),
                    for (var i = 0; i < 5; i++) tableRow(),
                  ],
                ),
              )
            else
              for (var i = 0; i < 3; i++) ...[
                card(
                  height: 96,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            bone(90, 12),
                            const Spacer(),
                            bone(64, 22, r: 11),
                          ],
                        ),
                        const SizedBox(height: 12),
                        bone(140, 11),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: bone(80, 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}
