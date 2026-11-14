import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/dashboard_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.error.value != null &&
        controller.loadingOrders.value &&
        controller.loadingProducts.value) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Dashboard',
          subtitle: "Today's sales, order activity and stock health.",
        ),
        if (controller.loadingOrders.value || controller.loadingProducts.value)
          const AppLoader(label: 'Loading dashboard metrics...')
        else
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              KpiCard(
                label: "Today's sales",
                value: Money.rs(controller.todaySales),
                icon: PhosphorIconsRegular.currencyDollar,
              ),
              KpiCard(
                label: "Today's orders",
                value: '${controller.todayOrders.length}',
                icon: PhosphorIconsRegular.receipt,
              ),
              KpiCard(
                label: "Today's profit",
                value: Money.rs(controller.todayProfit),
                icon: PhosphorIconsRegular.trendUp,
              ),
              KpiCard(
                label: 'Low stock',
                value: '${controller.lowStock.length}',
                icon: PhosphorIconsRegular.warningCircle,
              ),
            ],
          ),
        const SizedBox(height: 22),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales · last 7 days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(height: 220, child: _salesChart(context)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profit · last 7 days',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(height: 220, child: _profitChart(context)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent orders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (controller.loadingOrders.value)
                      const AppLoader(label: 'Loading charts...')
                    else if (controller.orders.isEmpty)
                      const EmptyState(title: 'No orders yet')
                    else
                      ...controller.orders
                          .take(5)
                          .map(
                            (order) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(PhosphorIconsRegular.receipt),
                              title: Text('#${order.number}'),
                              subtitle: Text(order.status),
                              trailing: Text(Money.rs(order.total)),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Low stock',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (controller.loadingProducts.value)
                      const AppLoader(label: 'Loading charts...')
                    else if (controller.lowStock.isEmpty)
                      const EmptyState(title: 'Stock levels look good')
                    else
                      ...controller.lowStock
                          .take(5)
                          .map(
                            (product) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(product.name),
                              trailing: Text('${product.stock} left'),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  });

  Widget _salesChart(BuildContext context) {
    final values = controller.weeklySales;
    final maxY = values.fold(
      0.0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 10 : maxY * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
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
              reservedSize: 64,
              getTitlesWidget: (value, _) => Text(
                Money.rs(value),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final date = DateTime.now().subtract(
                  Duration(days: 6 - value.toInt()),
                );
                return Text(
                  '${date.day}/${date.month}',
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < values.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _profitChart(BuildContext context) {
    final values = controller.weeklyProfit;
    final maxValue = values.fold(0.0, (a, b) => a > b ? a : b);
    final minValue = values.fold(0.0, (a, b) => a < b ? a : b);
    return BarChart(
      BarChartData(
        minY: minValue < 0 ? minValue * 1.2 : 0,
        maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (var index = 0; index < values.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                  color: values[index] < 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
