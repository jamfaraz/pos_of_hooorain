import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/constants.dart';
import 'package:hoorain_pos/models/order_model.dart';

/// A compact, information-dense order card for the Hoorain admin panel.
///
/// Shows order identity, status, customer, a small product-thumbnail
/// preview (so staff can recognize a ghee / rice / detergent order at a
/// glance without opening it), payment method, and the total.
class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  Color get _statusColor {
    switch (order.status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF5A524);
      case 'cancelled':
        return const Color(0xFFE5484D);
      case 'delivered':
        return const Color(0xFF17A34A);
      default:
        return kPrimaryColor;
    }
  }

  String get _displayId {
    final raw = order.orderId ?? order.id;
    return raw.length > 8 ? raw.substring(0, 8) : raw;
  }

  String get _formattedDateTime {
    final date = order.orderDate;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} • $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: Colors.black.withAlpha(14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5.w,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(14.r)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderRow(),
                        SizedBox(height: 4.h),
                        Text(
                          _formattedDateTime,
                          style: GoogleFonts.interTight(
                            fontSize: 11.sp,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Divider(height: 1, color: Colors.grey.shade100),
                        ),
                        _buildCustomerRow(),
                        SizedBox(height: 10.h),
                        _buildItemsPreview(),
                        SizedBox(height: 12.h),
                        _buildFooterRow(),
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

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                '#$_displayId',
                style: GoogleFonts.interTight(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              if (order.isFirstOrder) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withAlpha(24),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Text(
                    'FIRST ORDER',
                    style: GoogleFonts.interTight(
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6C63FF),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: _statusColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            order.status.toUpperCase(),
            style: GoogleFonts.interTight(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10.sp,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerRow() {
    return Row(
      children: [
        CircleAvatar(
          radius: 15.r,
          backgroundColor: kPrimaryColor.withAlpha(24),
          child: Text(
            order.userName.isNotEmpty ? order.userName[0].toUpperCase() : '?',
            style: GoogleFonts.interTight(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: kPrimaryColor,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.interTight(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade900,
                ),
              ),
              Text(
                order.userPhone,
                style: GoogleFonts.interTight(fontSize: 11.sp, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Small thumbnail strip so staff can recognize a ghee / rice / detergent
  /// order at a glance, plus a one-line comma list of item names.
  Widget _buildItemsPreview() {
    final items = order.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final previewItems = items.take(3).toList();
    final remaining = items.length - previewItems.length;
    final nameSummary = items.map((e) => e.productName).join(', ');

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 34.w,
            child: Stack(
              children: [
                for (int i = 0; i < previewItems.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i * 22.w),
                    child: _ItemThumb(item: previewItems[i]),
                  ),
                if (remaining > 0)
                  Padding(
                    padding: EdgeInsets.only(left: previewItems.length * 22.w),
                    child: Container(
                      width: 34.w,
                      height: 34.w,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+$remaining',
                        style: GoogleFonts.interTight(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: previewItems.length * 22.w + (remaining > 0 ? 20.w : 0)),
          Expanded(
            child: Text(
              nameSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.interTight(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterRow() {
    return Row(
      children: [
        Icon(Icons.inventory_2_outlined, size: 15.sp, color: Colors.grey.shade500),
        SizedBox(width: 5.w),
        Text(
          '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
          style: GoogleFonts.interTight(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Text(
          'Rs. ${order.total.toStringAsFixed(0)}',
          style: GoogleFonts.interTight(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }
}

class _ItemThumb extends StatelessWidget {
  final OrderItem item;
  const _ItemThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 3),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(color: Colors.grey.shade100);
              },
            )
          : _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: kPrimaryColor.withAlpha(20),
      alignment: Alignment.center,
      child: Icon(Icons.shopping_basket_outlined, size: 16.sp, color: kPrimaryColor),
    );
  }
}