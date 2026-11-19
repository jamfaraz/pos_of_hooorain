import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/order_controller.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/order_card.dart';
import '../../widgets/retry_widget.dart';

// ============================================================================
// Helpers
// ============================================================================

String _compact(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1000000) return '$sign${(a / 1000000).toStringAsFixed(1)}M';
  if (a >= 1000) {
    final k = a / 1000;
    return '$sign${k.toStringAsFixed(k >= 100 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '')}k';
  }
  return '$sign${a.toStringAsFixed(0)}';
}

double? _delta(double now, double before) =>
    before <= 0 ? null : (now - before) / before * 100;

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _dateLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

Color _muted(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

BoxDecoration _surface(BuildContext context, {double radius = 20}) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: theme.dividerColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.25 : 0.04,
        ),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Minimal line with a soft area fill. No axes, no grid.
Widget _sparkline(List<double> values, Color color, {double height = 44}) {
  final max = values.fold<double>(0, (m, v) => v > m ? v : m);
  final min = values.fold<double>(max, (m, v) => v < m ? v : m);
  return SizedBox(
    height: height,
    child: LineChart(
      LineChartData(
        minY: min < 0 ? min * 1.2 : 0,
        maxY: max <= 0 ? 1 : max * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.4,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 500),
    ),
  );
}

// ============================================================================
// Screen
// ============================================================================

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

    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final compact = w < 720;
        final wide = w >= 1080;
        final pad = compact ? 4.0 : 8.0;
        final loading =
            controller.loadingOrders.value || controller.loadingProducts.value;

        final sales = controller.weeklySales;
        final profit = controller.weeklyProfit;
        final todaySales = controller.todaySales;
        final todayProfit = controller.todayProfit;
        final orderCount = controller.todayOrders.length;
        final yesterdaySales = sales.length >= 2 ? sales[sales.length - 2] : 0.0;
        final salesDelta = _delta(todaySales, yesterdaySales);
        final margin = todaySales <= 0 ? 0.0 : todayProfit / todaySales * 100;
        final weekSales = sales.fold<double>(0, (a, b) => a + b);
        final weekProfit = profit.fold<double>(0, (a, b) => a + b);
        final avgOrder = orderCount == 0 ? 0.0 : todaySales / orderCount;

        final kpis = [
          _KpiData(
            label: 'Orders today',
            value: '$orderCount',
            note: 'Counter and online',
            icon: PhosphorIconsRegular.receipt,
            color: AppColors.info,
          ),
          _KpiData(
            label: 'Net profit today',
            value: Money.rs(todayProfit),
            note: 'Margin ${margin.toStringAsFixed(1)}%',
            icon: PhosphorIconsRegular.chartLineUp,
            color: Theme.of(context).colorScheme.primary,
            series: profit,
          ),
          _KpiData(
            label: 'Average order',
            value: Money.rs(avgOrder),
            note: 'Per order, today',
            icon: PhosphorIconsRegular.shoppingBag,
            color: Theme.of(context).colorScheme.secondary,
          ),
          _KpiData(
            label: 'Low stock',
            value: '${controller.lowStock.length}',
            note: controller.lowStock.isEmpty
                ? 'All stocked'
                : 'Needs attention',
            icon: PhosphorIconsRegular.warningCircle,
            color: controller.lowStock.isEmpty
                ? AppColors.ok
                : AppColors.warning,
          ),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
          children: [
            _Header(compact: compact, onRefresh: controller.reload),
            const SizedBox(height: 20),
            _HeroCard(
              compact: compact,
              todaySales: todaySales,
              delta: salesDelta,
              orders: orderCount,
              weekSales: weekSales,
              weekProfit: weekProfit,
              series: sales,
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: AppLoader(label: 'Loading dashboard...'),
              )
            else
              _kpiGrid(kpis, w),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _TrendCard(sales: sales, profit: profit)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _ChannelCard(controller: controller)),
                ],
              )
            else ...[
              _TrendCard(sales: sales, profit: profit),
              const SizedBox(height: 16),
              _ChannelCard(controller: controller),
            ],
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _recentOrders(context)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _stockPanel(context)),
                ],
              )
            else ...[
              _recentOrders(context),
              const SizedBox(height: 16),
              _stockPanel(context),
            ],
          ],
        );
      },
    );
  });

  Widget _kpiGrid(List<_KpiData> items, double w) {
    final cols = w >= 1080 ? 4 : (w >= 560 ? 2 : 1);
    const gap = 14.0;
    final itemW = (w - 8 - gap * (cols - 1)) / cols;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final k in items) SizedBox(width: itemW, child: _KpiCard(data: k)),
      ],
    );
  }

  Widget _recentOrders(BuildContext context) => _Panel(
    title: 'Recent orders',
    subtitle: 'Latest activity across counter and online',
    icon: PhosphorIconsRegular.receipt,
    trailing: TextButton(
      onPressed: () => Get.toNamed('/orders'),
      child: const Text('View all'),
    ),
    child: controller.loadingOrders.value
        ? const SizedBox(height: 160, child: AppLoader(label: 'Loading orders...'))
        : controller.orders.isEmpty
        ? const _PanelEmpty(
            icon: PhosphorIconsRegular.receipt,
            message: 'New orders will appear here.',
          )
        : Column(
            children: [
              for (final order in controller.orders.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OrderCard(
                    order: order,
                    compact: true,
                    loadCustomerImage: () =>
                        Get.find<OrderController>().getCustomerImage(order.userId),
                    onTap: () => Get.toNamed('/orders/detail', arguments: order),
                  ),
                ),
            ],
          ),
  );

  Widget _stockPanel(BuildContext context) {
    final low = controller.lowStock;
    return _Panel(
      title: 'Stock attention',
      subtitle: 'Products at or below reorder point',
      icon: PhosphorIconsRegular.package,
      trailing: TextButton(
        onPressed: () => Get.toNamed('/inventory'),
        child: const Text('Inventory'),
      ),
      child: controller.loadingProducts.value
          ? const SizedBox(height: 160, child: AppLoader(label: 'Loading stock...'))
          : low.isEmpty
          ? const _PanelEmpty(
              icon: PhosphorIconsRegular.checkCircle,
              message: 'Stock levels look healthy.',
            )
          : Column(
              children: [
                for (final (i, p) in low.take(6).indexed) ...[
                  _StockRow(product: p),
                  if (i < low.take(6).length - 1) const Divider(height: 1),
                ],
              ],
            ),
    );
  }
}

