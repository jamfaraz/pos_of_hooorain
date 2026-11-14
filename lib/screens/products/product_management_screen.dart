import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/product_management_controller.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_table.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import 'product_editor_drawer.dart';

class ProductManagementScreen extends GetView<ProductManagementController> {
  const ProductManagementScreen({this.initialMode = 'all', super.key});

  final String initialMode;

  @override
  Widget build(BuildContext context) {
    if (initialMode != 'all' && controller.mode.value != initialMode) {
      controller.mode.value = initialMode;
    }
    return Obx(() {
      final currentMode = initialMode == 'all'
          ? controller.mode.value
          : initialMode;
      final title = switch (currentMode) {
        'featured' => 'Featured products',
        'hidden' => 'Hidden products',
        _ => 'Products & prices',
      };
      final products = controller.filteredProducts;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: title,
            subtitle: 'Manage product visibility, pricing and stock.',
            actions: [
              if (initialMode == 'featured')
                AppButton(
                  label: 'Feature a product',
                  icon: const Icon(PhosphorIconsRegular.plus),
                  onPressed: () => _featureProduct(context),
                ),
              if (initialMode == 'all')
                AppButton(
                  label: 'Add product',
                  icon: const Icon(PhosphorIconsRegular.plus),
                  onPressed: () => ProductEditorDrawer.show(null),
                ),
            ],
          ),
          if (initialMode == 'all')
            Wrap(
              spacing: 8,
              children: [
                _modeTab('all', 'All', controller.products.length),
                _modeTab(
                  'featured',
                  'Featured',
                  controller.products.where((p) => p.featured).length,
                ),
                _modeTab(
                  'hidden',
                  'Hidden',
                  controller.products.where((p) => !p.active).length,
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => controller.search.value = value,
            decoration: const InputDecoration(
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              hintText: 'Search by product name or SKU',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: controller.loading.value
                ? const AppLoader(label: 'Loading products...')
                : controller.error.value != null
                ? ErrorRetryWidget(
                    errorMessage: controller.error.value!,
                    onRetry: controller.reload,
                  )
                : products.isEmpty
                ? EmptyState(
                    title: 'No products found',
                    message: 'Products will appear here when added.',
                    actionLabel: currentMode == 'all' ? 'Add product' : null,
                    onAction: initialMode == 'all'
                        ? () => ProductEditorDrawer.show(null)
                        : null,
                  )
                : Column(
                    children: [
                      Expanded(child: _table(context, products)),
                      if (controller.canLoadMore.value)
                        TextButton(
                          onPressed: controller.loadingMore.value
                              ? null
                              : controller.loadMore,
                          child: Text(
                            controller.loadingMore.value
                                ? 'Loading…'
                                : 'Load more',
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      );
    });
  }

  Widget _modeTab(String mode, String label, int count) => Obx(
    () => ChoiceChip(
      label: Text('$label  $count'),
      selected: controller.mode.value == mode,
      onSelected: (_) => controller.mode.value = mode,
    ),
  );

  Widget _table(BuildContext context, List<ProductRecord> products) => AppTable(
    minWidth: 1120,
    columns: const [
      DataColumn2(label: Text('Product'), size: ColumnSize.L),
      DataColumn2(label: Text('MRP'), numeric: true),
      DataColumn2(label: Text('Home'), numeric: true),
      DataColumn2(label: Text('Shop'), numeric: true),
      DataColumn2(label: Text('Qty'), numeric: true),
      DataColumn2(label: Text('Bulk')),
      DataColumn2(label: Text('Rating')),
      DataColumn2(label: Text('Featured')),
      DataColumn2(label: Text('Visible')),
      DataColumn2(label: Text('Actions'), size: ColumnSize.M),
    ],
    rows: products
        .map(
          (product) => DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    _productThumbnail(context, product),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${controller.categoryName(product.categoryId)}${product.subcategory.isEmpty ? '' : ' > ${product.subcategory}'}${product.sku.isEmpty ? '' : ' · SKU ${product.sku}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (controller.hasLiveOffer(product))
                            const Text(
                              'Live offer',
                              style: TextStyle(
                                color: Color(0xFF0F7B5F),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(Money.rs(product.mrp))),
              DataCell(Text(Money.rs(product.homePrice))),
              DataCell(Text(Money.rs(product.shopPrice))),
              DataCell(Text('${product.stock}')),
              DataCell(
                product.bulkEnabled
                    ? const Chip(label: Text('Bulk'))
                    : const Text('—'),
              ),
              DataCell(
                Text(
                  '${product.ratingAvg.toStringAsFixed(1)} (${product.ratingCount})',
                ),
              ),
              DataCell(
                Switch(
                  value: product.featured,
                  onChanged: (value) => _confirmProductToggle(
                    context,
                    product,
                    value,
                    featured: true,
                  ),
                ),
              ),
              DataCell(
                Switch(
                  value: product.active,
                  onChanged: (value) => _confirmProductToggle(
                    context,
                    product,
                    value,
                    featured: false,
                  ),
                ),
              ),
              DataCell(
                Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Edit product',
                      onPressed: () => ProductEditorDrawer.show(product),
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                    ),
                    ConfirmTapButton(
                      label: 'Delete',
                      confirmLabel: 'Delete',
                      confirmTitle: 'Delete product?',
                      confirmMessage:
                          'If this product has sales history, it will be hidden instead of deleted.',
                      onConfirmed: () async {
                        try {
                          final deleted = await controller.deleteOrHide(
                            product,
                          );
                          Get.snackbar(
                            deleted ? 'Product deleted' : 'Product hidden',
                            deleted
                                ? product.name
                                : 'Sales history exists, so the product was hidden.',
                          );
                        } catch (exception) {
                          Get.snackbar(
                            'Could not delete product',
                            exception.toString(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .toList(),
  );

  Widget _productThumbnail(BuildContext context, ProductRecord product) {
    final imageUrl = product.images.isNotEmpty
        ? product.images.first
        : product.imageUrl;
    final fallback = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        PhosphorIconsRegular.image,
        size: 19,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
    if (imageUrl == null || imageUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.network(
        imageUrl,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Future<void> _confirmProductToggle(
    BuildContext context,
    ProductRecord product,
    bool value, {
    required bool featured,
  }) async {
    final title = featured
        ? value
              ? 'Feature product?'
              : 'Remove from featured?'
        : value
        ? 'Make product visible?'
        : 'Hide product?';
    final action = featured
        ? value
              ? 'Feature'
              : 'Remove'
        : value
        ? 'Make visible'
        : 'Hide';
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: title,
      message: featured
          ? '"${product.name}" will ${value ? 'appear in' : 'be removed from'} the featured section.'
          : '"${product.name}" will ${value ? 'be available' : 'no longer be available'} to customers.',
      icon: featured
          ? PhosphorIconsRegular.star
          : value
          ? PhosphorIconsRegular.eye
          : PhosphorIconsRegular.eyeSlash,
      iconColor: featured
          ? Theme.of(context).colorScheme.primary
          : value
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.error,
      positiveButtonText: action,
    );
    if (confirmed != true) return;
    try {
      if (featured) {
        await controller.toggleFeatured(product, value);
      } else {
        await controller.toggleVisible(product, value);
      }
    } catch (exception) {
      Get.snackbar('Could not update product', exception.toString());
    }
  }

  Future<void> _featureProduct(BuildContext context) async {
    final candidates = controller.products
        .where((product) => !product.featured && product.active)
        .toList();
    if (candidates.isEmpty) {
      Get.snackbar(
        'No products available',
        'All visible products are already featured.',
      );
      return;
    }
    final selected = await showDialog<ProductRecord>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Feature a product'),
        children: candidates
            .map(
              (product) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(product),
                child: Text(product.name),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) await controller.toggleFeatured(selected, true);
  }
}
