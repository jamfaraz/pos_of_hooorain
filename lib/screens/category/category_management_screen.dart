import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/category_management_controller.dart';
import '../../models/category_model.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/multi_image_uploader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/side_drawer.dart';
import '../products/product_editor_drawer.dart';

class CategoryManagementScreen extends GetView<CategoryManagementController> {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final selected = controller.selected.value;
    if (controller.loading.value) {
      return const AppLoader(label: 'Loading categories...');
    }
    if (controller.error.value != null && controller.categories.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }
    if (selected != null) return _categoryProducts(context, selected);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Categories',
            subtitle: 'Browse your catalog and manage products by category.',
            actions: [
              AppButton(
                label: 'Add category',
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => _editCategory(context),
              ),
            ],
          ),
          if (controller.error.value != null)
            ErrorRetryWidget(
              errorMessage: controller.error.value!,
              onRetry: controller.reload,
            ),
          if (controller.categoryCountsError.value != null)
            ErrorRetryWidget(
              errorMessage: controller.categoryCountsError.value!,
              onRetry: controller.retryCategoryProductCounts,
            ),
          if (controller.categories.isEmpty)
            const EmptyState(
              title: 'No categories yet',
              message: 'Create a category to start organizing products.',
            )
          else
            Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 330,
                    mainAxisExtent: 240,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: controller.categories.length,
                  itemBuilder: (context, index) {
                    final category = controller.categories[index];
                    final categoryKey = category.id ?? category.name;
                    final count = controller.categoryProductCounts[categoryKey];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => controller.selectCategory(category),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: SizedBox(
                                width: double.infinity,
                                child: category.imageUrl?.isNotEmpty == true
                                    ? Image.network(
                                        category.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _categoryPlaceholder(context),
                                      )
                                    : _categoryPlaceholder(context),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          category.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit category',
                                        onPressed: () =>
                                            _editCategory(context, category),
                                        icon: const Icon(
                                          PhosphorIconsRegular.pencilSimple,
                                        ),
                                      ),
                                      ConfirmTapButton(
                                        label: 'Delete',
                                        confirmLabel: 'Delete',
                                        confirmTitle: 'Delete category?',
                                        confirmMessage:
                                            'This category can only be deleted if it has no products or banners.',
                                        onConfirmed: () async {
                                          try {
                                            await controller.delete(category);
                                          } catch (exception) {
                                            Get.snackbar(
                                              'Cannot delete category',
                                              exception.toString(),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsRegular.package,
                                          size: 14,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          count == null
                                              ? (controller
                                                        .loadingProductCountIds
                                                        .contains(categoryKey)
                                                    ? 'Counting products…'
                                                    : 'Count unavailable')
                                              : '$count ${count == 1 ? 'product' : 'products'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (controller.canLoadMore.value)
                  Center(
                    child: TextButton(
                      onPressed: controller.loadingMore.value
                          ? null
                          : controller.loadMore,
                      child: Text(
                        controller.loadingMore.value
                            ? 'Loading…'
                            : 'Load more categories',
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  });

  Widget _categoryProducts(BuildContext context, CategoryRecord category) {
    final products = controller.selectedProducts;
    final selectedSubcategory = controller.selectedSubcategory.value;
    final productCount = products.length;
    final productLabel = productCount == 1 ? 'product' : 'products';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: category.name,
            subtitle: controller.loadingCategoryProducts.value
                ? 'Loading products…'
                : selectedSubcategory.isEmpty
                ? '$productCount $productLabel in this category.'
                : '$productCount $productLabel in $selectedSubcategory.',
            actions: [
              AppButton(
                label: 'Back to categories',
                style: AppButtonStyle.ghost,
                onPressed: controller.clearSelectedCategory,
              ),
              AppButton(
                label: 'Add product here',
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => _openProductEditor(category),
              ),
            ],
          ),
          if (category.subcategories.isNotEmpty)
            _subcategoryFilters(context, category),
          const SizedBox(height: 16),
          if (controller.loadingCategoryProducts.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 44),
              child: AppLoader(label: 'Loading category products...'),
            )
          else if (controller.categoryProductsError.value != null)
            ErrorRetryWidget(
              errorMessage: controller.categoryProductsError.value!,
              onRetry: controller.reloadSelectedProducts,
            )
          else if (controller.selectedProducts.isEmpty)
            EmptyState(
              title: 'No products in this category',
              message: 'Add a product here or select a different sub-category.',
              actionLabel: 'Add product here',
              onAction: () => _openProductEditor(category),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 235,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: controller.selectedProducts.length,
              itemBuilder: (context, index) {
                final product = controller.selectedProducts[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            product.images.isEmpty
                                ? _categoryPlaceholder(context)
                                : Image.network(
                                    product.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _categoryPlaceholder(context),
                                  ),
                            if (product.stock <= 0)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.error
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIconsRegular.warningCircle,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'OUT OF STOCK',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onErrorContainer,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.35,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton.filledTonal(
                                tooltip: 'Edit product',
                                onPressed: () => _openProductEditor(
                                  category,
                                  product: product,
                                ),
                                icon: const Icon(
                                  PhosphorIconsRegular.pencilSimple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                if (product.subcategory.isNotEmpty)
                                  product.subcategory,
                                '${product.stock} in stock',
                              ].join(' · '),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              Money.rs(product.homePrice),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _subcategoryFilters(BuildContext context, CategoryRecord category) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = controller.selectedSubcategory.value;
    final allProducts = controller.categoryProducts;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.funnel,
                size: 17,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filter by sub-category',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: () => controller.selectedSubcategory.value = '',
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _subcategoryChoice(
                  context,
                  label: 'All',
                  count: allProducts.length,
                  selected: selected.isEmpty,
                  onSelected: () => controller.selectedSubcategory.value = '',
                ),
                for (final subcategory in category.subcategories) ...[
                  const SizedBox(width: 8),
                  _subcategoryChoice(
                    context,
                    label: subcategory,
                    count: allProducts
                        .where((product) => product.subcategory == subcategory)
                        .length,
                    selected: selected == subcategory,
                    onSelected: () =>
                        controller.selectedSubcategory.value = subcategory,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subcategoryChoice(
    BuildContext context, {
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      avatar: selected
          ? Icon(PhosphorIconsRegular.check, size: 14, color: colors.onPrimary)
          : null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? colors.onPrimary.withValues(alpha: 0.16)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      labelStyle: TextStyle(
        color: selected ? colors.onPrimary : colors.onSurface,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      side: BorderSide(
        color: selected ? colors.primary : colors.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  Widget _categoryPlaceholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
    child: const Center(
      child: Icon(PhosphorIconsRegular.squaresFour, size: 40),
    ),
  );

  Future<void> _openProductEditor(
    CategoryRecord category, {
    ProductRecord? product,
  }) async {
    await ProductEditorDrawer.show(product, categoryId: category.id);
    await controller.reloadSelectedProducts();
  }

  Future<void> _editCategory(
    BuildContext context, [
    CategoryRecord? category,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: category?.name ?? '');
    final subcategories = (category?.subcategories ?? const <String>[])
        .map((value) => TextEditingController(text: value))
        .toList();
    var images = category?.imageUrl == null
        ? <String>[]
        : [category!.imageUrl!];
    var saving = false;
    final drawer = SideDrawer(
      title: category == null ? 'Add category' : 'Edit category',
      subtitle: category == null
          ? 'Create a clear home for related products.'
          : 'Update the category details and product filters.',
      width: 680,
      body: StatefulBuilder(
        builder: (context, setDrawerState) {
          final theme = Theme.of(context);
          return Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _editorSection(
                  context,
                  icon: PhosphorIconsRegular.tag,
                  title: 'Category details',
                  subtitle: 'Give this category a recognizable name.',
                  child: PrimaryTextField(
                    controller: name,
                    headerText: 'Category name',
                    hintText: 'e.g. Spices & Condiments',
                    textCapitalization: TextCapitalization.words,
                    required: true,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                _editorSection(
                  context,
                  icon: PhosphorIconsRegular.image,
                  title: 'Cover image',
                  subtitle: 'Choose one image to identify the category.',
                  child: MultiImageUploader(
                    maxImages: 1,
                    value: images,
                    onChanged: (value) => setDrawerState(() => images = value),
                  ),
                ),
                const SizedBox(height: 16),
                _editorSection(
                  context,
                  icon: PhosphorIconsRegular.squaresFour,
                  title: 'Sub-categories',
                  subtitle:
                      'Optional filters customers can use to narrow products.',
                  trailing: IconButton.filledTonal(
                    tooltip: 'Add sub-category',
                    onPressed: () => setDrawerState(
                      () => subcategories.add(TextEditingController()),
                    ),
                    icon: const Icon(PhosphorIconsRegular.plus),
                  ),
                  child: Column(
                    children: [
                      if (subcategories.isEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No sub-categories added yet.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (var index = 0; index < subcategories.length; index++)
                        Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: subcategories[index],
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: 'Sub-category name',
                                    isDense: true,
                                    filled: true,
                                    fillColor: theme.colorScheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Remove sub-category',
                                onPressed: () => setDrawerState(() {
                                  subcategories[index].dispose();
                                  subcategories.removeAt(index);
                                }),
                                icon: Icon(
                                  PhosphorIconsRegular.trash,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Cancel',
            style: AppButtonStyle.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Save category',
            onPressed: () async {
              if (saving || !formKey.currentState!.validate()) return;
              saving = true;
              try {
                await controller.save(
                  CategoryRecord(
                    id: category?.id,
                    name: name.text.trim(),
                    imageUrl: images.isEmpty ? null : images.first,
                    subcategories: subcategories
                        .map((value) => value.text.trim())
                        .where((value) => value.isNotEmpty)
                        .toSet()
                        .toList(),
                    sortOrder:
                        category?.sortOrder ?? controller.categories.length,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              } catch (exception) {
                Get.snackbar('Could not save category', exception.toString());
              } finally {
                saving = false;
              }
            },
          ),
        ],
      ),
    );
    await SideDrawer.show<void>(drawer);
    name.dispose();
    for (final item in subcategories) {
      item.dispose();
    }
  }

  Widget _editorSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
