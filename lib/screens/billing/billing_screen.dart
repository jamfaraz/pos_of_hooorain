import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/billing_controller.dart';
import '../../models/order_record.dart';
import '../../models/product_record.dart';
import '../../utils/bill_print_service.dart';
import '../../utils/money.dart';
import '../../utils/pricing.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';

class BillingScreen extends GetView<BillingController> {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontSizeFactor: 0.94),
      primaryTextTheme: theme.primaryTextTheme.apply(fontSizeFactor: 0.94),
    );
    return Theme(
      data: compactTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final compact = constraints.maxWidth < 500;
          return Obx(
            () => CustomScrollView(
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  floating: false,
                  pinned: false,
                  toolbarHeight: compact ? 76 : 84,
                  titleSpacing: 0,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Billing',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (!compact)
                        Text(
                          'Counter sales. Stock updates when a bill is saved.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: compact
                          ? IconButton(
                              tooltip: 'Bill history',
                              onPressed: () => Get.toNamed('/bill-history'),
                              icon: const Icon(PhosphorIconsRegular.receipt),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => Get.toNamed('/bill-history'),
                              icon: const Icon(
                                PhosphorIconsRegular.receipt,
                                size: 18,
                              ),
                              label: const Text('Bill history'),
                            ),
                    ),
                  ],
                ),
                if (controller.loading.value && controller.products.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppLoader(label: 'Loading products...'),
                    ),
                  )
                else if (controller.error.value != null &&
                    controller.products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorRetryWidget(
                      errorMessage: controller.error.value!,
                      onRetry: controller.reload,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16),
                    sliver: SliverToBoxAdapter(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 13,
                                  child: _ProductPicker(controller: controller),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 7,
                                  child: _CurrentBillPanel(
                                    controller: controller,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _ProductPicker(controller: controller),
                                const SizedBox(height: 14),
                                _CurrentBillPanel(controller: controller),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BillingNewBillAction extends GetView<BillingController> {
  const BillingNewBillAction({super.key});

  Future<void> _startNewBill(BuildContext context) async {
    if (controller.saving.value) return;
    if (controller.cart.isNotEmpty) {
      final confirmed = await CommonDialog.confirm(
        context: context,
        title: 'Start a new bill?',
        message: 'The current unsaved bill will be cleared.',
        icon: PhosphorIconsRegular.filePlus,
        iconColor: Theme.of(context).colorScheme.error,
        positiveButtonText: 'Clear and start',
      );
      if (confirmed != true || controller.saving.value) return;
    }
    controller.startNewBill();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Obx(() {
      final enabled = !controller.saving.value;
      if (compact) {
        return IconButton.filled(
          tooltip: 'New bill',
          onPressed: enabled ? () => _startNewBill(context) : null,
          icon: const Icon(PhosphorIconsRegular.plus),
        );
      }
      return FilledButton.icon(
        onPressed: enabled ? () => _startNewBill(context) : null,
        icon: const Icon(PhosphorIconsRegular.plus, size: 18),
        label: const Text('New bill'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(132, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    });
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: TextField(
            onChanged: (value) => controller.searchQuery.value = value,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
              hintText: 'Search by name or SKU, or scan a barcode',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: Obx(() {
            final categories = controller.categories;
            final selectedCategory = controller.selectedCategory.value;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) =>
                      controller.selectedCategory.value = category,
                  showCheckmark: false,
                  backgroundColor: theme.colorScheme.surface,
                  selectedColor: theme.colorScheme.primaryContainer,
                  side: BorderSide(
                    color: selected
                        ? theme.colorScheme.primaryContainer
                        : theme.dividerColor,
                  ),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            );
          }),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final products = controller.filteredProducts;
          final shopCustomer = controller.customerType.value == 'shop';
          final availableOffers = controller.offers.toList();
          final cartLinesByProduct = {
            for (final line in controller.cart.toList()) line.productId: line,
          };
          final isSaving = controller.saving.value;
          if (products.isEmpty) {
            final audienceProducts = controller.productsForCustomerType;
            final noStockProducts =
                audienceProducts.isNotEmpty &&
                audienceProducts.every((product) => !product.inStock);
            final noAudienceProducts =
                controller.products.isNotEmpty && audienceProducts.isEmpty;
            return Column(
              children: [
                EmptyState(
                  title: controller.products.isEmpty
                      ? 'No products available'
                      : noAudienceProducts
                      ? 'No products for ${shopCustomer ? 'shop owners' : 'home users'}'
                      : noStockProducts
                      ? 'No in-stock products'
                      : 'No products match',
                  message: controller.products.isEmpty
                      ? 'Active products will appear here.'
                      : noAudienceProducts
                      ? 'Enable this customer panel in a product’s availability settings.'
                      : noStockProducts
                      ? 'Products will appear here when stock is added.'
                      : 'Try a different product name, SKU, or category.',
                  icon: PhosphorIconsRegular.package,
                ),
                _LoadMoreProducts(controller: controller),
              ],
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 680
                  ? 4
                  : constraints.maxWidth >= 450
                  ? 3
                  : constraints.maxWidth >= 320
                  ? 2
                  : 1;
              return Column(
                children: [
                  GridView.builder(
                    key: ValueKey(
                      '${controller.searchQuery.value}|'
                      '${controller.selectedCategory.value}',
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.94,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final cartLine = cartLinesByProduct[product.id];
                      final quantityInBill = cartLine?.qty ?? 0;
                      return _ProductCard(
                        product: product,
                        price: unitPrice(
                          product: product,
                          shopCustomer: shopCustomer,
                          quantity: quantityInBill > 0 ? quantityInBill : 1,
                          offers: availableOffers,
                        ),
                        quantityInBill: quantityInBill,
                        onTap: quantityInBill < product.stock && !isSaving
                            ? () => controller.addProduct(product)
                            : null,
                        onDecrease: cartLine == null || isSaving
                            ? null
                            : () => controller.changeQuantity(
                                cartLine,
                                quantityInBill - 1,
                              ),
                      );
                    },
                  ),
                  _LoadMoreProducts(controller: controller),
                ],
              );
            },
          );
        }),
      ],
    );
  }
}

class _LoadMoreProducts extends StatelessWidget {
  const _LoadMoreProducts({required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final isLoading = controller.loadingMoreProducts.value;
    final message = controller.productPageError.value;
    if (!controller.hasMoreProducts.value && !isLoading && message == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      child: Column(
        children: [
          if (message != null)
            Text(
              'Could not load more products: $message',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isLoading || controller.saving.value
                ? null
                : controller.loadMoreProducts,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    message == null
                        ? PhosphorIconsRegular.arrowDown
                        : PhosphorIconsRegular.arrowClockwise,
                  ),
            label: Text(
              isLoading
                  ? 'Loading products...'
                  : message == null
                  ? 'Load more products'
                  : 'Retry loading products',
            ),
          ),
        ],
      ),
    );
  });
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.price,
    required this.quantityInBill,
    required this.onTap,
    required this.onDecrease,
  });

  final ProductRecord product;
  final double price;
  final int quantityInBill;
  final VoidCallback? onTap;
  final VoidCallback? onDecrease;

  int? get _bulkQuantity {
    final quantities = product.tiers
        .map((tier) => tier['qty'])
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value > 0)
        .toList();
    if (quantities.isEmpty) {
      quantities.addAll(
        product.bulkPricing.keys
            .map((value) => int.tryParse(value) ?? 0)
            .where((value) => value > 0),
      );
    }
    if (quantities.isEmpty) return null;
    quantities.sort();
    return quantities.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl =
        product.images.where((image) => image.trim().isNotEmpty).firstOrNull ??
        product.imageUrl;
    final bulkQuantity = _bulkQuantity;
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: InkWell(
              onTap: onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl?.isNotEmpty == true
                      ? Image.network(
                          imageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes == null
                                      ? null
                                      : progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => _imagePlaceholder(context),
                        )
                      : _imagePlaceholder(context),
                  if (bulkQuantity != null)
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'Bulk $bulkQuantity+',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (quantityInBill > 0)
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '$quantityInBill IN BILL',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _stockBadge(
                      context,
                      product.stock <= 0
                          ? 'OUT OF STOCK'
                          : '${product.stock} in stock',
                      product.stock <= 0
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSurfaceVariant,
                      isOutOfStock: product.stock <= 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 9, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Money.rs(price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (quantityInBill > 0)
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Remove one',
                                onPressed: onDecrease,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 32,
                                ),
                                style: IconButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide.none,
                                  shape: const CircleBorder(),
                                ),
                                icon: const Icon(
                                  PhosphorIconsRegular.minus,
                                  size: 14,
                                ),
                              ),
                              Text(
                                '$quantityInBill',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add one',
                                onPressed: onTap,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 28,
                                  height: 32,
                                ),
                                style: IconButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  backgroundColor: Colors.transparent,
                                  side: BorderSide.none,
                                  shape: const CircleBorder(),
                                ),
                                icon: const Icon(
                                  PhosphorIconsRegular.plus,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 32,
                          child: FilledButton.icon(
                            onPressed: onTap,
                            icon: const Icon(
                              PhosphorIconsRegular.plus,
                              size: 15,
                            ),
                            label: const Text('Add'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              textStyle: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        PhosphorIconsRegular.package,
        size: 36,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _stockBadge(
    BuildContext context,
    String label,
    Color color, {
    bool isOutOfStock = false,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: isOutOfStock
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CurrentBillPanel extends StatelessWidget {
  const _CurrentBillPanel({required this.controller});

  final BillingController controller;

  Future<void> _clearBill(BuildContext context) async {
    if (controller.cart.isEmpty || controller.saving.value) return;
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Clear this bill?',
      message: 'All items and discounts in the current bill will be removed.',
      icon: PhosphorIconsRegular.trash,
      iconColor: Theme.of(context).colorScheme.error,
      positiveButtonText: 'Clear bill',
    );
    if (confirmed == true && !controller.saving.value) {
      controller.startNewBill();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current bill',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Obx(() {
                        final count = controller.cart.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count ${count == 1 ? 'ITEM' : 'ITEMS'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Obx(
                  () => IconButton(
                    tooltip: 'Clear bill',
                    onPressed: controller.saving.value
                        ? null
                        : () => _clearBill(context),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.65),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(
              () => CommonDropdown<String>(
                label: 'Customer',
                bottomSpacing: 0,
                value: controller.selectedCustomerId.value ?? '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Walk-in customer'),
                  ),
                  ...controller.customers.map(
                    (customer) => DropdownMenuItem(
                      value: customer.id,
                      child: Text(
                        customer.isVerified
                            ? '${customer.fullName} · verified'
                            : customer.fullName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: controller.saving.value
                    ? null
                    : (value) {
                        controller.selectedCustomerId.value =
                            value == null || value.isEmpty ? null : value;
                      },
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'home', label: Text('Home user')),
                    ButtonSegment(value: 'shop', label: Text('Shop owner')),
                  ],
                  selected: {controller.customerType.value},
                  onSelectionChanged: controller.saving.value
                      ? null
                      : (values) => controller.setCustomerType(values.first),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Obx(() {
              final editingEnabled = !controller.saving.value;
              if (controller.cart.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.handTap,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your bill is empty',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Add a product to get started.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final line in controller.cart)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _BillLine(
                          line: line,
                          onDecrease: editingEnabled
                              ? () => controller.changeQuantity(
                                  line,
                                  line.qty - 1,
                                )
                              : null,
                          onIncrease: editingEnabled
                              ? () => controller.changeQuantity(
                                  line,
                                  line.qty + 1,
                                )
                              : null,
                          onRemove: editingEnabled
                              ? () => controller.changeQuantity(line, 0)
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            }),
            Obx(() {
              final message = controller.error.value;
              if (message == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            _BillSummary(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({
    required this.line,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final OrderLineRecord line;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.rs(line.qty * line.unitPrice),
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: 'Remove item',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                icon: Icon(
                  PhosphorIconsRegular.x,
                  size: 17,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Money.rs(line.unitPrice)} each',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _QuantityButton(
                icon: PhosphorIconsRegular.minus,
                onPressed: onDecrease,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${line.qty}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _QuantityButton(
                icon: PhosphorIconsRegular.plus,
                onPressed: onIncrease,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    padding: EdgeInsets.zero,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    icon: Icon(icon, size: 16),
  );
}

class _BillSummary extends StatelessWidget {
  const _BillSummary({required this.controller});

  final BillingController controller;

  Future<void> _showPreview(BuildContext context) {
    controller.ensureDraftBillNumber();
    return showDialog<void>(
      context: context,
      builder: (_) => _BillPreviewDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final canPreview = controller.cart.isNotEmpty && !controller.saving.value;

      return Column(
        children: [
          Divider(height: 1, color: theme.dividerColor),
          Column(
            children: [
              _SummaryRow(
                label: 'Subtotal',
                value: Money.rs(controller.subtotal),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: TextField(
                                  controller: controller.discountController,
                                  enabled: !controller.saving.value,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  onChanged: (_) => controller.cart.refresh(),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: '0',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ToggleButtons(
                              isSelected: [
                                !controller.isDiscountPercent.value,
                                controller.isDiscountPercent.value,
                              ],
                              onPressed: controller.saving.value
                                  ? null
                                  : (index) {
                                      controller.isDiscountPercent.value =
                                          index == 1;
                                      controller.cart.refresh();
                                    },
                              borderRadius: BorderRadius.circular(8),
                              constraints: const BoxConstraints(
                                minHeight: 32,
                                minWidth: 29,
                              ),
                              children: const [Text('Rs'), Text('%')],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 32,
                          child: TextField(
                            controller: controller.deliveryController,
                            enabled: !controller.saving.value,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => controller.cart.refresh(),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: '0',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canPreview ? () => _showPreview(context) : null,
              icon: const Icon(PhosphorIconsRegular.receipt, size: 17),
              label: Text('Preview · ${Money.rs(controller.total)}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _BillPreviewDialog extends StatefulWidget {
  const _BillPreviewDialog({required this.controller});

  final BillingController controller;

  @override
  State<_BillPreviewDialog> createState() => _BillPreviewDialogState();
}

class _BillPreviewDialogState extends State<_BillPreviewDialog> {
  bool _printing = false;

  BillingController get controller => widget.controller;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      final opened = await printReceiptHtml(_receiptHtml());
      if (!mounted) return;
      Get.snackbar(
        opened ? 'Print preview opened' : 'Printing unavailable',
        opened
            ? 'Choose your printer in the browser print window.'
            : 'Browser printing is not available on this platform.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (exception) {
      if (!mounted) return;
      Get.snackbar(
        'Could not open print preview',
        exception.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _save() async {
    try {
      final id = await controller.checkout();
      if (!mounted || id == null) return;
      Navigator.of(context).pop();
      Get.snackbar(
        'Bill saved',
        'Bill #$id was saved successfully.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (exception) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save bill',
        exception.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String _receiptHtml() {
    final billNumber = controller.ensureDraftBillNumber();
    final customer =
        controller.selectedCustomer?.fullName ?? 'Walk-in customer';
    final phone = controller.selectedCustomer?.phoneNumber ?? '';
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final itemRows = controller.cart.map((line) {
      final productName = _escapeHtml(line.name);
      return '<tr><td>$productName</td><td class="qty">${line.qty}</td>'
          '<td class="amount">${_escapeHtml(Money.rs(line.unitPrice))}</td>'
          '<td class="amount">${_escapeHtml(Money.rs(line.qty * line.unitPrice))}'
          '</td></tr>';
    }).join();

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Hoorain bill preview</title>
  <style>
    @page { size: 80mm auto; margin: 4mm; }
    * { box-sizing: border-box; }
    body { font: 13px Arial, sans-serif; color: #17231e; margin: 0 auto; max-width: 72mm; }
    h1 { font: bold 19px Georgia, serif; margin: 0; letter-spacing: 1px; }
    .center { text-align: center; }
    .muted { color: #64736c; font-size: 11px; }
    .rule { border-top: 1px dashed #89958f; margin: 10px 0; }
    table { width: 100%; border-collapse: collapse; }
    th { text-align: left; font-size: 10px; padding: 4px 0; border-bottom: 1px solid #89958f; }
    td { padding: 5px 0; vertical-align: top; }
    .qty { text-align: center; padding: 0 4px; }
    .amount { text-align: right; white-space: nowrap; padding-left: 8px; }
    .total { font-size: 16px; font-weight: bold; }
    @media screen {
      body { margin: 24px auto; padding: 18px; border: 1px solid #d5ded9; }
    }
  </style>
</head>
<body>
  <header class="center">
    <h1>HOORAIN</h1>
    <div class="muted">COUNTER BILL</div>
  </header>
  <div class="rule"></div>
  <div>Bill No: ${_escapeHtml(billNumber)}</div>
  <div>Date: ${_escapeHtml(date)}</div>
  <div>Customer: ${_escapeHtml(customer)}</div>
  ${phone.isEmpty ? '' : '<div>Phone: ${_escapeHtml(phone)}</div>'}
  <div class="rule"></div>
  <table>
    <thead><tr><th>ITEM</th><th class="qty">QTY</th><th class="amount">PRICE</th><th class="amount">TOTAL</th></tr></thead>
    <tbody>$itemRows</tbody>
  </table>
  <div class="rule"></div>
  <table>
    <tr><td>Subtotal</td><td class="amount">${_escapeHtml(Money.rs(controller.subtotal))}</td></tr>
    <tr><td>Service charges</td><td class="amount">Rs 0</td></tr>
    <tr><td>Discount</td><td class="amount">− ${_escapeHtml(Money.rs(controller.discount))}</td></tr>
    <tr><td>Delivery</td><td class="amount">${_escapeHtml(Money.rs(controller.delivery))}</td></tr>
    <tr class="total"><td>Total</td><td class="amount">${_escapeHtml(Money.rs(controller.total))}</td></tr>
  </table>
  <div class="rule"></div>
  <div>Payment: ${_escapeHtml(controller.selectedPaymentMethod.value)}</div>
  <p class="center muted">Thank you for shopping with us.</p>
</body>
</html>
''';
  }

  String _escapeHtml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    return Obx(() {
      final cashPayment = controller.selectedPaymentMethod.value == 'cash';
      final canSave =
          controller.cart.isNotEmpty &&
          !controller.saving.value &&
          (!cashPayment || controller.cashReceived >= controller.total);
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: size.height * 0.9,
          ),
          child: SizedBox(
            width: size.width < 640 ? size.width - 96 : 560,
            height: size.height * 0.84,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill preview',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Review the receipt, then print and save it.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close preview',
                        onPressed: controller.saving.value
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(PhosphorIconsRegular.x),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: _ReceiptPreview(controller: controller),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment method',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SegmentedButton<String>(
                                    showSelectedIcon: false,
                                    segments: const [
                                      ButtonSegment(
                                        value: 'cash',
                                        label: Text('Cash'),
                                      ),
                                      ButtonSegment(
                                        value: 'easypaisa',
                                        label: Text('Easypaisa'),
                                      ),
                                      ButtonSegment(
                                        value: 'bank transfer',
                                        label: Text('Bank'),
                                      ),
                                    ],
                                    selected: {
                                      controller.selectedPaymentMethod.value,
                                    },
                                    onSelectionChanged: controller.saving.value
                                        ? null
                                        : (values) =>
                                              controller
                                                      .selectedPaymentMethod
                                                      .value =
                                                  values.first,
                                  ),
                                  if (cashPayment) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: controller
                                                .cashReceivedController,
                                            enabled: !controller.saving.value,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (_) =>
                                                controller.cart.refresh(),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              labelText: 'Cash received',
                                              hintText: '0',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Change ${controller.cashReceived >= controller.total ? Money.rs(controller.changeDue) : '—'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    if (controller.cashReceived <
                                        controller.total)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          'Enter the amount received to enable saving.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.error,
                                              ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: controller.saving.value
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Back to bill'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _printing || controller.saving.value
                            ? null
                            : _print,
                        icon: _printing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                PhosphorIconsRegular.printer,
                                size: 17,
                              ),
                        label: Text(_printing ? 'Opening...' : 'Print'),
                      ),
                      FilledButton.icon(
                        onPressed: canSave ? _save : null,
                        icon: controller.saving.value
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(PhosphorIconsRegular.check, size: 17),
                        label: Text(
                          controller.saving.value ? 'Saving...' : 'Save bill',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer =
        controller.selectedCustomer?.fullName ?? 'Walk-in customer';
    final phone = controller.selectedCustomer?.phoneNumber ?? '';
    final date = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'HOORAIN',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          Text(
            'COUNTER BILL',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _ReceiptValueRow(
            label: 'Bill No.',
            value: controller.ensureDraftBillNumber(),
            numeric: true,
          ),
          _ReceiptValueRow(label: 'Date', value: date),
          _ReceiptValueRow(label: 'Customer', value: customer),
          if (phone.isNotEmpty) _ReceiptValueRow(label: 'Phone', value: phone),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ITEM',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ReceiptColumnHeader(
                label: 'QTY',
                width: 38,
                textAlign: TextAlign.center,
              ),
              _ReceiptColumnHeader(label: 'PRICE', width: 72),
              _ReceiptColumnHeader(label: 'TOTAL', width: 78),
            ],
          ),
          const Divider(height: 1),
          ...controller.cart.map(
            (line) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text('${line.qty}', textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 72,
                    child: Text(
                      Money.rs(line.unitPrice),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.robotoMono(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      Money.rs(line.qty * line.unitPrice),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.robotoMono(
                        color: theme.colorScheme.onSurface,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _ReceiptValueRow(
            label: 'Subtotal',
            value: Money.rs(controller.subtotal),
            numeric: true,
          ),
          const _ReceiptValueRow(
            label: 'Service charges',
            value: 'Rs 0',
            numeric: true,
          ),
          _ReceiptValueRow(
            label: 'Discount',
            value: Money.rs(controller.discount),
            numeric: true,
          ),
          _ReceiptValueRow(
            label: 'Delivery',
            value: Money.rs(controller.delivery),
            numeric: true,
          ),
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 6),
          _ReceiptValueRow(
            label: 'Total',
            value: Money.rs(controller.total),
            emphasized: true,
            numeric: true,
          ),
          _ReceiptValueRow(
            label: 'Payment',
            value: controller.selectedPaymentMethod.value,
          ),
          const SizedBox(height: 12),
          Text(
            'Thank you for shopping with us.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptColumnHeader extends StatelessWidget {
  const _ReceiptColumnHeader({
    required this.label,
    required this.width,
    this.textAlign = TextAlign.right,
  });

  final String label;
  final double width;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ReceiptValueRow extends StatelessWidget {
  const _ReceiptValueRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.numeric = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = GoogleFonts.dmSans(
      color: theme.colorScheme.onSurface,
      fontSize: emphasized ? 14 : 12,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
    );
    final valueStyle = emphasized
        ? GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          )
        : numeric
        ? GoogleFonts.robotoMono(
            color: theme.colorScheme.onSurface,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          )
        : GoogleFonts.dmSans(
            color: theme.colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
