import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/sales_controller.dart';
import '../../models/order_model.dart';
import '../../utils/money.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_table.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';

class SalesScreen extends StatelessWidget {
  SalesScreen({super.key});

  final SalesController controller = Get.put(SalesController());
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Sales and profit',
          subtitle:
              'Review counter and online sales across the selected period.',
          actions: [
            OutlinedButton.icon(
              onPressed: controller.refresh,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        _RangeControls(controller: controller),
        const SizedBox(height: 18),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const AppLoader(label: 'Loading sales...');
            }
            if (controller.hasError.value) {
              return ErrorRetryWidget(
                errorMessage: controller.errorMessage.value,
                onRetry: controller.refresh,
              );
            }
            if (controller.filteredOrders.isEmpty) {
              return const EmptyState(
                title: 'No sales in this period',
                message: 'Choose a different date range to view sales.',
                icon: PhosphorIconsRegular.receipt,
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200
                    ? 4
                    : constraints.maxWidth >= 700
                    ? 2
                    : 1;
                final gap = 12.0;
                final cardWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        _MetricCard(
                          width: cardWidth,
                          label: 'Total sales',
                          value: Money.rs(controller.totalSales.value),
                          icon: PhosphorIconsRegular.currencyDollar,
                          color: theme.colorScheme.primary,
                          note: controller.rangeLabel,
                        ),
                        _MetricCard(
                          width: cardWidth,
                          label: 'Orders',
                          value: '${controller.totalOrders.value}',
                          icon: PhosphorIconsRegular.receipt,
                          color: theme.colorScheme.secondary,
                          note:
                              '${controller.filteredOrders.length} in this view',
                        ),
                        _MetricCard(
                          width: cardWidth,
                          label: 'Delivered sales',
                          value: Money.rs(controller.deliveredRevenue.value),
                          icon: PhosphorIconsRegular.checkCircle,
                          color: AppColors.ok,
                          note: 'Completed orders',
                        ),
                        _MetricCard(
                          width: cardWidth,
                          label: 'Order statuses',
                          value: '${controller.statusBreakdown.length}',
                          icon: PhosphorIconsRegular.chartBar,
                          color: AppColors.info,
                          note: 'Statuses in this period',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _StatusSummary(controller: controller),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order history',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${controller.rangeLabel} · ${controller.filteredOrders.length} orders',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: constraints.maxWidth >= 900
                          ? _SalesTable(
                              orders: controller.filteredOrders,
                              dateFormat: _dateFormat,
                            )
                          : RefreshIndicator(
                              color: theme.colorScheme.primary,
                              onRefresh: controller.refresh,
                              child: ListView.separated(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: controller.filteredOrders.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) =>
                                    _SalesOrderCard(
                                      order: controller.filteredOrders[index],
                                      dateFormat: _dateFormat,
                                    ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

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
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Obx(
          () => SegmentedButton<SalesRange>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SalesRange.today, label: Text('Today')),
              ButtonSegment(value: SalesRange.thisWeek, label: Text('7 days')),
              ButtonSegment(
                value: SalesRange.thisMonth,
                label: Text('30 days'),
              ),
            ],
            selected: {controller.selectedRange.value},
            onSelectionChanged: (selected) =>
                controller.applyRange(selected.first),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _selectDay(context),
          icon: const Icon(PhosphorIconsRegular.calendarBlank, size: 18),
          label: Obx(
            () => Text(
              controller.selectedRange.value == SalesRange.singleDay &&
                      controller.singleDate.value != null
                  ? DateFormat(
                      'dd MMM yyyy',
                    ).format(controller.singleDate.value!)
                  : 'Choose day',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _selectRange(context),
          icon: const Icon(PhosphorIconsRegular.calendarDots, size: 18),
          label: const Text('Custom range'),
        ),
        Obx(
          () => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              controller.rangeLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.note,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.controller});

  final SalesController controller;

  Color _color(BuildContext context, String status) => switch (status) {
    'Delivered' => AppColors.ok,
    'Accepted' => AppColors.info,
    'Pending' => AppColors.warning,
    'Rejected' || 'Cancelled' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: controller.statusBreakdown.entries.map((entry) {
          final color = _color(context, entry.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${entry.key} · ${entry.value}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SalesTable extends StatelessWidget {
  const _SalesTable({required this.orders, required this.dateFormat});

  final List<OrderModel> orders;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppTable(
      minWidth: 1050,
      columns: const [
        DataColumn2(label: Text('Bill / order'), size: ColumnSize.M),
        DataColumn2(label: Text('Date'), size: ColumnSize.L),
        DataColumn2(label: Text('Customer'), size: ColumnSize.L),
        DataColumn2(label: Text('Channel')),
        DataColumn2(label: Text('Items'), numeric: true),
        DataColumn2(label: Text('Payment')),
        DataColumn2(label: Text('Total'), numeric: true),
        DataColumn2(label: Text('Status')),
      ],
      rows: orders.map((order) {
        return DataRow(
          onSelectChanged: (_) =>
              Get.toNamed('/orders/detail', arguments: order),
          cells: [
            DataCell(
              Text(
                '#${order.orderId ?? order.id}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            DataCell(Text(dateFormat.format(order.orderDate))),
            DataCell(
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.userName.isEmpty
                        ? 'Walk-in customer'
                        : order.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (order.userPhone.isNotEmpty)
                    Text(
                      order.userPhone,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            DataCell(Text(order.channel)),
            DataCell(Text('${order.items.length}')),
            DataCell(Text(order.paymentMethod)),
            DataCell(
              Text(
                Money.rs(order.total),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataCell(_StatusBadge(status: order.status)),
          ],
        );
      }).toList(),
    );
  }
}

class _SalesOrderCard extends StatelessWidget {
  const _SalesOrderCard({required this.order, required this.dateFormat});

  final OrderModel order;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.toNamed('/orders/detail', arguments: order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderId ?? order.id}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  _StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                order.userName.isEmpty ? 'Walk-in customer' : order.userName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${order.channel} · ${order.items.length} items · ${dateFormat.format(order.orderDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.paymentMethod,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    Money.rs(order.total),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'delivered' => AppColors.ok,
      'accepted' => AppColors.info,
      'pending' => AppColors.warning,
      'cancelled' || 'rejected' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
