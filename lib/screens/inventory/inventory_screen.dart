import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_table.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/status_chip.dart';
import '../products/product_editor_drawer.dart';
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

    final theme = Theme.of(context);
    final totalCost = controller.inventoryStockValue;
    final retailValue = controller.inventoryRetailValue;
    final profit = controller.inventoryExpectedProfit;
    final margin = retailValue <= 0 ? 0.0 : profit / retailValue * 100;
    final categoryValues = controller.categoryStockValues;
    final maxCategoryValue = categoryValues.isEmpty
        ? 1.0
        : categoryValues.first.$2;
    final filtered = controller.visibleProducts;
    final filteredUnits = filtered.fold<int>(
      0,
      (total, product) => total + (product.stock > 0 ? product.stock : 0),
    );
    final filteredCost = filtered.fold<double>(
      0,
      (total, product) =>
          total +
          (product.stock > 0
              ? product.stock.toDouble() * product.inventoryCost
              : 0),
    );
    final filteredRetail = filtered.fold<double>(
      0,
      (total, product) =>
          total +
          (product.stock > 0 ? product.stock.toDouble() * product.price : 0),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock value',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How much stock is in the godown, and what it is worth.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
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
        const SizedBox(height: 18),
        if (controller.loading.value && controller.products.isEmpty)
          const AppLoader(label: 'Loading inventory...')
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: cols == 1
                    ? 3.6
                    : cols == 2
                    ? 2.4
                    : 2.15,
                children: [
                  _StockKpi(
                    label: 'Total stock value (cost)',
                    value: Money.rs(totalCost),
                    detail: 'What all stock in the godown cost you',
                    icon: PhosphorIconsRegular.package,
                    hero: true,
                  ),
                  _StockKpi(
                    label: 'Units in godown',
                    value: '${controller.inventoryUnitCount}',
                    detail:
                        '${controller.inStockProductCount} products in stock',
                    icon: PhosphorIconsRegular.listBullets,
                  ),
                  _StockKpi(
                    label: 'Value at selling price',
                    value: Money.rs(retailValue),
                    detail: "If everything sells at today's price",
                    icon: PhosphorIconsRegular.tag,
                  ),
                  _StockKpi(
                    label: 'Expected profit',
                    value: Money.rs(profit),
                    detail: '${margin.toStringAsFixed(1)}% margin on stock',
                    icon: PhosphorIconsRegular.trendUp,
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Where the stock money sits',
          subtitle: 'Stock value at cost, by category',
          child: categoryValues.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(title: 'No category stock values'),
                )
              : Column(
                  children: [
                    for (final entry in categoryValues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(
                                entry.$1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  minHeight: 12,
                                  value: maxCategoryValue <= 0
                                      ? 0
                                      : entry.$2 / maxCategoryValue,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  color: const Color(0xFF2A78D6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: Text(
                                Money.rs(entry.$2),
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _Panel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final search = SizedBox(
                    width: compact ? double.infinity : 220,
                    height: 40,
                    child: TextField(
                      onChanged: (value) =>
                          controller.searchQuery.value = value,
                      decoration: const InputDecoration(
                        hintText: 'Search product or SKU',
                        prefixIcon: Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 18,
                        ),
                        isDense: true,
                      ),
                    ),
                  );
                  final category = SizedBox(
                    width: compact ? double.infinity : 180,
                    height: 40,
                    child: DropdownButtonFormField<String>(
                      initialValue: controller.selectedCategory.value,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'All',
                          child: Text('All categories'),
                        ),
                        for (final category in controller.categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.selectedCategory.value = value;
                        }
                      },
                    ),
                  );
                  final sort = _SortSegment(
                    value: controller.sortMode.value,
                    onChanged: (value) => controller.sortMode.value = value,
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            search,
                            const SizedBox(height: 10),
                            category,
                            const SizedBox(height: 10),
                            sort,
                          ],
                        )
                      : Row(
                          children: [
                            search,
                            const SizedBox(width: 10),
                            category,
                            const SizedBox(width: 10),
                            sort,
                          ],
                        );
                },
              ),
              const SizedBox(height: 14),
              if (controller.loading.value && filtered.isEmpty)
                const AppLoader(label: 'Loading stock...')
              else if (filtered.isEmpty)
                const EmptyState(title: 'No products match')
              else
                AppTable(
                  minWidth: 1240,
                  headingRowHeight: 46,
                  dataRowHeight: 64,
                  columns: const [
                    DataColumn2(label: Text('Product'), size: ColumnSize.L),
                    DataColumn2(label: Text('Available qty')),
                    DataColumn2(label: Text('Price (cost)')),
                    DataColumn2(label: Text('Total stock price')),
                    DataColumn2(label: Text('Selling price')),
                    DataColumn2(label: Text('Selling value')),
                    DataColumn2(label: Text('Share')),
                    DataColumn2(label: Text('Status')),
                    DataColumn2(label: Text('Edit')),
                  ],
                  rows: [
                    for (final product in filtered)
                      _productRow(context, product, totalCost),
                    DataRow(
                      color: WidgetStatePropertyAll(
                        theme.colorScheme.surfaceContainerHighest,
                      ),
                      cells: [
                        const DataCell(
                          Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        DataCell(
                          Text(
                            '$filteredUnits',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const DataCell(Text('')),
                        DataCell(
                          Text(
                            Money.rs(filteredCost),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const DataCell(Text('')),
                        DataCell(
                          Text(
                            Money.rs(filteredRetail),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Total stock price = available qty × cost price.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  });

  DataRow _productRow(
    BuildContext context,
    ProductRecord product,
    double totalCost,
  ) {
    final isLow =
        product.reorderLevel > 0 && product.stock <= product.reorderLevel;
    final isOut = product.stock <= 0;
    final stockValue = product.stock > 0
        ? product.stock * product.inventoryCost
        : 0.0;
    final sellingValue = product.stock > 0
        ? product.stock * product.price
        : 0.0;
    final share = totalCost <= 0 ? 0.0 : stockValue / totalCost * 100;
    final cs = Theme.of(context).colorScheme;
    final imageUrl = product.images.isNotEmpty
        ? product.images.first
        : product.imageUrl;

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: cs.primaryContainer),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                cs.primaryContainer,
                                cs.primary.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                          child: Icon(
                            PhosphorIconsRegular.package,
                            size: 18,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${product.category.isEmpty ? 'Uncategorised' : product.category} · ${product.sku.isEmpty ? '—' : product.sku}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            '${product.stock}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text(Money.rs(product.inventoryCost))),
        DataCell(
          Text(
            Money.rs(stockValue),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(Text(Money.rs(product.price))),
        DataCell(Text(Money.rs(sellingValue))),
        DataCell(Text('${share.toStringAsFixed(1)}%')),
        DataCell(
          StatusChip(
            label: isOut
                ? 'Out'
                : isLow
                ? 'Low stock'
                : 'In stock',
            tone: isOut
                ? StatusTone.bad
                : isLow
                ? StatusTone.warn
                : StatusTone.good,
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Edit product',
            onPressed: () => ProductEditorDrawer.show(product),
            icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
          ),
        ),
      ],
    );
  }
}

class _StockKpi extends StatelessWidget {
  const _StockKpi({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.hero = false,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hero
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.surface,
                ],
              )
            : null,
        color: hero ? null : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
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
              Icon(icon, size: 18, color: AppColors.primary),
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
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: hero
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

class _SortSegment extends StatelessWidget {
  const _SortSegment({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = const [
      ('value', 'Highest value'),
      ('qty', 'Most qty'),
      ('low', 'Least qty'),
      ('name', 'A to Z'),
    ];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => onChanged(option.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == option.$1
                      ? theme.colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: value == option.$1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option.$2,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: value == option.$1
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
