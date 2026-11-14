import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/category_management_controller.dart';
import '../../models/category_model.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Categories',
          subtitle: 'Organize products with categories and sub-categories.',
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
        if (controller.categories.isEmpty)
          const Expanded(
            child: EmptyState(
              title: 'No categories yet',
              message: 'Create a category to start organizing products.',
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 330,
                    mainAxisExtent: 270,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: controller.categories.length,
                  itemBuilder: (context, index) {
                    final category = controller.categories[index];
                    final count = controller.products
                        .where(
                          (product) =>
                              product.categoryId == category.id ||
                              product.categoryId == category.name,
                        )
                        .length;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          controller.selected.value = category;
                          controller.selectedSubcategory.value = '';
                        },
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
                                  Text(
                                    '$count products',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: category.subcategories
                                        .take(4)
                                        .map(
                                          (value) => Chip(
                                            label: Text(value),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        )
                                        .toList(),
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
          ),
      ],
    );
  });

  Widget _categoryProducts(BuildContext context, CategoryRecord category) {
    final products = controller.selectedProducts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: category.name,
          subtitle: '${products.length} products in this category.',
          actions: [
            AppButton(
              label: 'Back to categories',
              style: AppButtonStyle.ghost,
              onPressed: () => controller.selected.value = null,
            ),
            AppButton(
              label: 'Add product here',
              icon: const Icon(PhosphorIconsRegular.plus),
              onPressed: () =>
                  ProductEditorDrawer.show(null, categoryId: category.id),
            ),
          ],
        ),
        if (category.subcategories.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: controller.selectedSubcategory.value.isEmpty,
                onSelected: (_) => controller.selectedSubcategory.value = '',
              ),
              ...category.subcategories.map(
                (subcategory) => ChoiceChip(
                  label: Text(subcategory),
                  selected: controller.selectedSubcategory.value == subcategory,
                  onSelected: (_) =>
                      controller.selectedSubcategory.value = subcategory,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Expanded(
          child: products.isEmpty
              ? EmptyState(
                  title: 'No products in this category',
                  message:
                      'Add a product here or select a different sub-category.',
                  actionLabel: 'Add product here',
                  onAction: () =>
                      ProductEditorDrawer.show(null, categoryId: category.id),
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 235,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: product.images.isEmpty
                                  ? _categoryPlaceholder(context)
                                  : Image.network(
                                      product.images.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _categoryPlaceholder(context),
                                    ),
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
                                  '${product.subcategory} · ${product.stock} in stock',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  Money.rs(product.homePrice),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
        ),
      ],
    );
  }

  Widget _categoryPlaceholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
    child: const Center(
      child: Icon(PhosphorIconsRegular.squaresFour, size: 40),
    ),
  );

  Future<void> _editCategory(
    BuildContext context, [
    CategoryRecord? category,
  ]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: category?.name ?? '');
    final subcategories = (category?.subcategories ?? const <String>[])
        .map((value) => TextEditingController(text: value))
        .toList();
    if (subcategories.isEmpty) subcategories.add(TextEditingController());
    var images = category?.imageUrl == null
        ? <String>[]
        : [category!.imageUrl!];
    final drawer = SideDrawer(
      title: category == null ? 'Add category' : 'Edit category',
      width: 640,
      body: StatefulBuilder(
        builder: (context, setDrawerState) => Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PrimaryTextField(
                controller: name,
                headerText: 'Category name',
                hintText: 'Enter category name',
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 18),
              const Text('Category image'),
              const SizedBox(height: 8),
              MultiImageUploader(
                maxImages: 1,
                value: images,
                onChanged: (value) => setDrawerState(() => images = value),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sub-categories',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add sub-category',
                    onPressed: () => setDrawerState(
                      () => subcategories.add(TextEditingController()),
                    ),
                    icon: const Icon(PhosphorIconsRegular.plus),
                  ),
                ],
              ),
              for (var index = 0; index < subcategories.length; index++)
                Row(
                  children: [
                    Expanded(
                      child: PrimaryTextField(
                        controller: subcategories[index],
                        headerText: 'Sub-category ${index + 1}',
                        hintText: 'Enter sub-category',
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove sub-category',
                      onPressed: () => setDrawerState(() {
                        subcategories[index].dispose();
                        subcategories.removeAt(index);
                      }),
                      icon: const Icon(PhosphorIconsRegular.x),
                    ),
                  ],
                ),
            ],
          ),
        ),
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
              if (!formKey.currentState!.validate()) return;
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
}
