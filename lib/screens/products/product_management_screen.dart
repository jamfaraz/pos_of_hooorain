import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/product_management_controller.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import 'product_editor_drawer.dart';

/// Column widths for the product table. The product column takes the rest.
const double _wMrp = 84;
const double _wHome = 98;
const double _wShop = 98;
const double _wStock = 80;
const double _wBulk = 86;
const double _wRating = 98;
const double _wFeatured = 86;
const double _wVisible = 78;
const double _wActions = 168;
const double _kHeaderHeight = 42;
const double _kProductMin = 260;
const double _kSidePad = 16;

double get _tableMinWidth =>
    _kProductMin +
    _wMrp +
    _wHome +
    _wShop +
    _wStock +
    _wBulk +
    _wRating +
    _wFeatured +
    _wVisible +
    _wActions +
    _kSidePad * 2;

class ProductManagementScreen extends GetView<ProductManagementController> {
  const ProductManagementScreen({this.initialMode = 'all', super.key});

  final String initialMode;

  @override
  Widget build(BuildContext context) {
    controller.configureScreen(initialMode);
    return Obx(() {
      final currentMode = initialMode == 'all'
          ? controller.mode.value
          : initialMode;
      final title = switch (currentMode) {
        'featured' => 'Featured products',
        'hidden' => 'Hidden products',
        _ => 'Products',
      };
      final products = controller.filteredProductsFor(currentMode);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: title,
              subtitle:
                  'Every product has a home price and a shop price. Shop owners see the shop price in the app.',
              bottomSpacing: 10,
              titleFontSize: 24,
              actions: [
                if (initialMode == 'all')
                  AppButton(
                    label: 'Categories',
                    style: AppButtonStyle.ghost,
                    icon: const Icon(PhosphorIconsRegular.storefront),
                    onPressed: () => Get.toNamed('/categories'),
                  ),
                if (initialMode == 'all')
                  AppButton(
                    label: 'Add product',
                    icon: const Icon(PhosphorIconsRegular.plus),
                    onPressed: () => ProductEditorDrawer.show(null),
                  ),
              ],
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _toolbar(context, products.length),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  _content(context, products, currentMode),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // --------------------------------------------------------------------
  // Toolbar
  // --------------------------------------------------------------------

  Widget _toolbar(BuildContext context, int shown) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      child: Row(
        children: [
          if (initialMode == 'all') ...[
            _modeSwitcher(context),
            const SizedBox(width: 16),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (value) => controller.search.value = value,
                  style: theme.textTheme.bodySmall,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                    ),
                    hintText: 'Search product or SKU',
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$shown ${shown == 1 ? 'product' : 'products'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSwitcher(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeTab(context, 'all', 'All', controller.productCounts['all'] ?? 0),
          _modeTab(
            context,
            'featured',
            'Featured',
            controller.productCounts['featured'] ?? 0,
          ),
          _modeTab(
            context,
            'hidden',
            'Hidden',
            controller.productCounts['hidden'] ?? 0,
          ),
          if (controller.productCountsError.value != null)
            IconButton(
              tooltip: 'Product counts failed to load. Retry',
              onPressed: controller.refreshProductCounts,
              icon: Icon(
                PhosphorIconsRegular.arrowClockwise,
                size: 15,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeTab(BuildContext context, String mode, String label, int count) {
    final theme = Theme.of(context);
    final selected = controller.mode.value == mode;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? theme.dividerColor : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Content
  // --------------------------------------------------------------------

  Widget _content(
    BuildContext context,
    List<ProductRecord> products,
    String selectedMode,
  ) {
    if (controller.loadingFor(selectedMode).value &&
        controller.productsFor(selectedMode).isEmpty) {
      return const Center(child: AppLoader(label: 'Loading products...'));
    }
    if (controller.errorFor(selectedMode).value != null &&
        controller.productsFor(selectedMode).isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.errorFor(selectedMode).value!,
        onRetry: () => controller.reload(selectedMode: selectedMode),
      );
    }
    if (products.isEmpty) {
      return Column(
        children: [
          EmptyState(
            title: 'No products found',
            message: controller.search.value.isEmpty
                ? 'Products will appear here when added.'
                : 'Try a different product name or SKU.',
            actionLabel: initialMode == 'all' ? 'Add product' : null,
            onAction: initialMode == 'all'
                ? () => ProductEditorDrawer.show(null)
                : null,
          ),
          if (controller.canLoadMoreFor(selectedMode).value ||
              controller.loadMoreErrorFor(selectedMode).value != null)
            _footer(context, selectedMode),
        ],
      );
    }
    final showFooter =
        controller.canLoadMoreFor(selectedMode).value ||
        controller.loadMoreErrorFor(selectedMode).value != null;
    return Column(
      children: [
        _table(context, products),
        if (showFooter) _footer(context, selectedMode),
      ],
    );
  }

  Widget _footer(BuildContext context, String selectedMode) {
    final theme = Theme.of(context);
    final loadMoreError = controller.loadMoreErrorFor(selectedMode).value;
    final loadingMore = controller.loadingMoreFor(selectedMode).value;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loadMoreError != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  'Could not load more products',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          if (controller.canLoadMoreFor(selectedMode).value)
            TextButton.icon(
              onPressed: loadingMore
                  ? null
                  : () => controller.loadMore(selectedMode: selectedMode),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
              ),
              icon: loadingMore
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.arrowDown, size: 16),
              label: Text(
                loadingMore
                    ? 'Loading products...'
                    : loadMoreError == null
                    ? 'Load more products'
                    : 'Retry loading products',
              ),
            ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Table: plain Row-based layout. Every column has a fixed width and its
  // content is clipped, so nothing can ever paint over a neighbouring cell.
  // --------------------------------------------------------------------

  Widget _table(BuildContext context, List<ProductRecord> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = _tableMinWidth;
        final width = constraints.maxWidth < minWidth
            ? minWidth
            : constraints.maxWidth;
        final body = SizedBox(
          width: width,
          child: Column(
            children: [
              _header(context),
              Column(
                children: [
                  for (final product in products) _row(context, product),
                ],
              ),
            ],
          ),
        );
        if (constraints.maxWidth >= minWidth) return body;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: body,
        );
      },
    );
  }

  Widget _cell(
    double width,
    Widget child, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return SizedBox(
      width: width,
      child: ClipRect(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Align(alignment: alignment, child: child),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      fontSize: 11,
    );
    Widget h(
      String text,
      double width, {
      bool right = false,
      bool center = false,
    }) => _cell(
      width,
      Text(text, maxLines: 1, style: style),
      alignment: right
          ? Alignment.centerRight
          : (center ? Alignment.center : Alignment.centerLeft),
    );
    return Container(
      height: _kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: _kSidePad),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('Product', style: style),
            ),
          ),
          h('MRP', _wMrp, right: true),
          h('Home price', _wHome, right: true),
          h('Shop price', _wShop, right: true),
          h('Stock', _wStock, right: true),
          h('Bulk', _wBulk),
          h('Rating', _wRating),
          h('Featured', _wFeatured, center: true),
          h('Visible', _wVisible, center: true),
          const SizedBox(width: _wActions),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    return _HoverRow(
      builder: (hovering) => Container(
        padding: const EdgeInsets.symmetric(horizontal: _kSidePad, vertical: 6),
        decoration: BoxDecoration(
          color: hovering
              ? theme.colorScheme.primary.withValues(alpha: 0.045)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: theme.dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, right: 10),
                  child: _productCell(context, product),
                ),
              ),
            ),
            _cell(
              _wMrp,
              _mrpCell(context, product),
              alignment: Alignment.centerRight,
            ),
            _cell(
              _wHome,
              _priceCell(context, product.homePrice, emphasized: true),
              alignment: Alignment.centerRight,
            ),
            _cell(
              _wShop,
              _priceCell(context, product.shopPrice, emphasized: true),
              alignment: Alignment.centerRight,
            ),
            _cell(
              _wStock,
              _stockCell(context, product),
              alignment: Alignment.centerRight,
            ),
            _cell(_wBulk, _bulkCell(context, product)),
            _cell(_wRating, _ratingCell(context, product)),
            _cell(
              _wFeatured,
              Semantics(
                label: 'Featured ${product.name}',
                toggled: product.featured,
                child: AppToggle(
                  label: '',
                  value: product.featured,
                  onChanged: (value) => _confirmProductToggle(
                    context,
                    product,
                    value,
                    featured: true,
                  ),
                ),
              ),
              alignment: Alignment.center,
            ),
            _cell(
              _wVisible,
              Semantics(
                label: 'Visible ${product.name}',
                toggled: product.active,
                child: AppToggle(
                  label: '',
                  value: product.active,
                  onChanged: (value) => _confirmProductToggle(
                    context,
                    product,
                    value,
                    featured: false,
                  ),
                ),
              ),
              alignment: Alignment.center,
            ),
            SizedBox(
              width: _wActions,
              child: Align(
                alignment: Alignment.centerRight,
                child: _actionsCell(context, product),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View item profit',
          onPressed: product.id == null
              ? null
              : () => Get.toNamed('/item-profit', arguments: product.id),
          style: IconButton.styleFrom(
            minimumSize: const Size(34, 34),
            padding: EdgeInsets.zero,
            foregroundColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(PhosphorIconsRegular.chartLineUp, size: 16),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          onPressed: () => ProductEditorDrawer.show(product),
          icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 14),
          label: const Text('Edit'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Delete product',
          onPressed: () => _confirmDeleteProduct(context, product),
          style: IconButton.styleFrom(
            minimumSize: const Size(34, 34),
            padding: EdgeInsets.zero,
            foregroundColor: theme.colorScheme.error,
            backgroundColor: theme.colorScheme.error.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(PhosphorIconsRegular.trash, size: 16),
        ),
      ],
    );
  }

  Widget _productCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    final category = controller.categoryName(product.categoryId);
    final categoryText = [
      if (category.isNotEmpty)
        category == product.categoryId && product.category.isNotEmpty
            ? product.category
            : category,
      if (product.subcategory.isNotEmpty) product.subcategory,
    ].join('  ›  ');
    final hasOffer = controller.hasLiveOffer(product);
    return Row(
      children: [
        _productThumbnail(context, product),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (hasOffer) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Offer',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                categoryText.isEmpty ? 'Uncategorized' : categoryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mrpCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    if (product.mrp <= 0) {
      return Text(
        '—',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final discounted = product.mrp > product.homePrice;
    return Text(
      Money.rs(product.mrp),
      maxLines: 1,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        decoration: discounted ? TextDecoration.lineThrough : null,
        decorationColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.6,
        ),
      ),
    );
  }

  Widget _priceCell(
    BuildContext context,
    double price, {
    bool emphasized = false,
  }) {
    final theme = Theme.of(context);
    return Text(
      Money.rs(price),
      maxLines: 1,
      style: theme.textTheme.bodySmall?.copyWith(
        color: emphasized
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _stockCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    final out = product.stock <= 0;
    final low =
        !out &&
        product.reorderLevel > 0 &&
        product.stock <= product.reorderLevel;
    if (!out && !low) {
      return Text(
        '${product.stock}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
    }
    final bg = out
        ? theme.colorScheme.error.withValues(alpha: 0.1)
        : theme.colorScheme.tertiaryContainer;
    final fg = out
        ? theme.colorScheme.error
        : theme.colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        out ? 'Out' : '${product.stock} low',
        maxLines: 1,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _bulkCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    if (!product.bulkEnabled) {
      return Text(
        '—',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final tierCount = product.tiers.isNotEmpty
        ? product.tiers.length
        : product.bulkPricing.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tierCount > 0
            ? '$tierCount ${tierCount == 1 ? 'tier' : 'tiers'}'
            : 'Bulk',
        maxLines: 1,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _ratingCell(BuildContext context, ProductRecord product) {
    final theme = Theme.of(context);
    if (product.ratingCount == 0 && product.ratingAvg == 0) {
      return Text(
        '—',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIconsFill.star,
          size: 14,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: 4),
        Text(
          product.ratingAvg.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '(${product.ratingCount})',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _productThumbnail(BuildContext context, ProductRecord product) {
    final imageUrl = product.images.isNotEmpty
        ? product.images.first
        : product.imageUrl;
    final theme = Theme.of(context);
    final fallback = Icon(
      PhosphorIconsRegular.image,
      size: 18,
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: imageUrl == null || imageUrl.isEmpty
            ? Center(child: fallback)
            : Image.network(
                imageUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: fallback),
              ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Actions (unchanged behaviour)
  // --------------------------------------------------------------------

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    ProductRecord product,
  ) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Delete product?',
      message:
          'If this product has sales history, it will be hidden instead of deleted.',
      icon: PhosphorIconsRegular.trash,
      iconColor: Theme.of(context).colorScheme.error,
      positiveButtonText: 'Delete',
    );
    if (confirmed != true) return;
    try {
      final deleted = await controller.deleteOrHide(product);
      Get.snackbar(
        deleted ? 'Product deleted' : 'Product hidden',
        deleted
            ? product.name
            : 'Sales history exists, so the product was hidden.',
      );
    } catch (exception) {
      Get.snackbar('Could not delete product', exception.toString());
    }
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
}

/// Row wrapper that reports hover state for desktop/web.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.builder});

  final Widget Function(bool hovering) builder;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.builder(_hovering),
    );
  }
}
