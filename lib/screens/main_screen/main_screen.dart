// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:hoorain_pos/controllers/fetch_product_controller.dart';
// import 'package:hoorain_pos/screens/banners/banners_screen.dart';
// import 'package:hoorain_pos/screens/category/add_category_screen.dart';
// import 'package:hoorain_pos/screens/notification/notifications.dart';
// import 'package:hoorain_pos/screens/notification/send_notification_screen.dart';
// import 'package:hoorain_pos/screens/orders/order_screen.dart';
// import 'package:hoorain_pos/screens/products/featured_products_screen.dart';
// import 'package:hoorain_pos/screens/products/hidden_products_screen.dart';
// import 'package:hoorain_pos/screens/sales/sales_screen.dart';
// import '../../constants.dart';
// import '../../controllers/dashboard_count_controller.dart';
// import '../../controllers/profile_controller.dart';
// import '../../controllers/user_controller.dart';
// import '../../widgets/common_dialog.dart';
// import '../add_product/add_product_screen.dart';
// import '../products/category_screen.dart';
// import '../users/users_screen.dart';

// class MainScreen extends StatefulWidget {
//   const MainScreen({this.embedded = false, super.key});

//   final bool embedded;

//   @override
//   State<MainScreen> createState() => _MainScreenState();
// }

// class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
//   final ProfileController profileController = Get.put(ProfileController());
//   final UsersController usersController = Get.put(UsersController());
//   final FetchProductController fetchProductController = Get.put(
//     FetchProductController(),
//   );
//   final DashboardCountsController countsController =
//     Get.put(DashboardCountsController());

//   late AnimationController _fadeController;

//   @override
//   void initState() {
//     super.initState();
//     _fadeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 600),
//     );
//     _fadeController.forward();
//     fetchProductController.fetchTotalProducts();
//   }

//   @override
//   void dispose() {
//     _fadeController.dispose();
//     super.dispose();
//   }

//   // Get time-based greeting
//   String _getGreeting() {
//     final hour = DateTime.now().hour;
//     if (hour >= 5 && hour < 12) {
//       return 'Good Morning';
//     } else if (hour >= 12 && hour < 17) {
//       return 'Good Afternoon';
//     } else if (hour >= 17 && hour < 21) {
//       return 'Good Evening';
//     } else {
//       return 'Good Night';
//     }
//   }

//   // Get greeting icon
//   IconData _getGreetingIcon() {
//     final hour = DateTime.now().hour;
//     if (hour >= 5 && hour < 12) {
//       return Icons.wb_sunny_rounded;
//     } else if (hour >= 12 && hour < 17) {
//       return Icons.wb_sunny_outlined;
//     } else if (hour >= 17 && hour < 21) {
//       return Icons.nights_stay_outlined;
//     } else {
//       return Icons.bedtime_rounded;
//     }
//   }

//   // Get gradient colors based on time
//   List<Color> _getTimeBasedGradient() {
//     final hour = DateTime.now().hour;
//     if (hour >= 5 && hour < 12) {
//       return [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)]; // Morning
//     } else if (hour >= 12 && hour < 17) {
//       return [const Color(0xFFDDEAFB), const Color(0xFFBFDBFE)]; // Afternoon
//     } else if (hour >= 17 && hour < 21) {
//       return [const Color(0xFFE9D5FF), const Color(0xFFDDD6FE)]; // Evening
//     } else {
//       return [const Color(0xFF1E293B), const Color(0xFF334155)]; // Night
//     }
//   }

//   Widget _buildDashboardContent() {
//     return SingleChildScrollView(
//       physics: const BouncingScrollPhysics(),
//       padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Greeting Banner
//           _buildGreetingBanner(),
//           SizedBox(height: 24.h),

//           // Analytics Cards
//           _buildAnalyticsSection(),
//           SizedBox(height: 28.h),

//           // Quick Actions
//           _buildSectionHeader('Quick Actions'),
//           SizedBox(height: 14.h),
//           _buildQuickActionsGrid(),
//           SizedBox(height: 28.h),

