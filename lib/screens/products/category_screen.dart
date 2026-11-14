// lib/screens/category_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:hoorain_pos/constants.dart';
import 'package:hoorain_pos/widgets/backbutton.dart';
import '../../models/category_model.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/retry_widget.dart';
import 'product_list_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Responsive App Bar
          _buildAppBar(context),

          // Content - StreamBuilder for Category Grid
          _buildContent(context),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final bool isDesktop = _isDesktop(context);

    return SliverAppBar(
      expandedHeight: isDesktop ? 140.h : 120.h,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 4.0,
      shadowColor: Colors.black.withOpacity(0.1),
      leading: isDesktop
          ? null
          : BackNavigatingButton(color: const Color(0xFF1A1A1A)),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: EdgeInsets.only(
          left: isDesktop ? 40.w : 20.w,
          bottom: isDesktop ? 20.h : 16.h,
        ),
        title: Text(
          'Explore Categories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 22.sp : 18.sp,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(color: Colors.white),
        ),
      ),
    );
  }

  SliverPadding _buildContent(BuildContext context) {
    return SliverPadding(
      padding: _getContentPadding(context),
      sliver: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context);
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return _buildCategoryGrid(context, snapshot.data!.docs);
        },
      ),
    );
  }

  SliverFillRemaining _buildErrorState(AsyncSnapshot<QuerySnapshot> snapshot) {
    return SliverFillRemaining(
      child: ErrorRetryWidget(
        errorMessage: 'Oops! Failed to fetch categories: ${snapshot.error}',
        onRetry: () => FirebaseFirestore.instance
            .collection('categories')
            .orderBy('name')
            .snapshots(),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const SliverFillRemaining(
      child: AppLoader(label: 'Loading categories...'),
    );
  }

  SliverFillRemaining _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 80.sp,
              color: Colors.grey[300],
            ),
            SizedBox(height: 16.h),
            Text(
              'No categories found.',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Start by adding new categories to your store.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverGrid _buildCategoryGrid(
    BuildContext context,
    List<QueryDocumentSnapshot> docs,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getCrossAxisCount(context),
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: _getCardAspectRatio(context),
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final doc = docs[index];
        final category = Category.fromMap(
          doc.data() as Map<String, dynamic>,
          id: doc.id,
        );
        return _CategoryCard(
          category: category,
          isDesktop: _isDesktop(context),
        );
      }, childCount: docs.length),
    );
  }

  // Responsive helper methods
  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  bool _isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  EdgeInsets _getContentPadding(BuildContext context) {
    final bool isLargeDesktop = _isLargeDesktop(context);
    final bool isDesktop = _isDesktop(context);

    if (isLargeDesktop) {
      return EdgeInsets.symmetric(horizontal: 120.w, vertical: 24.h);
    } else if (isDesktop) {
      return EdgeInsets.symmetric(horizontal: 60.w, vertical: 24.h);
    } else {
      return EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h);
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 1200) return 4; // Large desktop
    if (screenWidth >= 800) return 3; // Desktop/tablet
    if (screenWidth >= 600) return 2; // Small tablet
    return 2; // Mobile
  }

  double _getCardAspectRatio(BuildContext context) {
    final bool isDesktop = _isDesktop(context);
    return isDesktop ? 0.75 : 0.85; // Wider cards on desktop
  }
}

class _CategoryCard extends StatefulWidget {
  final Category category;
  final bool isDesktop;

  const _CategoryCard({required this.category, required this.isDesktop});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToProductList() {
    Future.delayed(const Duration(milliseconds: 100), () {
      Get.to(
        () => ProductListScreen(category: widget.category.name),
        transition: Transition.cupertino,
        duration: const Duration(milliseconds: 400),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const int alpha6 = 255 * 6 ~/ 100;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        _navigateToProductList();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(alpha6),
                blurRadius: 16.r,
                offset: Offset(0, 8.h),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(255 * 3 ~/ 100),
                blurRadius: 4.r,
                offset: Offset(0, 2.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Stack(
              children: [
                // Background Image
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: widget.category.imageUrl ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const AppLoader(label: 'Loading image...'),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: widget.isDesktop ? 64.sp : 48.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),

                // Sophisticated Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.fromARGB(0, 0, 0, 0),
                          Color.fromARGB(44, 0, 0, 0),
                          Color.fromARGB(144, 0, 0, 0),
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),

                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isDesktop ? 16.w : 9.w,
                      vertical: widget.isDesktop ? 16.h : 12.h,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Category Name
                        Expanded(
                          child: Text(
                            widget.category.name,
                            style: GoogleFonts.interTight(
                              fontWeight: FontWeight.w700,
                              fontSize: widget.isDesktop ? 18.sp : 16.sp,
                              color: Colors.white,
                              height: 1.1,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withAlpha(
                                    255 * 60 ~/ 100,
                                  ),
                                  offset: const Offset(1, 1),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            maxLines: widget.isDesktop ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Arrow Icon
                        Container(
                          width: widget.isDesktop ? 28.r : 24.r,
                          height: widget.isDesktop ? 28.r : 24.r,
                          decoration: BoxDecoration(
                            color: kGreenColor,
                            borderRadius: BorderRadius.circular(333.r),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: widget.isDesktop ? 16.sp : 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