// ============================================================================
// Header
// ============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.compact, required this.onRefresh});
  final bool compact;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _muted(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Business overview',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: compact ? 24 : 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.calendarBlank, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                _dateLabel(DateTime.now()),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          height: 44,
          child: OutlinedButton(
            onPressed: onRefresh,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 14), actions],
      );
    }
    return Row(children: [Expanded(child: title), actions]);
  }
}

// ============================================================================
// Hero
// ============================================================================

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.compact,
    required this.todaySales,
    required this.delta,
    required this.orders,
    required this.weekSales,
    required this.weekProfit,
    required this.series,
  });

  final bool compact;
  final double todaySales;
  final double? delta;
  final int orders;
  final double weekSales;
  final double weekProfit;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c1 = Color.lerp(cs.primary, Colors.black, 0.55)!;
    final c2 = Color.lerp(cs.primary, Colors.black, 0.85)!;
    final up = (delta ?? 0) >= 0;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE · TODAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (delta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (up ? Colors.greenAccent : Colors.redAccent)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      up ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown,
                      size: 12,
                      color: up ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${up ? '+' : ''}${delta!.toStringAsFixed(0)}% vs yesterday',
                      style: TextStyle(
                        color: up ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          "Today's sales",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Money.rs(todaySales),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 36 : 46,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.6,
              height: 1.05,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$orders ${orders == 1 ? 'order' : 'orders'} recorded today',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12.5,
          ),
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'LAST 7 DAYS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _sparkline(series, Colors.white, height: compact ? 60 : 84),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _heroStat('Sales', Money.rs(weekSales))),
            const SizedBox(width: 10),
            Expanded(child: _heroStat('Profit', Money.rs(weekProfit))),
          ],
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1, c2],
          ),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -80,
              top: -110,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.22),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -120,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.035),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 20 : 30),
              child: LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 700) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [left, const SizedBox(height: 22), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: left),
                      const SizedBox(width: 36),
                      Expanded(flex: 4, child: right),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// KPI cards