//           // Products Management
//           _buildSectionHeader('Product Management'),
//           SizedBox(height: 14.h),
//           _buildProductsSection(),
//           SizedBox(height: 28.h),

//           // Orders Management
//           _buildSectionHeader('Order Management'),
//           SizedBox(height: 14.h),
//           _buildOrdersSection(),
//           SizedBox(height: 28.h),

//           // Additional Tools
//           _buildSectionHeader('Additional Tools'),
//           SizedBox(height: 14.h),
//           _buildAdditionalTools(),
//           SizedBox(height: 20.h),
//         ],
//       ),
//     );
//   }

//   Widget _buildGreetingBanner() {
//     final hour = DateTime.now().hour;
//     final isNight = hour >= 21 || hour < 5;
    
//     return Container(
//       margin: EdgeInsets.only(top: 20.h),
//       padding: EdgeInsets.all(24.w),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: _getTimeBasedGradient(),
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(20.r),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withAlpha(20),
//             blurRadius: 20,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: EdgeInsets.all(12.w),
//             decoration: BoxDecoration(
//               color: isNight ? Colors.white.withAlpha(51) : Colors.white.withAlpha(128),
//               borderRadius: BorderRadius.circular(16.r),
//             ),
//             child: Icon(
//               _getGreetingIcon(),
//               color: isNight ? Colors.white : const Color(0xFF1A1D26),
//               size: 30.sp,
//             ),
//           ),
//           SizedBox(width: 14.w),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getGreeting(),
//                   style: GoogleFonts.inter(
//                     fontSize: 18.sp,
//                     fontWeight: FontWeight.w700,
//                     color: isNight ? Colors.white : const Color(0xFF1A1D26),
//                     letterSpacing: -0.3,
//                   ),
//                 ),
//                 SizedBox(height: 4.h),
//                 Text(
//                   'Welcome back to your dashboard',
//                   style: GoogleFonts.inter(
//                     fontSize: 12.sp,
//                     fontWeight: FontWeight.w500,
//                     color: isNight ? Colors.white.withAlpha(230) : const Color(0xFF6B7280),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () => _onWillPop(),
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF8F9FB),
//         appBar: widget.embedded ? null : _buildProfessionalAppBar(context),
//         body: _buildDashboardContent(),
//       ),
//     );
//   }

//   PreferredSizeWidget _buildProfessionalAppBar(BuildContext context) {
//     return AppBar(
//       titleSpacing: 0,
//       elevation: 0,
//       backgroundColor: Colors.white,
//       surfaceTintColor: Colors.white,
//       shadowColor: Colors.black.withAlpha(13),
//       automaticallyImplyLeading: false,
//       toolbarHeight: 70.h,
//       title: Padding(
//         padding: EdgeInsets.only(left: 24.w),
//         child: Row(
//           children: [
//             Container(
//               padding: EdgeInsets.all(10.w),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12.r),
//               ),
//               child: Icon(
//                 Icons.dashboard_rounded,
//                 color: Colors.white,
//                 size: 24.sp,
//               ),
//             ),
//             SizedBox(width: 12.w),
//             Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Admin Panel',
//                   style: GoogleFonts.inter(
//                     color: const Color(0xFF1A1D26),
//                     fontSize: 18.sp,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: -0.3,
//                   ),
//                 ),
//                 Text(
//                   'Store Management',
//                   style: GoogleFonts.inter(
//                     color: const Color(0xFF9CA3AF),
//                     fontSize: 11.sp,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         Container(
//           margin: EdgeInsets.only(right: 16.w),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF9FAFB),
//             borderRadius: BorderRadius.circular(12.r),
//             border: Border.all(
//               color: const Color(0xFFE5E7EB),
//               width: 1,
//             ),
//           ),
//           child: IconButton(
//             onPressed: () async {
//               showLogoutDialog(context, profileController);
//             },
//             icon: Icon(
//               Icons.logout_rounded,
//               color: const Color(0xFF6B7280),
//               size: 20.sp,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSectionHeader(String title) {
//     return Row(
//       children: [
//         Container(
//           width: 3.w,
//           height: 18.h,
//           decoration: BoxDecoration(
//             gradient: const LinearGradient(
//               colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//             ),
//             borderRadius: BorderRadius.circular(2.r),
//           ),
//         ),
//         SizedBox(width: 10.w),
//         Text(
//           title,
//           style: GoogleFonts.inter(
//             fontSize: 15.sp,
//             fontWeight: FontWeight.w700,
//             color: const Color(0xFF1A1D26),
//             letterSpacing: -0.2,
//           ),
//         ),
//       ],
//     );
//   }

