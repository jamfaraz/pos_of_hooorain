import 'package:data_table_2/data_table_2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/inventory_controller.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_table.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/status_chip.dart';
import 'stock_in_drawer.dart';

class InventoryScreen extends GetView<InventoryController> {
  const InventoryScreen({super.key});

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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        PageHeader(
          title: 'Inventory',
          subtitle: 'Current stock, low-stock alerts and purchase movements.',
          actions: [
            AppButton(
              label: 'Add stock',
              icon: const Icon(PhosphorIconsRegular.plus),
              onPressed: controller.products.isEmpty
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      builder: (_) => StockInDrawer(
                        controller: controller,
                        products: controller.products.toList(),
                      ),
                    ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show low stock only'),
          value: controller.lowStockOnly.value,
          onChanged: (value) => controller.lowStockOnly.value = value,
        ),
        if (controller.loading.value && controller.products.isEmpty)
          const AppLoader(label: 'Loading inventory...')
        else if (controller.products.isEmpty)
          const EmptyState(title: 'No products to inventory')
        else
          AppTable(
            minWidth: 720,
            columns: const [
              DataColumn2(label: Text('Product'), size: ColumnSize.L),
              DataColumn2(label: Text('SKU')),
              DataColumn2(label: Text('Quantity')),
              DataColumn2(label: Text('Reorder at')),
              DataColumn2(label: Text('Status')),
            ],
            rows: controller.visibleProducts.map((product) {
              final low =
                  product.reorderLevel > 0 &&
                  product.stock <= product.reorderLevel;
              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text(product.sku.isEmpty ? '—' : product.sku)),
                  DataCell(Text('${product.stock}')),
                  DataCell(Text('${product.reorderLevel}')),
                  DataCell(
                    StatusChip(
                      label: low ? 'Low stock' : 'In stock',
                      tone: low ? StatusTone.warn : StatusTone.good,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        const SizedBox(height: 28),
        Text(
          'Stock movement history',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (controller.loading.value && controller.movements.isEmpty)
          const AppLoader(label: 'Loading stock movements...')
        else if (controller.movements.isEmpty)
          const EmptyState(title: 'No stock movements recorded')
        else
          AppTable(
            minWidth: 740,
            columns: const [
              DataColumn2(label: Text('Date')),
              DataColumn2(label: Text('Product'), size: ColumnSize.L),
              DataColumn2(label: Text('Type')),
              DataColumn2(label: Text('Quantity')),
              DataColumn2(label: Text('Note'), size: ColumnSize.L),
            ],
            rows: controller.movements.map((movement) {
              final product = controller.productById(
                movement['productId']?.toString(),
              );
              final date = movement['createdAt'];
              return DataRow(
                cells: [
                  DataCell(Text(_formatDate(date))),
                  DataCell(Text(product?.name ?? 'Unknown product')),
                  DataCell(
                    StatusChip(
                      label: movement['type']?.toString() ?? 'movement',
                      tone: StatusTone.info,
                    ),
                  ),
                  DataCell(Text('${movement['qty'] ?? 0}')),
                  DataCell(
                    Text(
                      movement['note']?.toString().isNotEmpty == true
                          ? movement['note'].toString()
                          : '—',
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        if (controller.movements.isNotEmpty)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: controller.loadingMore.value
                  ? null
                  : controller.loadMoreMovements,
              child: Text(
                controller.loadingMore.value
                    ? 'Loading…'
                    : 'Load more movements',
              ),
            ),
          ),
        if (controller.error.value != null)
          Text(
            controller.error.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  });

  String _formatDate(dynamic value) {
    DateTime? date;
    if (value is DateTime) date = value;
    if (value is Timestamp) date = value.toDate();
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
