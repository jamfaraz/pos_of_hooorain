import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/reports_controller.dart';
import '../../utils/money.dart';
import '../../utils/toas_message.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';

class ReportsScreen extends GetView<ReportsController> {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.error.value != null &&
        controller.loading.value &&
        controller.orders.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }

    final theme = Theme.of(context);
    final month = controller.selectedMonth.value;
    final monthName = _monthName(month);
    final sales = controller.salesByDay;
    final monthTotal = controller.selectedMonthSales;
    final average = controller.selectedMonthAverage;
    final best = controller.selectedMonthBestDay;
    final saleDays = sales.where((entry) => entry.value > 0).length;
    final maxSale = sales.fold<double>(
      0,
      (maximum, entry) => entry.value > maximum ? entry.value : maximum,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        PageHeader(
          title: 'Sales report',
          subtitle: 'Daily sales performance for the selected month.',
          actions: [
            AppButton(
              label: controller.exporting.value
                  ? 'Preparing CSV…'
                  : 'Export CSV',
              icon: const Icon(PhosphorIconsRegular.fileCsv),
              onPressed: controller.exporting.value ? null : _export,
            ),
          ],
        ),
        if (controller.loading.value)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AppLoader(label: 'Loading monthly sales...'),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: controller.previousMonth,
                icon: const Icon(PhosphorIconsRegular.caretLeft),
              ),
              Expanded(
                child: Text(
                  monthName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: _canGoNext(month) ? controller.nextMonth : null,
                icon: const Icon(PhosphorIconsRegular.caretRight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.8 : 2.2,
              children: [
                _MetricCard(
                  label: 'Monthly sales',
                  value: Money.rs(monthTotal),
                  icon: PhosphorIconsRegular.currencyCircleDollar,
                  accent: theme.colorScheme.primary,
                ),
                _MetricCard(
                  label: 'Daily average',
                  value: Money.rs(average),
                  icon: PhosphorIconsRegular.chartLineUp,
                  accent: const Color(0xFF2563EB),
                ),
                _MetricCard(
                  label: 'Best sales day',
                  value: best == null || best.value <= 0
                      ? 'No sales'
                      : Money.rs(best.value),
                  detail: best == null || best.value <= 0
                      ? '—'
                      : _dayLabel(best.key),
                  icon: PhosphorIconsRegular.trophy,
                  accent: const Color(0xFFB45309),
                ),
                _MetricCard(
                  label: 'Selling days',
                  value: '$saleDays',
                  detail: 'of ${sales.length} days',
                  icon: PhosphorIconsRegular.calendarCheck,
                  accent: const Color(0xFF059669),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Daily sales',
          subtitle: '$monthName · sales by calendar day',
          child: sales.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: Text('No sales data available')),
                )
              : SizedBox(
                  height: 260,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: (sales.length * 34).clamp(680, 1800).toDouble(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final entry in sales)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (entry.value > 0)
                                      Text(
                                        _compactMoney(entry.value),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              fontSize: 9,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    const SizedBox(height: 5),
                                    Container(
                                      height: maxSale <= 0
                                          ? 4
                                          : 180 * entry.value / maxSale,
                                      constraints: const BoxConstraints(
                                        minHeight: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            theme.colorScheme.primary,
                                            theme.colorScheme.primary
                                                .withValues(alpha: 0.58),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _dayNumber(entry.key),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Day by day',
          subtitle: 'Complete ${monthName.toLowerString()} breakdown',
          child: Column(
            children: [
              for (var i = 0; i < sales.length; i++) ...[
                _DailyRow(
                  date: sales[i].key,
                  value: sales[i].value,
                  monthTotal: monthTotal,
                ),
                if (i != sales.length - 1)
                  Divider(height: 1, color: theme.dividerColor),
              ],
            ],
          ),
        ),
        if (controller.error.value != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error.value!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  });

  static String _monthName(DateTime date) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[date.month - 1]} ${date.year}';
  }

  static bool _canGoNext(DateTime month) {
    final now = DateTime.now();
    return DateTime(
      month.year,
      month.month + 1,
      1,
    ).isBefore(DateTime(now.year, now.month + 1, 1));
  }

  static String _dayNumber(String key) => key.split('-').last;

  static String _dayLabel(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return '${parts[2]} ${_monthName(DateTime(parts[0], parts[1])).split(' ').first}';
  }

  static String _compactMoney(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }

  Future<void> _export() async {
    try {
      final path = await controller.exportCsv();
      if (path != null) {
        MessageToast.showSuccess(msg: path, title: 'Report exported');
      }
    } catch (exception) {
      MessageToast.showError(
        msg: exception.toString(),
        title: 'Could not export report',
      );
    }
  }
}

extension on String {
  String toLowerString() => toLowerCase();
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    required this.date,
    required this.value,
    required this.monthTotal,
  });

  final String date;
  final double value;
  final double monthTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = monthTotal <= 0 ? 0.0 : value / monthTotal;
    final day = int.parse(date.split('-').last);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              'Day $day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: share,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 120,
            child: Text(
              Money.rs(value),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