// ============================================================================

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.series,
  });
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final List<double>? series;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: _surface(context, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, size: 19, color: data.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _muted(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
          if (data.series != null) ...[
            const SizedBox(height: 10),
            _sparkline(data.series!, data.color, height: 34),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Trend (sales + profit)
// ============================================================================

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.sales, required this.profit});
  final List<double> sales;
  final List<double> profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final all = [...sales, ...profit];
    final maxV = all.fold<double>(0, (m, v) => v > m ? v : m);
    final minV = all.fold<double>(0, (m, v) => v < m ? v : m);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.2;
    final minY = minV < 0 ? minV * 1.2 : 0.0;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10.5,
      color: _muted(context),
    );
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    LineChartBarData line(List<double> v, Color color) => LineChartBarData(
      spots: [for (var i = 0; i < v.length; i++) FlSpot(i.toDouble(), v[i])],
      isCurved: true,
      curveSmoothness: 0.28,
      color: color,
      barWidth: 3,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, p, bar, i) => FlDotCirclePainter(
          radius: i == v.length - 1 ? 5 : 3,
          color: cs.surface,
          strokeWidth: 2.5,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
        ),
      ),
    );

    return _Panel(
      title: 'Revenue and profit',
      subtitle: 'Daily performance for the last 7 days',
      icon: PhosphorIconsRegular.chartLineUp,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legend(context, 'Sales', cs.primary),
          const SizedBox(width: 14),
          _legend(context, 'Profit', cs.secondary),
        ],
      ),
      child: SizedBox(
        height: 280,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (_) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.8),
                strokeWidth: 1,
                dashArray: [4, 4],
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 46,
                  getTitlesWidget: (v, meta) => v == meta.max || v == meta.min
                      ? const SizedBox.shrink()
                      : Text(_compact(v), style: labelStyle),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i > 6) return const SizedBox.shrink();
                    final d = DateTime.now().subtract(Duration(days: 6 - i));
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(days[d.weekday - 1], style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF14201B),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      Money.rs(s.y),
                      TextStyle(
                        color: s.bar.color ?? Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [line(sales, cs.primary), line(profit, cs.secondary)],
          ),
          duration: const Duration(milliseconds: 500),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: _muted(context),
        ),
      ),
    ],
  );
}

// ============================================================================
// Channel split + status
// ============================================================================

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.controller});
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final orders = controller.todayOrders;

    double counter = 0, online = 0;
    for (final o in orders) {
      if (o.channel == 'counter') {
        counter += o.total;
      } else {
        online += o.total;
      }
    }
    final total = counter + online;

    final statuses = <String, int>{};
    for (final o in controller.orders) {
      statuses.update(o.status, (v) => v + 1, ifAbsent: () => 1);
    }
    final statusEntries = statuses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Color statusColor(String s) => switch (s.toLowerCase()) {
      'delivered' => AppColors.ok,
      'accepted' || 'packed' => AppColors.info,
      'pending' => AppColors.warning,
      'cancelled' || 'rejected' => cs.error,
      _ => cs.onSurfaceVariant,
    };

    return _Panel(
      title: 'Sales channels',
      subtitle: 'Counter vs online, today',
      icon: PhosphorIconsRegular.chartDonut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: total <= 0
                ? const _PanelEmpty(
                    icon: PhosphorIconsRegular.chartDonut,
                    message: 'No sales yet today.',
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 56,
                          startDegreeOffset: -90,
                          sections: [
                            PieChartSectionData(
                              value: counter <= 0 ? 0.0001 : counter,
                              color: cs.primary,
                              radius: 18,
                              showTitle: false,
                            ),
                            PieChartSectionData(
                              value: online <= 0 ? 0.0001 : online,
                              color: cs.secondary,
                              radius: 18,
                              showTitle: false,
                            ),
                          ],
                        ),
                        duration: const Duration(milliseconds: 500),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _muted(context),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _compact(total),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          _channelRow(context, 'Counter', counter, total, cs.primary),
          const SizedBox(height: 10),
          _channelRow(context, 'Online', online, total, cs.secondary),
          if (statusEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 14),
            Text(
              'Recent order status',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in statusEntries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(e.key).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.key} · ${e.value}',
                      style: TextStyle(
                        color: statusColor(e.key),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _channelRow(
    BuildContext context,
    String label,
    double value,
    double total,
    Color color,
  ) {
    final theme = Theme.of(context);
    final pct = total <= 0 ? 0.0 : value / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              Money.rs(value),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text(
                '${(pct * 100).round()}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Panels
// ============================================================================

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.product});
  final ProductRecord product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final critical = product.stock <= product.reorderLevel / 2;
    final color = critical ? theme.colorScheme.error : AppColors.warning;
    final progress = product.reorderLevel <= 0
        ? 0.0
        : (product.stock / product.reorderLevel).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PhosphorIconsRegular.package, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.stock} left',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                critical ? 'Urgent' : 'Reorder soon',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}