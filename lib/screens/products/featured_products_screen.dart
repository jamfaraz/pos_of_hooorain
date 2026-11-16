import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:intl/intl.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

import '../../constants.dart';
import '../../controllers/fetch_product_controller.dart';
import '../../models/product_model.dart';
import '../../widgets/backbutton.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/round_button.dart';
import '../../widgets/app_loader.dart';
import 'edit_product_screen.dart';

class FeaturedProductsScreen extends StatefulWidget {
  const FeaturedProductsScreen({super.key});

  @override
  State<FeaturedProductsScreen> createState() => _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState extends State<FeaturedProductsScreen>
    with SingleTickerProviderStateMixin {
  final FetchProductController fetchProductController =
      Get.find<FetchProductController>();

  bool isLoading = true;
  String? errorMessage;
  late AnimationController _animationController;

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _priceFilter = 'All';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadFeaturedProducts();

    // Listen to products changes
    ever(fetchProductController.products, (List<Product> products) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFeaturedProducts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await fetchProductController.loadFeaturedProducts();

      setState(() {
        isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load featured products: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _removeFromFeatured(Product product) async {
    try {
      await fetchProductController.toggleFeaturedStatus(product.id!, false);
      MessageToast.showToast(msg: 'Product removed from featured');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update product: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await fetchProductController.deleteProduct(productId);
      MessageToast.showToast(msg: 'Product deleted successfully');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete product: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    String productId,
    String productName,
  ) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Delete Product',
        message:
            'Are you sure you want to delete "$productName"? This action cannot be undone.',
        icon: Icons.delete_outline,
        iconColor: Colors.red,
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Delete',
        onPositiveButtonPressed: () async {
          await _deleteProduct(productId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showRemoveFeaturedDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: 'Remove from Featured',
        message:
            'Do you want to remove "${product.name}" from featured products?',
        icon: Icons.star_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        negativeButtonText: 'Cancel',
        positiveButtonText: 'Remove',
        onPositiveButtonPressed: () async {
          await _removeFromFeatured(product);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  List<Product> _getFilteredProducts() {
    List<Product> allProducts = fetchProductController.products
        .where((product) => product.isFeatured)
        .toList();

    if (_searchQuery.isEmpty && _priceFilter == 'All') {
      return allProducts;
    }

    return allProducts.where((product) {
      // Name search
      bool matchesSearch =
          _searchQuery.isEmpty ||
          product.name.toLowerCase().contains(_searchQuery.toLowerCase());

      // Price filter
      bool matchesPrice = true;
      if (_priceFilter == 'Under 500') {
        matchesPrice = product.price < 500;
      } else if (_priceFilter == '500 - 1000') {
        matchesPrice = product.price >= 500 && product.price <= 1000;
      } else if (_priceFilter == '1000 - 5000') {
        matchesPrice = product.price > 1000 && product.price <= 5000;
      } else if (_priceFilter == 'Above 5000') {
        matchesPrice = product.price > 5000;
      }

      return matchesSearch && matchesPrice;
    }).toList();
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _priceFilter = 'All';
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.black.withAlpha(19), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: const Color(0xFF64748B),
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search featured products...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14.sp,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: const Color(0xFF0F172A),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _isSearching = value.isNotEmpty || _priceFilter != 'All';
                });
              },
            ),
          ),
          if (_isSearching) ...[
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  [
                    'All',
                    'Under 500',
                    '500 - 1000',
                    '1000 - 5000',
                    'Above 5000',
                  ].map((priceRange) {
                    final isSelected = _priceFilter == priceRange;
                    return Container(
                      margin: EdgeInsets.only(right: 8.w),
                      child: FilterChip(
                        label: Text(
                          priceRange,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _priceFilter = selected ? priceRange : 'All';
                            _isSearching =
                                _searchQuery.isNotEmpty ||
                                _priceFilter != 'All';
                          });
                        },
                        backgroundColor: const Color(0xFFF8FAFC),
                        selectedColor: kGreenColor,
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: isSelected
                              ? kGreenColor
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context, designSize: const Size(360, 690));
    final filteredProducts = _getFilteredProducts();
    final featuredProductsCount = fetchProductController.products
        .where((product) => product.isFeatured)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Featured Products',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.black.withAlpha(12),
        leading: BackNavigatingButton(color: kblack),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: kGreenColor,
                size: 22.sp,
              ),
              onPressed: _loadFeaturedProducts,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeaturedProducts,
        color: kGreenColor,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildStatsHeader(
                featuredProductsCount,
                filteredProducts.length,
              ),
            ),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            _buildBody(filteredProducts),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(int totalFeatured, int filteredCount) {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF59E0B), const Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withAlpha(75),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(75),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.star_rounded, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSearching ? 'Search Results' : 'Featured Products',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(222),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _isSearching
                      ? '$filteredCount ${filteredCount == 1 ? 'Product' : 'Products'}'
                      : '$totalFeatured ${totalFeatured == 1 ? 'Product' : 'Products'}',
                  style: GoogleFonts.inter(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                if (_isSearching && totalFeatured > 0) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'of $totalFeatured total featured products',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Product> productsToDisplay) {
    if (isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: AppLoader(label: 'Loading featured products...')),
      );
    }

    if (errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: ErrorRetryWidget(
            errorMessage: errorMessage!,
            onRetry: _loadFeaturedProducts,
          ),
        ),
      );
    }

    if (productsToDisplay.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(_isSearching),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index.isOdd) return SizedBox(height: 9.h);
          final product = productsToDisplay[index ~/ 2];
          return _buildProductCard(product, index ~/ 2);
        }, childCount: productsToDisplay.length * 2 - 1),
      ),
    );
  }

  Widget _buildProductCard(Product product, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.black.withAlpha(19), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Get.to(
                  () => EditProductScreen(product: product),
                  transition: Transition.cupertino,
                  duration: const Duration(milliseconds: 400),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Hero(
                              tag: 'featured-product-${product.id}',
                              child: Container(
                                width: 90.w,
                                height: 90.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  color: const Color(0xFFF1F5F9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child:
                                      product.imageUrl != null &&
                                          product.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          product.imageUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (
                                                context,
                                                child,
                                                loadingProgress,
                                              ) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return LoadingPlaceholder.fromColors(
                                                  baseColor: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                  highlightColor: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  child: Container(
                                                    color: Colors.white,
                                                  ),
                                                );
                                              },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: const Color(
                                                      0xFF94A3B8,
                                                    ),
                                                    size: 32.sp,
                                                  ),
                                                );
                                              },
                                        )
                                      : Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: const Color(0xFF94A3B8),
                                            size: 32.sp,
                                          ),
                                        ),
                                ),
                              ),
                            ),
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
                                    colors: [
                                      Color(0xFF9333EA),
                                      Color(0xFF7C3AED),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF9333EA,
                                      ).withAlpha(100),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star_rounded,
                                      size: 11.sp,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 3.w),
                                    Text(
                                      'FEATURED',
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
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: GoogleFonts.interTight(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A).withAlpha(222),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                product.category,
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    'Rs.${product.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: kPrimaryColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (product.mrp > product.price) ...[
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Rs.${product.mrp.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        color: const Color(0xFFEF4444),
                                        decoration: TextDecoration.lineThrough,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 14.sp,
                                    color: const Color(0xFFFBBF24),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    product.rating.toStringAsFixed(1),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 11.sp,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(product.createdAt),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          children: [
                            ActionButton(
                              icon: Icons.star_outline_rounded,
                              color: const Color(0xFFF59E0B),
                              onTap: () =>
                                  _showRemoveFeaturedDialog(context, product),
                              tooltip: 'Remove from Featured',
                            ),
                            SizedBox(height: 6.h),
                            ActionButton(
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFEF4444),
                              onTap: () {
                                _showDeleteDialog(
                                  context,
                                  product.id!,
                                  product.name,
                                );
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isSearching) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSearching
                  ? 'No Featured Products Found'
                  : 'No Featured Products',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              isSearching
                  ? 'No featured products match your search criteria. Try adjusting your filters or search terms.'
                  : 'You haven\'t added any products to featured yet. Feature products to highlight them for customers.',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
