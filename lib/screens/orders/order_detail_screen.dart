import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:hoorain_pos/screens/main_screen/main_screen.dart';

import '../../constants.dart';
import '../../controllers/common_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/order_actions_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../utils/toas_message.dart';
import '../../widgets/backbutton.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/full_image.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../users/user_detail_screen.dart';
import 'bill_viewer_screen.dart';

/// Ordered lifecycle used to drive the status stepper and to figure out
/// which statuses an order is allowed to move to next.
/// UPDATED: Removed 'Shipped' from the flow
const List<String> _kStatusFlow = ['Pending', 'Accepted', 'Delivered'];

/// Which statuses an order can move to from its current status.
/// UPDATED: Removed 'Shipped' options
const Map<String, List<String>> _kNextStatusOptions = {
  'Pending': ['Accepted', 'Cancelled'],
  'Accepted': ['Delivered', 'Cancelled'],
  'Delivered': [],
  'Cancelled': [],
};

const Map<String, String> _kStatusDialogMessage = {
  'Accepted': 'Accept this order and move it into fulfillment?',
  'Delivered': 'Confirm this order has been delivered to the customer?',
};

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // ✅ Initialize controllers
    OrderController orderController = Get.put(OrderController());
    UsersController usersController = Get.put(UsersController());
    final expandedNotifier = ValueNotifier<bool>(false);

    // ✅ Fetch user data when screen loads using UsersController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      usersController.fetchUserById(order.userId);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: BackNavigatingButton(color: kblack),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order Details',
              style: GoogleFonts.interTight(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            if (order.orderId != null)
              Text(
                '#${order.orderId}',
                style: GoogleFonts.interTight(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderStatusBanner(),
            if (order.status.toLowerCase() != 'cancelled') ...[
              SizedBox(height: 16.h),
              _buildStatusStepper(),
            ],
            SizedBox(height: 20.h),
            _buildDeliveryInfoCard(context),
            const SizedBox(height: 14),
            _buildRiderAssignment(context),
            SizedBox(height: 14.h),
            _buildOrderItemsSection(expandedNotifier),
            SizedBox(height: 14.h),
            _buildPriceBreakdownCard(),
            if (order.billImageUrl != null &&
                order.billImageUrl!.isNotEmpty) ...[
              SizedBox(height: 14.h),
              _buildBillImageCard(),
            ],
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(orderController, context),
    );
  }

  Widget _buildOrderStatusBanner() {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: statusColor.withAlpha(60), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(22),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: GoogleFonts.interTight(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  _getStatusMessage(order.status),
                  style: GoogleFonts.interTight(
                    fontSize: 12.5.sp,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A simple horizontal progress stepper: Pending -> Accepted -> Delivered
  /// UPDATED: Removed 'Shipped' step
  Widget _buildStatusStepper() {
    final currentIndex = _kStatusFlow.indexOf(order.status);
    // If the current status isn't part of the main flow (e.g. unknown), skip.
    if (currentIndex == -1) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_kStatusFlow.length, (index) {
          final isCompleted = index < currentIndex;
          final isActive = index == currentIndex;
          final isDone = isCompleted || isActive;
          final color = isDone ? kGreenColor : Colors.grey.shade300;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        color: isDone ? color : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                      child: isCompleted
                          ? Icon(Icons.check, size: 13.w, color: Colors.white)
                          : isActive
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      _kStatusFlow[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.interTight(
                        fontSize: 9.5.sp,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isDone
                            ? Colors.grey.shade800
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                if (index != _kStatusFlow.length - 1)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 18.h),
                      child: Container(
                        height: 2,
                        color: isCompleted ? kGreenColor : Colors.grey.shade200,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBillImageCard() {
    final billUrl = order.billImageUrl!;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Bill Image',
            icon: Icons.receipt_outlined,
          ),
          SizedBox(height: 16.h),
          InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () => Get.to(
              () =>
                  BillViewScreen(billImageUrl: billUrl, orderId: order.orderId),
            ),
            child: Container(
              width: double.infinity,
              height: 160.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      billUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return LoadingPlaceholder.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 32.w,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    // "Tap to view" overlay
                    Positioned(
                      right: 8.w,
                      bottom: 8.h,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(150),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in,
                              size: 14.w,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Tap to view',
                              style: GoogleFonts.interTight(
                                fontSize: 10.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard(BuildContext context) {
    // ✅ Get the UsersController instance
    final UsersController usersController = Get.put(UsersController());

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Delivery Information',
            icon: Icons.local_shipping_outlined,
          ),
          SizedBox(height: 16.h),
          InkWell(
            borderRadius: BorderRadius.circular(10.r),
            onTap: () => CommonController.openMapsByCoordinates(
              order.location.latitude,
              order.location.longitude,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20.w,
                    color: kPrimaryColor,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Address',
                          style: GoogleFonts.interTight(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          order.deliveryAddress,
                          style: GoogleFonts.interTight(
                            fontSize: 12.5.sp,
                            color: kPrimaryColor,
                            height: 1.5,
                            decoration: TextDecoration.underline,
                            decorationColor: kPrimaryColor,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 14.w,
                              color: kPrimaryColor,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Open in Maps',
                              style: GoogleFonts.interTight(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18.w,
                    color: kPrimaryColor,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 16.h),
          // Order Date + Total Items
          _buildInfoRow(
            label: 'Order Date',
            value: _formatDateTime(order.orderDate),
          ),
          SizedBox(height: 18.h),

          // ✅ Customer info with profile image using UsersController
          Obx(() {
            // Get user from UsersController
            final user = usersController.selectedUser.value;
            final isLoading = usersController.isUserLoading.value;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () {
                  // Navigate to user detail screen
                  Get.to(() => UserDetailScreen(userId: order.userId));
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withAlpha(14),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: kPrimaryColor.withAlpha(45)),
                  ),
                  child: Row(
                    children: [
                      // ✅ Show loading or profile image
                      if (isLoading)
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kPrimaryColor,
                              ),
                            ),
                          ),
                        )
                      else
                        _buildCustomerProfileImage(user),

                      SizedBox(width: 10.w),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.userName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.interTight(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 12.w,
                                  color: kPrimaryColor.withAlpha(200),
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    order.userPhone,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: GoogleFonts.interTight(
                                      fontSize: 11.sp,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16.w,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Method to build customer profile image with loading states
  Widget _buildCustomerProfileImage(UserModel? user) {
    final String? imageUrl = user?.image; // Using 'image' field from UserModel

    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryColor.withAlpha(40), width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return LoadingPlaceholder.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: kPrimaryColor.withAlpha(20),
                  child: Icon(
                    Icons.person_outline,
                    size: 20.w,
                    color: kPrimaryColor,
                  ),
                ),
              )
            : Container(
                color: kPrimaryColor.withAlpha(20),
                child: Icon(
                  Icons.person_outline,
                  size: 20.w,
                  color: kPrimaryColor,
                ),
              ),
      ),
    );
  }

  Widget _buildOrderItemsSection(ValueNotifier<bool> expandedNotifier) {
    return _buildCard(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: ValueListenableBuilder<bool>(
        valueListenable: expandedNotifier,
        builder: (context, isExpanded, child) {
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.only(bottom: 10.h),
              onExpansionChanged: (expanded) =>
                  expandedNotifier.value = expanded,
              leading: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: kPrimaryColor,
                  size: 18.w,
                ),
              ),
              title: Text(
                'Order Items (${order.items.length})',
                style: GoogleFonts.interTight(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withAlpha(220),
                ),
              ),
              trailing: Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: isExpanded
                      ? kPrimaryColor.withAlpha(20)
                      : Colors.grey.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: isExpanded ? kPrimaryColor : Colors.grey,
                  size: 18.w,
                ),
              ),
              children: [
                Divider(height: 1, color: Colors.grey.shade200),
                SizedBox(height: 12.h),
                ...order.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10.r),
                        onTap: () => Get.to(
                          () => FullImageScreen(imageUrl: item.imageUrl ?? ''),
                        ),
                        child: _buildOrderItemRow(item, index + 1),
                      ),
                      if (index != order.items.length - 1)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Divider(
                            height: 1,
                            color: Colors.grey.shade100,
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item, int itemNumber) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            '$itemNumber',
            style: GoogleFonts.interTight(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: kGreenColor,
            ),
          ),
        ),
        SizedBox(width: 4.w),
        _buildProductImage(item),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: GoogleFonts.interTight(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      'Qty: ${item.quantity}',
                      style: GoogleFonts.interTight(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black.withAlpha(180),
                      ),
                    ),
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'Rs. ${item.price.toStringAsFixed(1)} each',
                    style: GoogleFonts.interTight(
                      fontSize: 9.sp,
                      color: Colors.black.withAlpha(177),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Rs. ${(item.price * item.quantity).toStringAsFixed(1)}',
              style: GoogleFonts.interTight(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Total',
              style: GoogleFonts.interTight(
                fontSize: 10.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceBreakdownCard() {
    return _buildCard(
      child: Column(
        children: [
          _buildSectionHeader(
            title: 'Price Breakdown',
            icon: Icons.receipt_long_outlined,
          ),
          SizedBox(height: 16.h),
          _buildInfoRow(
            label: 'Payment Method',
            value: order.paymentMethod,
            valueStyle: GoogleFonts.interTight(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: kPrimaryColor,
            ),
          ),
          SizedBox(height: 10.h),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 10.h),
          _buildPriceRow(
            label: 'Items Total',
            amount: order.subtotal,
            isHighlighted: false,
          ),
          SizedBox(height: 10.h),
          _buildPriceRow(
            label: 'Delivery Fee',
            amount: order.deliveryFee,
            isHighlighted: false,
          ),
          SizedBox(height: 10.h),
          _buildPriceRow(
            label: 'Service Charges',
            amount: order.serviceFee,
            isHighlighted: false,
          ),
          SizedBox(height: 14.h),
          Divider(height: 1, color: Colors.grey.shade300),
          SizedBox(height: 14.h),
          _buildPriceRow(
            label: 'Grand Total',
            amount: order.total,
            isHighlighted: true,
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildRiderAssignment(BuildContext context) {
    final controller = Get.find<OrderActionsController>();
    return Obx(() {
      if (controller.loadingRiders.value) {
        return const LinearProgressIndicator();
      }
      if (controller.error.value != null && controller.riders.isEmpty) {
        return ErrorRetryWidget(
          errorMessage: controller.error.value!,
          onRetry: controller.reloadRiders,
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CommonDropdown<String>(
            label: 'Assign rider',
            value: controller.assignedRiderId.value ?? '',
            bottomSpacing: 0,
            items: [
              const DropdownMenuItem(value: '', child: Text('Not assigned')),
              ...controller.riders.map(
                (rider) => DropdownMenuItem(
                  value: rider.id,
                  child: Text('${rider.name} · ${rider.phone}'),
                ),
              ),
            ],
            onChanged: (value) async {
              final riderId = value == null || value.isEmpty ? null : value;
              final rider = controller.riders.firstWhereOrNull(
                (item) => item.id == riderId,
              );
              final confirmed = await CommonDialog.confirm(
                context: context,
                title: riderId == null
                    ? 'Remove rider assignment?'
                    : 'Assign this rider?',
                message: riderId == null
                    ? 'This order will no longer be assigned to a rider.'
                    : 'Assign ${rider?.name ?? 'the selected rider'} to this order?',
                icon: PhosphorIconsRegular.motorcycle,
                iconColor: Theme.of(context).colorScheme.primary,
                positiveButtonText: riderId == null
                    ? 'Remove assignment'
                    : 'Assign rider',
              );
              if (confirmed != true) return;
              try {
                await controller.assignRider(riderId);
              } catch (exception) {
                Get.snackbar('Could not assign rider', exception.toString());
              }
            },
          ),
        ),
      );
    });
  }

  // --------------------------------------------------------------------
  // Bottom action bar — dynamic status control
  // --------------------------------------------------------------------

  Widget _buildBottomActionBar(
    OrderController controller,
    BuildContext context,
  ) {
    final nextOptions = _kNextStatusOptions[order.status] ?? [];
    final isFinal = nextOptions.isEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.interTight(
                      fontSize: 11.5.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Rs. ${order.total.toStringAsFixed(1)}',
                    style: GoogleFonts.interTight(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            if (isFinal)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withAlpha(20),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _getStatusColor(order.status).withAlpha(60),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStatusIcon(order.status),
                      size: 16.w,
                      color: _getStatusColor(order.status),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      order.status.toLowerCase() == 'cancelled'
                          ? 'Order Cancelled'
                          : 'Order Completed',
                      style: GoogleFonts.interTight(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                        color: _getStatusColor(order.status),
                      ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withAlpha(40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _showStatusOptionsSheet(
                      context,
                      controller,
                      nextOptions,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 13.h),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_alt_rounded, size: 17.w),
                        SizedBox(width: 8.w),
                        Text(
                          'Update Status',
                          style: GoogleFonts.interTight(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet listing only the statuses this order is currently
  /// allowed to move to.
  void _showStatusOptionsSheet(
    BuildContext context,
    OrderController controller,
    List<String> nextOptions,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(22.r),
              topRight: Radius.circular(22.r),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                Text(
                  'Update Order Status',
                  style: GoogleFonts.interTight(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Current status: ${order.status}',
                  style: GoogleFonts.interTight(
                    fontSize: 12.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
                SizedBox(height: 16.h),
                ...nextOptions.map((status) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 10.h),
                    child: _buildStatusOptionTile(
                      status: status,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (status == 'Cancelled') {
                          _showCancelOrderDialog(context, controller);
                        } else {
                          _showStatusUpdateDialog(
                            context,
                            controller,
                            status,
                            _getStatusColor(status),
                            '${status == 'Delivered' ? 'Mark as Delivered' : status} Order',
                            _kStatusDialogMessage[status] ??
                                'Update this order to "$status"?',
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOptionTile({
    required String status,
    required VoidCallback onTap,
  }) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);
    final isDestructive = status == 'Cancelled';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: color.withAlpha(isDestructive ? 10 : 14),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(9.w),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18.w, color: color),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'Delivered'
                        ? 'Mark as Delivered'
                        : 'Mark as $status',
                    style: GoogleFonts.interTight(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _getStatusMessage(status),
                    style: GoogleFonts.interTight(
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withAlpha(160)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Reusable helpers
  // --------------------------------------------------------------------

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: kPrimaryColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 18.w, color: kPrimaryColor),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.interTight(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black.withAlpha(220),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.interTight(
            fontSize: 12.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style:
                valueStyle ??
                GoogleFonts.interTight(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.w, color: kPrimaryColor),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: GoogleFonts.interTight(
              fontSize: 12.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(OrderItem item) {
    return Container(
      width: 58.w,
      height: 58.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
            ? Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return LoadingPlaceholder.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 58.w,
                      height: 58.w,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 20.w,
                    color: Colors.grey.shade400,
                  ),
                ),
              )
            : Icon(
                Icons.inventory_2_outlined,
                size: 24.w,
                color: Colors.grey.shade400,
              ),
      ),
    );
  }

  Widget _buildPriceRow({
    required String label,
    required double amount,
    required bool isHighlighted,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.interTight(
            fontSize: 12.sp,
            color: isHighlighted ? kPrimaryColor : Colors.grey.shade700,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(1)}',
          style: GoogleFonts.interTight(
            fontSize: isHighlighted ? 14.sp : 12.sp,
            color: isHighlighted ? kPrimaryColor : Colors.grey.shade700,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // Dialogs
  // --------------------------------------------------------------------

  void _showStatusUpdateDialog(
    BuildContext context,
    OrderController controller,
    String newStatus,
    Color color,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: title,
        message: message,
        icon: _getStatusIcon(newStatus),
        iconColor: color,
        negativeButtonText: 'No',
        positiveButtonText: 'Confirm',
        onPositiveButtonPressed: () async {
          Navigator.of(context).pop();
          await controller.updateOrderStatus(
            id: order.id,
            status: newStatus,
            orderId: order.orderId ?? '',
          );
        },
      ),
    );
  }

  void _showCancelOrderDialog(
    BuildContext context,
    OrderController controller,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CommonDialog(
        title: 'Cancel Order',
        message:
            'Are you sure you want to cancel this order? The product quantities will be restored to inventory. This action cannot be undone.',
        icon: Icons.cancel_outlined,
        iconColor: Colors.red,
        negativeButtonText: 'Exit',
        positiveButtonText: 'Confirm',
        onPositiveButtonPressed: () async {
          Navigator.of(dialogContext).pop();

          Get.dialog(
            Center(
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: kGreenColor),
                      const SizedBox(height: 16),
                      Text(
                        'Cancelling order...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            barrierDismissible: false,
          );

          try {
            final success = await controller.cancelOrder(order.id);

            if (Get.isDialogOpen ?? false) {
              Get.back();
            }

            if (success) {
              MessageToast.showToast(msg: 'Order cancelled successfully');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (Get.context != null && Navigator.canPop(Get.context!)) {
                  Get.offAll(() => MainScreen());
                }
              });
            }
          } catch (e) {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            MessageToast.showToast(msg: 'Error: ${e.toString()}');
          }
        },
      ),
    );
  }

  // --------------------------------------------------------------------
  // Formatting / status helpers
  // --------------------------------------------------------------------

  String _formatDateTime(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'The order is awaiting admin review and acceptance.';
      case 'accepted':
        return 'The order has been accepted and is being prepared.';
      case 'delivered':
        return 'The order was successfully delivered and completed.';
      case 'cancelled':
        return 'This order has been officially cancelled.';
      default:
        return 'Order status: $status';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions_outlined;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'delivered':
        return Icons.verified_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'accepted':
        return Colors.green.shade600;
      case 'delivered':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return kPrimaryColor;
    }
  }
}