// Widget _buildAnalyticsSection() {
//   return Row(
//     children: [
//       Expanded(
//         child: Obx(
//           () => _buildAnalyticsCard(
//             title: 'Total Customers',
//             value: countsController.isLoadingCustomers.value
//                 ? '...'
//                 : countsController.customersCount.value.toString(),
//             icon: Icons.people_outline_rounded,
//             color: const Color(0xFF3B82F6),
//             bgColor: const Color(0xFFEFF6FF),
//             onTap: () => Get.to(
//               () => UsersScreen(),
//               transition: Transition.cupertino,
//               duration: const Duration(milliseconds: 300),
//             ),
//           ),
//         ),
//       ),
//       SizedBox(width: 14.w),
//       Expanded(
//         child: Obx(
//           () => _buildAnalyticsCard(
//             title: 'Total Products',
//             value: countsController.isLoadingProducts.value
//                 ? '...'
//                 : countsController.productsCount.value.toString(),
//             icon: Icons.inventory_2_outlined,
//             color: const Color(0xFF10B981),
//             bgColor: const Color(0xFFECFDF5),
//             onTap: () => Get.to(
//               () => CategoryScreen(),
//               transition: Transition.cupertino,
//               duration: const Duration(milliseconds: 300),
//             ),
//           ),
//         ),
//       ),
//     ],
//   );
// }
//   Widget _buildAnalyticsCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//     required Color bgColor,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 14.w,vertical: 12.h),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.white, bgColor.withAlpha(30)],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//           borderRadius: BorderRadius.circular(16.r),
//           border: Border.all(
//             color: color.withAlpha(40),
//             width: 1.5,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: color.withAlpha(25),
//               blurRadius: 15,
//               offset: const Offset(0, 6),
//               spreadRadius: 0,
//             ),
//             BoxShadow(
//               color: Colors.black.withAlpha(8),
//               blurRadius: 10,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Container(
//               padding: EdgeInsets.all(8.w),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [color, color.withAlpha(200)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(14.r),
//                 boxShadow: [
//                   BoxShadow(
//                     color: color.withAlpha(60),
//                     blurRadius: 8,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Icon(icon, color: Colors.white, size: 23.sp),
//             ),
//             SizedBox(height: 9.h),
//             Text(
//               value,
//               style: GoogleFonts.inter(
//                 fontSize: 19.sp,
//                 fontWeight: FontWeight.w700,
//                 color: const Color(0xFF1A1D26),
//                 height: 1.1,
//                 letterSpacing: -0.5,
//               ),
//             ),
//             SizedBox(height: 5.h),
//             Text(
//               title,
//               style: GoogleFonts.inter(
//                 fontSize: 12.sp,
//                 fontWeight: FontWeight.w600,
//                 color: const Color(0xFF6B7280),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildQuickActionsGrid() {
//     return Row(
//       children: [
//         Expanded(
//           child: _buildActionButton(
//             icon: Icons.add_circle_outline_rounded,
//             label: 'Add Product',
//             color: const Color(0xFF8B5CF6),
//             bgColor: const Color(0xFFF5F3FF),
//             onTap: () => Get.to(
//               () => AddProductScreen(),
//               transition: Transition.cupertino,
//               duration: const Duration(milliseconds: 300),
//             ),
//           ),
//         ),
//         SizedBox(width: 14.w),
//         Expanded(
//           child: _buildActionButton(
//             icon: Icons.category_outlined,
//             label: 'Add Category',
//             color: const Color(0xFFEC4899),
//             bgColor: const Color(0xFFFDF2F8),
//             onTap: () => Get.to(
//               () => AddCategoryScreen(),
//               transition: Transition.cupertino,
//               duration: const Duration(milliseconds: 300),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildActionButton({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required Color bgColor,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(vertical: 16.h),
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Colors.white, bgColor.withAlpha(50)],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//           borderRadius: BorderRadius.circular(18.r),
//           border: Border.all(
//             color: color.withAlpha(50),
//             width: 1.5,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: color.withAlpha(20),
//               blurRadius: 12,
//               offset: const Offset(0, 6),
//             ),
//             BoxShadow(
//               color: Colors.black.withAlpha(8),
//               blurRadius: 10,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.all(9.w),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [color, color.withAlpha(200)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(14.r),
//                 boxShadow: [
//                   BoxShadow(
//                     color: color.withAlpha(60),
//                     blurRadius: 8,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Icon(icon, color: Colors.white, size: 24.sp),
//             ),
//             SizedBox(height: 11.h),
//             Text(
//               label,
//               style: GoogleFonts.inter(
//                 fontSize: 13.sp,
//                 fontWeight: FontWeight.w700,
//                 color: const Color(0xFF1A1D26),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildProductsSection() {
//     return Column(
//       children: [
//         _buildMenuItem(
//           icon: Icons.grid_view_rounded,
//           title: 'All Products',
//           subtitle: 'View and manage all products',
//           color: const Color(0xFF3B82F6),
//           bgColor: const Color(0xFFEFF6FF),
//           onTap: () => Get.to(
//             () => CategoryScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//         SizedBox(height: 10.h),
//         _buildMenuItem(
//           icon: Icons.visibility_off_outlined,
//           title: 'Hidden Products',
//           subtitle: 'Manage hidden inventory',
//           color: const Color(0xFFF59E0B),
//           bgColor: const Color(0xFFFEF3C7),
//           onTap: () => Get.to(
//             () => HiddenProductsScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//         SizedBox(height: 10.h),
//         _buildMenuItem(
//           icon: Icons.star_outline_rounded,
//           title: 'Featured Products',
//           subtitle: 'Manage featured items',
//           color: const Color(0xFFFBBF24),
//           bgColor: const Color(0xFFFEF9C3),
//           onTap: () => Get.to(
//             () => FeaturedProductsScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildOrdersSection() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18.r),
//         border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withAlpha(12),
//             blurRadius: 15,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           _buildOrderItem(
//             'Pending',
//             const Color(0xFFF59E0B),
//             const Color(0xFFFEF3C7),
//             Icons.schedule_rounded,
//           ),
//           const Divider(height: 1, color: Color(0xFFE5E7EB)),
//           _buildOrderItem(
//             'Accepted',
//             const Color(0xFF3B82F6),
//             const Color(0xFFEFF6FF),
//             Icons.check_circle_outline_rounded,
//           ),
//           const Divider(height: 1, color: Color(0xFFE5E7EB)),
//           _buildOrderItem(
//             'Cancelled',
//             const Color(0xFFEF4444),
//             const Color(0xFFFEE2E2),
//             Icons.cancel_outlined,
//           ),
//           const Divider(height: 1, color: Color(0xFFE5E7EB)),
//           _buildOrderItem(
//             'Delivered',
//             const Color(0xFF10B981),
//             const Color(0xFFECFDF5),
//             Icons.verified_outlined,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildOrderItem(
//     String status,
//     Color color,
//     Color bgColor,
//     IconData icon,
//   ) {
//     return ListTile(
//       contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
//       leading: Container(
//         padding: EdgeInsets.all(8.w),
//         decoration: BoxDecoration(
//           color: bgColor,
//           borderRadius: BorderRadius.circular(12.r),
//         ),
//         child: Icon(icon, color: color, size: 22.sp),
//       ),
//       title: Text(
//         '$status Orders',
//         style: GoogleFonts.inter(
//           fontSize: 13.sp,
//           fontWeight: FontWeight.w500,
//           color: const Color(0xFF1A1D26),
//         ),
//       ),
//       trailing: Icon(
//         Icons.arrow_forward_ios_rounded,
//         size: 16.sp,
//         color: const Color(0xFF9CA3AF),
//       ),
//       onTap: () => Get.to(
//         () => OrdersScreen(orderStatus: status),
//         transition: Transition.cupertino,
//         duration: const Duration(milliseconds: 300),
//       ),
//     );
//   }

