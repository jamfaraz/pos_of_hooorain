import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/reports_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_table.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';

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
    if (controller.loading.value && controller.orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppLoader(label: 'Loading reports...'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Reports',
          subtitle:
              'Sales by day, category, top products and profit from sale-time cost.',
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
        _section(
          context,
          'Sales by day',
          AppTable(
            columns: const [
              DataColumn2(label: Text('Date')),
              DataColumn2(label: Text('Sales')),
            ],
            rows: controller.salesByDay
                .map(
                  (entry) => DataRow(
                    cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text(Money.rs(entry.value))),
                    ],
                  ),
                )
                .toList(),
            emptyTitle: 'No sales data available',
          ),
        ),
        const SizedBox(height: 16),
        _section(
          context,
          'Sales by category',
          AppTable(
            columns: const [
              DataColumn2(label: Text('Category')),
              DataColumn2(label: Text('Sales')),
            ],
            rows: controller.salesByCategory
                .map(
                  (entry) => DataRow(
                    cells: [
                      DataCell(Text(entry.key)),
                      DataCell(Text(Money.rs(entry.value))),
                    ],
                  ),
                )
                .toList(),
            emptyTitle: 'No category sales available',
          ),
        ),
        const SizedBox(height: 16),
        _section(
          context,
          'Top products and profit',
          AppTable(
            minWidth: 700,
            columns: const [
              DataColumn2(label: Text('Product'), size: ColumnSize.L),
              DataColumn2(label: Text('Units')),
              DataColumn2(label: Text('Sales')),
              DataColumn2(label: Text('Profit')),
            ],
            rows: controller.topProducts.map((product) {
              final stats = controller.productPerformance[product.id];
              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text('${stats?.units ?? 0}')),
                  DataCell(Text(Money.rs(stats?.sales ?? 0))),
                  DataCell(Text(Money.rs(stats?.profit ?? 0))),
                ],
              );
            }).toList(),
            emptyTitle: 'No product sales available',
          ),
        ),
        if (controller.canLoadMore)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: controller.loadingMore.value
                  ? null
                  : controller.loadMore,
              child: Text(
                controller.loadingMore.value
                    ? 'Loading more reports…'
                    : 'Load more data',
              ),
            ),
          ),
        if (controller.error.value != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  });

  Widget _section(BuildContext context, String title, Widget child) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        child,
      ],
    ),
  );

  Future<void> _export() async {
    try {
      final path = await controller.exportCsv();
      if (path != null) Get.snackbar('Report exported', path);
    } catch (exception) {
      Get.snackbar('Could not export report', exception.toString());
    }
  }
}
