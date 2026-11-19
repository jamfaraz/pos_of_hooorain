import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/item_profit_controller.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_table.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/status_chip.dart';

class ItemProfitScreen extends GetView<ItemProfitController> {
  const ItemProfitScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.error.value != null &&
        controller.loading.value &&
        controller.products.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }
    if (controller.loading.value && controller.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppLoader(label: 'Loading profit data...'),
      );
    }
    if (controller.products.isEmpty) {
      return const EmptyState(title: 'Add products to analyze item profit');
    }

    final theme = Theme.of(context);
    final product = controller.selectedProduct;
    final totals = controller.selectedTotals;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final gap = 14.0;
        final metricWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 24,
            18,
            compact ? 14 : 24,
            28,
          ),
          children: [
            _PageHeading(compact: compact),
            if (controller.error.value != null) ...[
              const SizedBox(height: 12),
              ErrorRetryWidget(
                errorMessage: controller.error.value!,
                onRetry: controller.reload,
              ),
            ],
            const SizedBox(height: 20),
            _ProductSelector(controller: controller, compact: compact),
            const SizedBox(height: 16),
            _ProfitHero(
              product: product,
              profit: totals.profit,
              margin: totals.margin,
              periodDays: controller.periodDays.value,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _ProfitMetric(
                  width: metricWidth,
                  label: 'Gross sales',
                  value: Money.rs(totals.sales),
                  note: 'Revenue from this product',
                  icon: PhosphorIconsRegular.currencyDollar,
                  color: const Color(0xFF197B63),
                ),
                _ProfitMetric(
                  width: metricWidth,
                  label: 'Cost of goods',
                  value: Money.rs(totals.cost),
                  note: 'Recorded cost at time of sale',
                  icon: PhosphorIconsRegular.shoppingBag,
                  color: const Color(0xFF5472A8),
                ),
                _ProfitMetric(
                  width: metricWidth,
                  label: 'Units sold',
                  value: '${totals.units}',
                  note: 'Across completed sales',
                  icon: PhosphorIconsRegular.package,
                  color: const Color(0xFF8A61C9),
                ),
                _ProfitMetric(
                  width: metricWidth,
                  label: 'Profit per unit',
                  value: Money.rs(
                    totals.units == 0 ? 0 : totals.profit / totals.units,
                  ),
                  note: 'Average for selected period',
                  icon: PhosphorIconsRegular.chartLineUp,
                  color: const Color(0xFFCE8A36),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _PremiumPanel(
              title: 'Profit trend',
              subtitle:
                  'Daily profit over the last ${controller.periodDays.value} days',
              icon: PhosphorIconsRegular.chartLineUp,
              child: SizedBox(
                height: compact ? 210 : 270,
                child: _trendChart(context),
              ),
            ),
            const SizedBox(height: 16),
            _PremiumPanel(
              title: 'Price & margin check',
              subtitle:
                  'Compare your current pricing scenarios against product cost.',
              icon: PhosphorIconsRegular.scales,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final scenario in controller.priceScenarios)
                    _PriceScenario(
                      label: scenario.$1,
                      price: scenario.$2,
                      cost: product?.cost ?? 0,
                    ),
                  if (controller.priceScenarios.isEmpty)
                    const EmptyState(
                      title: 'No pricing scenarios available',
                      message: 'Add a price to this product to see its margin.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PremiumPanel(
              title: 'Recent sale lines',
              subtitle:
                  'Sales containing this product during the selected period.',
              icon: PhosphorIconsRegular.receipt,
              trailing: Text(
                '${controller.selectedProductOrders.length} orders',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              padding: EdgeInsets.zero,
              child: AppTable(
                minWidth: 720,
                emptyTitle: 'No sales in this period',
                columns: const [
                  DataColumn2(label: Text('Bill')),
                  DataColumn2(label: Text('Date')),
                  DataColumn2(label: Text('Audience')),
                  DataColumn2(label: Text('Qty'), numeric: true),
                  DataColumn2(label: Text('Price'), numeric: true),
                  DataColumn2(label: Text('Profit'), numeric: true),
                ],
                rows: [
                  for (final order in controller.selectedProductOrders)
                    for (final line in order.items.where(
                      (item) => item.productId == controller.productId.value,
                    ))
                      DataRow(
                        cells: [
                          DataCell(Text(order.number)),
                          DataCell(Text(_formatDate(order.createdAt))),
                          DataCell(
                            StatusChip(
                              label: order.customerType.toLowerCase() == 'shop'
                                  ? 'Shop'
                                  : 'Home',
                              tone: StatusTone.info,
                            ),
                          ),
                          DataCell(Text('${line.qty}')),
                          DataCell(Text(Money.rs(line.unitPrice))),
                          DataCell(
                            Text(
                              Money.rs(
                                (line.unitPrice - line.costAtSale) * line.qty,
                              ),
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
            if (controller.canLoadMore) ...[
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: controller.loadingMore.value
                      ? null
                      : controller.loadMore,
                  icon: controller.loadingMore.value
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(PhosphorIconsRegular.arrowDown, size: 16),
                  label: Text(
                    controller.loadingMore.value
                        ? 'Loading sales...'
                        : 'Load more sales',
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  });

  Widget _trendChart(BuildContext context) {
    final values = controller.dailyProfit;
    final spots = [
      for (var index = 0; index < values.length; index++)
        FlSpot(index.toDouble(), values[index]),
    ];
    final low = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final high = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    final minimumY = low < 0 ? low * 1.2 : 0.0;
    final maximumY = high <= 0 ? 1.0 : high * 1.2;
    return LineChart(
      LineChartData(
        minY: minimumY,
        maxY: maximumY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.65),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: const LineTouchData(
          touchTooltipData: LineTouchTooltipData(),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.22,
            barWidth: 3,
            color: theme.colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  String _formatDate(DateTime? date) =>
      date == null ? '—' : DateFormat('dd MMM yyyy').format(date);
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: compact ? 44 : 50,
          height: compact ? 44 : 50,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            PhosphorIconsRegular.chartLineUp,
            color: theme.colorScheme.primary,
            size: 23,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRODUCT PERFORMANCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Item profitability',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: compact ? 23 : 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.65,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Understand your margins and make confident pricing decisions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductSelector extends StatelessWidget {
  const _ProductSelector({required this.controller, required this.compact});

  final ItemProfitController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedProduct = controller.selectedProduct;
    final selectedId = selectedProduct?.id;
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: compact ? 250 : 330,
            child: DropdownButtonFormField<String>(
              key: ValueKey(selectedId),
              initialValue: selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Product',
                prefixIcon: Icon(PhosphorIconsRegular.package),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                if (selectedProduct?.id != null)
                  DropdownMenuItem(
                    value: selectedProduct!.id,
                    child: Text(
                      selectedProduct.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.productId.value = value;
              },
            ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 days')),
              ButtonSegment(value: 30, label: Text('30 days')),
              ButtonSegment(value: 90, label: Text('90 days')),
            ],
            selected: {controller.periodDays.value},
            onSelectionChanged: (values) =>
                controller.periodDays.value = values.first,
            showSelectedIcon: false,
          ),
          StatusChip(
            label: '${controller.belowCostCount} below-cost prices',
            tone: controller.belowCostCount == 0
                ? StatusTone.good
                : StatusTone.warn,
          ),
        ],
      ),
    );
  }
}

class _ProfitHero extends StatelessWidget {
  const _ProfitHero({
    required this.product,
    required this.profit,
    required this.margin,
    required this.periodDays,
  });

  final ProductRecord? product;
  final double profit;
  final double margin;
  final int periodDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C4738), Color(0xFF0D7357), Color(0xFF12856A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C6049).withValues(alpha: 0.17),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -110,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 34,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width < 700 ? 18 : 24,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final details = Row(
                  children: [
                    _ProductThumbnail(
                      product: product,
                      size: 58,
                      inverted: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELECTED PRODUCT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            product?.name ?? 'Product performance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                                  if (product?.category.isNotEmpty == true)
                                    product!.category,
                                  if (product?.sku.isNotEmpty == true)
                                    'SKU ${product!.sku}',
                                ].join('  ·  ').isEmpty
                                ? 'Performance summary'
                                : [
                                    if (product?.category.isNotEmpty == true)
                                      product!.category,
                                    if (product?.sku.isNotEmpty == true)
                                      'SKU ${product!.sku}',
                                  ].join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.73),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final result = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PROFIT · LAST $periodDays DAYS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      Money.rs(profit),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: narrow ? 30 : 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Margin ${margin.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [details, const SizedBox(height: 22), result],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 22),
                    SizedBox(width: 230, child: result),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitMetric extends StatelessWidget {
  const _ProfitMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.025,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.025,
            ),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: padding == EdgeInsets.zero
                ? const EdgeInsets.fromLTRB(18, 18, 18, 16)
                : EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          if (padding == EdgeInsets.zero)
            child
          else ...[
            const SizedBox(height: 18),
            child,
          ],
        ],
      ),
    );
  }
}

class _PriceScenario extends StatelessWidget {
  const _PriceScenario({
    required this.label,
    required this.price,
    required this.cost,
  });

  final String label;
  final double price;
  final double cost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profit = price - cost;
    final profitable = profit >= 0;
    final color = profitable
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Container(
      width: 224,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  Money.rs(price),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                profitable
                    ? PhosphorIconsRegular.trendUp
                    : PhosphorIconsRegular.trendDown,
                size: 17,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${profitable ? 'Unit profit' : 'Unit loss'}  ${Money.rs(profit.abs())}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({
    required this.product,
    this.size = 38,
    this.inverted = false,
  });

  final ProductRecord? product;
  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = product?.imageUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.14)
            : theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size > 40 ? 15 : 11),
        border: inverted
            ? Border.all(color: Colors.white.withValues(alpha: 0.16))
            : null,
      ),
      child: image == null || image.isEmpty
          ? Icon(
              PhosphorIconsRegular.package,
              size: size * 0.48,
              color: inverted ? Colors.white : theme.colorScheme.primary,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                PhosphorIconsRegular.package,
                size: size * 0.48,
                color: inverted ? Colors.white : theme.colorScheme.primary,
              ),
            ),
    );
  }
}