//   Widget _buildAdditionalTools() {
//     return Column(
//       children: [
//         _buildMenuItem(
//           icon: Icons.photo_library_outlined,
//           title: 'Banners',
//           subtitle: 'Manage promotional banners',
//           color: const Color(0xFF8B5CF6),
//           bgColor: const Color(0xFFF5F3FF),
//           onTap: () => Get.to(
//             () => BannersScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//         SizedBox(height: 10.h),
//         _buildMenuItem(
//           icon: Icons.notifications_outlined,
//           title: 'Notifications',
//           subtitle: 'View all notifications',
//           color: const Color(0xFF06B6D4),
//           bgColor: const Color(0xFFECFEFF),
//           onTap: () => Get.to(
//             () => NotificationScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//         SizedBox(height: 10.h),
//         _buildMenuItem(
//           icon: Icons.send_outlined,
//           title: 'Send Notifications',
//           subtitle: 'Push updates to customers',
//           color: const Color(0xFF6366F1),
//           bgColor: const Color(0xFFEEF2FF),
//           onTap: () => Get.to(
//             () => SendNotificationScreen(),
//             transition: Transition.cupertino,
//             duration: const Duration(milliseconds: 300),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildMenuItem({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required Color bgColor,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.all(18.w),
//         decoration: BoxDecoration(
         
