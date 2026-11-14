import 'package:data_table_2/data_table_2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/item_profit_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_table.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
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
    final product = controller.selectedProduct;
    final totals = controller.selectedTotals;
    final makingProfit = totals.profit >= 0;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Item profit',
          subtitle:
              'Profit is calculated from each sale’s costAtSale snapshot.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: CommonDropdown<String>(
                label: 'Product',
                bottomSpacing: 0,
                value: controller.productId.value,
                items: controller.products
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => controller.productId.value = value,
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
            ),
            if (product != null)
              StatusChip(
                label: makingProfit ? 'Making profit' : 'Losing money',
                tone: makingProfit ? StatusTone.good : StatusTone.bad,
              ),
            StatusChip(
              label: '${controller.belowCostCount} prices below cost',
              tone: controller.belowCostCount == 0
                  ? StatusTone.good
                  : StatusTone.warn,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            KpiCard(
              label: 'Units sold',
              value: '${totals.units}',
              icon: PhosphorIconsRegular.package,
            ),
            KpiCard(
              label: 'Sales',
              value: Money.rs(totals.sales),
              icon: PhosphorIconsRegular.currencyDollar,
            ),
            KpiCard(
              label: 'Cost of goods',
              value: Money.rs(totals.cost),
              icon: PhosphorIconsRegular.shoppingBag,
            ),
            KpiCard(
              label: totals.profit < 0 ? 'Loss' : 'Profit',
              value: Money.rs(totals.profit),
              caption: 'Margin ${totals.margin.toStringAsFixed(1)}%',
              icon: totals.profit < 0
                  ? PhosphorIconsRegular.trendDown
                  : PhosphorIconsRegular.trendUp,
              accentColor: totals.profit < 0 ? Colors.red : Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profit trend',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              SizedBox(height: 220, child: _trendChart(context)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (controller.canLoadMore)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: controller.loadingMore.value
                  ? null
                  : controller.loadMore,
              child: Text(
                controller.loadingMore.value
                    ? 'Loading more sales…'
                    : 'Load more sales',
              ),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Text('Price check'),
              ),
              AppTable(
                minWidth: 520,
                columns: const [
                  DataColumn2(label: Text('Scenario'), size: ColumnSize.L),
                  DataColumn2(label: Text('Price')),
                  DataColumn2(label: Text('Profit / unit')),
                  DataColumn2(label: Text('Status')),
                ],
                rows: [
                  for (final scenario in controller.priceScenarios)
                    DataRow(
                      cells: [
                        DataCell(Text(scenario.$1)),
                        DataCell(Text(Money.rs(scenario.$2))),
                        DataCell(
                          Text(Money.rs(scenario.$2 - (product?.cost ?? 0))),
                        ),
                        DataCell(
                          StatusChip(
                            label: scenario.$2 > (product?.cost ?? 0)
                                ? 'Gain'
                                : scenario.$2 < (product?.cost ?? 0)
                                ? 'Loss'
                                : 'Break even',
                            tone: scenario.$2 > (product?.cost ?? 0)
                                ? StatusTone.good
                                : scenario.$2 < (product?.cost ?? 0)
                                ? StatusTone.bad
                                : StatusTone.info,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Text('Recent sale lines'),
              ),
              AppTable(
                minWidth: 760,
                emptyTitle: 'No sales in this period',
                columns: const [
                  DataColumn2(label: Text('Bill')),
                  DataColumn2(label: Text('Date')),
                  DataColumn2(label: Text('Audience')),
                  DataColumn2(label: Text('Qty')),
                  DataColumn2(label: Text('Price')),
                  DataColumn2(label: Text('Profit')),
                ],
                rows: [
                  for (final order in controller.selectedProductOrders)
                    for (final line in order.items.where(
                      (item) => item.productId == controller.productId.value,
                    ))
                      DataRow(
                        cells: [
                          DataCell(Text(order.number)),
                          DataCell(Text(_date(order.createdAt))),
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
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Text('All products · weakest profit first'),
              ),
              AppTable(
                minWidth: 660,
                columns: const [
                  DataColumn2(label: Text('Product'), size: ColumnSize.L),
                  DataColumn2(label: Text('Units')),
                  DataColumn2(label: Text('Sales')),
                  DataColumn2(label: Text('Profit / loss')),
                ],
                rows: [
                  for (final item in controller.weakestProducts)
                    DataRow(
                      selected: item.id == controller.productId.value,
                      onSelectChanged: (_) =>
                          controller.productId.value = item.id,
                      cells: [
                        DataCell(Text(item.name)),
                        DataCell(Text('${controller.totalsFor(item).units}')),
                        DataCell(
                          Text(Money.rs(controller.totalsFor(item).sales)),
                        ),
                        DataCell(
                          Text(Money.rs(controller.totalsFor(item).profit)),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
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
    return LineChart(
      LineChartData(
        minY: low < 0 ? low * 1.2 : 0,
        maxY: high <= 0 ? 1 : high * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 36),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .12),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  String _date(DateTime? date) => date == null
      ? '—'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
