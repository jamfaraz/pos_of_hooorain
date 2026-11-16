import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/controllers/fetch_product_controller.dart';
import 'package:hoorain_pos/widgets/backbutton.dart';

import '../../constants.dart';
import '../../controllers/product_controller.dart';
import '../../models/product_model.dart';
import '../../utils/toas_message.dart';
import '../../widgets/chip_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/round_button.dart';
import '../../widgets/loading_placeholder.dart';
import 'edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  final String category;

  const ProductListScreen({super.key, required this.category});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductController productController = Get.put(ProductController());
  final FetchProductController fetchProductController = Get.put(
    FetchProductController(),
  );

  List<Product> products = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    try {
      await fetchProductController.fetchSubcategoriesForCategory(
        widget.category,
      );
      _loadProducts();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load subcategories: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final selectedSubcat = fetchProductController.selectedSubcategory.value;
      final subcategory = selectedSubcat == 'All' ? null : selectedSubcat;

      // Use getAllProductsByCategory to get ALL products including hidden ones
      final snapshot = await fetchProductController
          .getAllProductsByCategory(widget.category, subcategory: subcategory)
          .first;

      setState(() {
        products = snapshot;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load products: $e';
        isLoading = false;
      });
    }
  }

  void _selectSubcategory(String subcategory) {
    fetchProductController.selectedSubcategory.value = subcategory;
    _loadProducts();
  }

  // Toggle product visibility
  Future<void> _toggleProductVisibility(Product product) async {
    try {
      final newHideStatus = !product.isHide;
      await fetchProductController.toggleProductVisibility(
        product.id!,
        newHideStatus,
      );

      // Update local product list
      setState(() {
        final index = products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          products[index] = product.copyWith(isHide: newHideStatus);
        }
      });

      // Show success message
      MessageToast.showToast(
        msg: newHideStatus
            ? 'Product hidden from customers'
            : 'Product made visible to customers',
      );
    } catch (e) {
      MessageToast.showToast(msg: 'Failed to update product visibility: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ScreenUtil based on your design size

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.category,
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            fontSize: 17.sp,
          ),
        ),
        centerTitle: true,
        elevation: 1,
        leading: BackNavigatingButton(color: kblack),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: _loadProducts,
          color: kGreenColor,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Obx(() {
                  if (fetchProductController.isLoadingSubcategories.value) {
                    return const AppLoader(label: 'Loading subcategories...');
                  }

                  if (fetchProductController.subcategories.isEmpty) {
                    return SizedBox(height: 8.h);
                  }

                  return Container(
                    height: 46.h,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: fetchProductController.subcategories.length,
                      itemBuilder: (context, index) {
                        final subcategory =
                            fetchProductController.subcategories[index];
                        final isSelected =
                            fetchProductController.selectedSubcategory.value ==
                            subcategory;

                        return ChipWidget(
                          subcategory: subcategory,
                          isSelected: isSelected,
                          onTap: () => _selectSubcategory(subcategory),
                        );
                      },
                    ),
                  );
                }),
              ),
              ..._buildBody(constraints.maxWidth),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(double screenWidth) {
    if (isLoading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: AppLoader(label: 'Loading products...')),
        ),
      ];
    }

    if (errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetryWidget(
            errorMessage: errorMessage!,
            onRetry: _loadProducts,
          ),
        ),
      ];
    }

    if (products.isEmpty) {
      final selectedSubcategory =
          fetchProductController.selectedSubcategory.value;
      final message = selectedSubcategory == 'All'
          ? 'There are no products in ${widget.category} yet.'
          : 'There are no products in $selectedSubcategory subcategory yet.';

      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetryWidget(
            mainMessage: 'No Products Found',
            errorMessage: message,
            onRetry: _loadProducts,
            icon: Icons.inventory_2,
            buttonText: 'Refresh',
          ),
        ),
      ];
    }

    int crossAxisCount;
    double childAspectRatio;
    if (screenWidth >= 1200) {
      crossAxisCount = 3;
      childAspectRatio = 2.8;
    } else if (screenWidth >= 800) {
      crossAxisCount = 2;
      childAspectRatio = 2.8;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 2.3;
    }

    const spacing = 12.0;
    return [
      SliverPadding(
        padding: const EdgeInsets.all(spacing),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final product = products[index];
            return _ProductCard(
              product: product,
              onEdit: () {
                Get.to(
                  () => EditProductScreen(
                    product: product,
                    onProductUpdated: _loadProducts,
                  ),
                  transition: Transition.cupertino,
                  duration: const Duration(milliseconds: 400),
                );
              },
              onToggleVisibility: () => _showToggleVisibilityDialog(product),
              onDelete: () => _showDeleteDialog(context, product.id!),
            );
          }, childCount: products.length),
        ),
      ),
    ];
  }

  void _showToggleVisibilityDialog(Product product) {
    final message = product.isHide
        ? 'Do you want to make this product visible to customers?'
        : 'Do you want to hide this product from customers?';

    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: product.isHide ? 'Make Product Visible' : 'Hide Product',
        message: message,
        icon: product.isHide ? Icons.visibility : Icons.visibility_off,
        iconColor: product.isHide ? kGreenColor : Colors.orange,
        negativeButtonText: 'Cancel',
        positiveButtonText: product.isHide ? 'Unhide' : 'Hide',
        onPositiveButtonPressed: () async {
          await _toggleProductVisibility(product);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Delete Product',
        message:
            'Do you want to delete this product? This action cannot be undone.',
        icon: Icons.delete,
        iconColor: Colors.red,
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Delete',
        onPositiveButtonPressed: () async {
          try {
            await fetchProductController.deleteProduct(productId);
            // Remove the deleted product from the list
            setState(() {
              products.removeWhere((product) => product.id == productId);
            });
            MessageToast.showToast(msg: 'Product deleted successfully');
          } catch (e) {
            MessageToast.showToast(msg: 'Failed to delete product: $e');
          }
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ------------------------------------------------------------------
// EXTRACTED PRODUCT CARD WIDGET FOR REUSABILITY IN GRID/LIST
// ------------------------------------------------------------------

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onToggleVisibility;
  final VoidCallback onDelete;

  const _ProductCard({
    Key? key,
    required this.product,
    required this.onEdit,
    required this.onToggleVisibility,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: product.isHide
            ? Colors.orange.withAlpha(19)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade300, width: 1.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with hidden indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: Container(
                    width: 80.w,
                    height: 80.h,
                    color: Colors.white,
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return LoadingPlaceholder.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade200,
                                child: Container(color: Colors.white),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade100,
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 24.sp,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 24.sp,
                            ),
                          ),
                  ),
                ),
                if (product.isHide)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(6.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 11.sp,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'HIDDEN',
                            style: GoogleFonts.inter(
                              fontSize: 8.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    product.name,
                    style: GoogleFonts.interTight(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  // Display subcategory if available
                  if (product.subcategory.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: Text(
                        product.subcategory,
                        style: GoogleFonts.interTight(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  Text(
                    'Rs.${product.price.toStringAsFixed(0)}',
                    style: GoogleFonts.interTight(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: kPrimaryColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Added: ${DateFormat('MMM dd, yyyy - hh:mm a').format(product.createdAt)}',
                    style: GoogleFonts.interTight(
                      fontSize: 12.sp,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Action Buttons
            Column(
              children: [
                ActionButton(
                  icon: product.isHide
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: product.isHide ? kGreenColor : Colors.orange,
                  onTap: onToggleVisibility,
                  tooltip: product.isHide ? 'Make Visible' : 'Hide Product',
                ),
                SizedBox(height: 6.h),
                ActionButton(
                  icon: Icons.edit,
                  color: kGreenColor,
                  onTap: onEdit,
                  tooltip: 'Edit Product',
                ),
                SizedBox(height: 6.h),
                ActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