//           borderRadius: BorderRadius.circular(18.r),
//           border: Border.all(
//             color: kblack.withAlpha(16),
//             width: 1,
//           ),
        
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: EdgeInsets.all(8.w),
//               decoration: BoxDecoration(
//                 color: bgColor,
//                 borderRadius: BorderRadius.circular(12.r),
//               ),
//               child: Icon(icon, color: color, size: 22.sp),
//             ),
//             SizedBox(width: 14.w),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     title,
//                     style: GoogleFonts.inter(
//                       fontSize: 13.4.sp,
//                       fontWeight: FontWeight.w600,
//                       color: const Color(0xFF1A1D26),
//                     ),
//                   ),
//                   SizedBox(height: 2.h),
//                   Text(
//                     subtitle,
//                     style: GoogleFonts.inter(
//                       fontSize: 11.sp,
//                       fontWeight: FontWeight.w400,
//                       color: const Color(0xFF6B7280),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Icon(
//               Icons.arrow_forward_ios_rounded,
//               size: 16.sp,
//               color: const Color(0xFF9CA3AF),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<bool> _onWillPop() async {
//     return (await showDialog(
//           context: context,
//           builder: (context) => CommonDialog(
//             title: "Exit",
//             message: "Do you really want to exit?",
//             icon: Icons.exit_to_app,
//             iconColor: Colors.deepPurple.shade600,
//             negativeButtonText: "Cancel",
//             positiveButtonText: "Exit",
//             onPositiveButtonPressed: () {
//               Navigator.of(context).pop(true);
//             },
//           ),
//         )) ??
//         false;
//   }
// }

// void showLogoutDialog(
//     BuildContext context,
//     ProfileController profileController,
// ) {
//   showDialog(
//     context: context,
//     builder: (context) => CommonDialog(
//       title: 'Logout',
//       message: 'Do you want to logout your account?',
//       icon: Icons.logout,
//       iconColor: kPrimaryColor,
//       negativeButtonText: 'NO',
//       positiveButtonText: 'YES',
//       onPositiveButtonPressed: () async {
//         Navigator.of(context).pop();
//         await profileController.logOut();
//       },
//     ),
//   );
// }