import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:hoorain_pos/widgets/backbutton.dart';

import '../../constants.dart';
import '../../controllers/sales_controller.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';

class SalesScreen extends StatelessWidget {
  SalesScreen({super.key});

  final SalesController controller = Get.put(SalesController());
  final currency = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs ',
    decimalDigits: 0,
  );
  final dateFmt = DateFormat('dd MMM, hh:mm a');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }
        if (controller.hasError.value) {
          return _ErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.refresh,
          );
        }

        return RefreshIndicator(
          color: kPrimaryColor,
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _Header(controller: controller, currency: currency),
                    _RangeSelector(controller: controller),
                  ],
                ),
              ),
              if (controller.statusBreakdown.isNotEmpty)
                SliverToBoxAdapter(
                  child: _StatusBreakdown(controller: controller),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order History',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        '${controller.rangeLabel} · ${controller.filteredOrders.length} orders',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.filteredOrders.isEmpty)
                SliverToBoxAdapter(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _OrderTile(
                        order: controller.filteredOrders[index],
                        controller: controller,
                        dateFmt: dateFmt,
                        currency: currency,
                      ),
                      childCount: controller.filteredOrders.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.currency});

  final SalesController controller;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 10,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: kPrimaryColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: BackNavigatingButton(color: Colors.white),
              ),
              Text(
                'Sales Overview',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              InkWell(
                onTap: controller.refresh,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL SALES',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white60,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currency.format(controller.totalSales.value),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${controller.totalOrders.value} orders',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    Text(
                      '  ·  ',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${currency.format(controller.deliveredRevenue.value)} delivered',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range selector — segmented control + custom date range button
// ---------------------------------------------------------------------------

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.controller});

  final SalesController controller;

  static const Map<SalesRange, String> _labels = {
    SalesRange.today: 'Today',
    SalesRange.thisWeek: '7 Days',
    SalesRange.thisMonth: '30 Days',
  };

  static Widget _themed(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: kPrimaryColor,
          surface: Colors.white,
        ),
        dialogBackgroundColor: Colors.white,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: kPrimaryColor,
          headerForegroundColor: Colors.white,
          headerHeadlineStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          headerHelpStyle: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.white70,
          ),
          weekdayStyle: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.black45,
          ),
          dayStyle: GoogleFonts.poppins(fontSize: 11),
          yearStyle: GoogleFonts.poppins(fontSize: 11),
          rangePickerBackgroundColor: Colors.white,
          rangeSelectionBackgroundColor: kPrimaryColor.withOpacity(0.12),
          // Today's date: primary text normally, white when it is selected
          // (selected day is filled with primary, so primary text vanished).
          todayForegroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) return Colors.white;
            return kPrimaryColor;
          }),
          dayOverlayColor: MaterialStateProperty.all(
            kPrimaryColor.withOpacity(0.08),
          ),
          elevation: 1,
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(0.85)),
        child: child!,
      ),
    );
  }

  Future<void> _pickSingleDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: controller.singleDate.value ?? now,
      builder: _themed,
    );
    if (picked != null) controller.setSingleDate(picked);
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          controller.customRange.value ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      builder: _themed,
    );
    if (picked != null) controller.setCustomRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Obx(() {
          final selected = controller.selectedRange.value;
          return Row(
            children: [
              ..._labels.entries.map((e) {
                final isSelected = selected == e.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => controller.applyRange(e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? kPrimaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        e.value,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () => _pickSingleDate(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == SalesRange.singleDay
                        ? kPrimaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Iconsax.calendar_tick,
                    size: 18,
                    color: selected == SalesRange.singleDay
                        ? Colors.white
                        : Colors.black45,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _pickCustomRange(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected == SalesRange.custom
                        ? kPrimaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Iconsax.calendar_1,
                    size: 18,
                    color: selected == SalesRange.custom
                        ? Colors.white
                        : Colors.black45,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status breakdown
// ---------------------------------------------------------------------------

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.controller});

  final SalesController controller;

  Color _colorFor(String status) {
    switch (status) {
      case 'Delivered':
        return kGreenColor;
      case 'Accepted':
        return kBlueColor;
      case 'Pending':
        return kYellowColor;
      case 'Rejected':
      case 'Cancelled':
        return kRedColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: controller.statusBreakdown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final entry = controller.statusBreakdown.entries.elementAt(i);
              final color = _colorFor(entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.key} · ${entry.value}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order tile — fetches live customer info by userId, taps through to detail
// ---------------------------------------------------------------------------

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.order,
    required this.controller,
    required this.dateFmt,
    required this.currency,
  });

  final OrderModel order;
  final SalesController controller;
  final DateFormat dateFmt;
  final NumberFormat currency;

  Color _statusColor(String status) {
    switch (status) {
      case 'Delivered':
        return kGreenColor;
      case 'Accepted':
        return kBlueColor;
      case 'Pending':
        return kYellowColor;
      case 'Rejected':
      case 'Cancelled':
        return kRedColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsCount = order.items.length;
    final statusColor = _statusColor(order.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Get.toNamed('/orders/detail', arguments: order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withAlpha(38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<UserModel?>(
              future: controller.getCustomer(order.userId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final hasPhoto = user?.image != null && user!.image!.isNotEmpty;
                final displayName = user?.fullName ?? order.userName;
                final initial = displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?';

                if (hasPhoto) {
                  return CircleAvatar(
                    radius: 21,
                    backgroundImage: NetworkImage(user.image!),
                  );
                }
                return CircleAvatar(
                  radius: 21,
                  backgroundColor: kPrimaryColor.withOpacity(0.1),
                  child: Text(
                    initial,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: kPrimaryColor,
                      fontSize: 15,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<UserModel?>(
                          future: controller.getCustomer(order.userId),
                          builder: (context, snapshot) {
                            final user = snapshot.data;
                            final name = user?.fullName ?? order.userName;
                            final phone = user?.phoneNumber ?? order.userPhone;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (phone != null && phone.isNotEmpty)
                                  Text(
                                    phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.black38,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      Text(
                        currency.format(order.total),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '#${order.orderId ?? order.id} · $itemsCount item${itemsCount == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.black.withAlpha(177),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Iconsax.clock, size: 12, color: Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        dateFmt.format(order.orderDate),
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: Colors.black45,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.receipt_2_1,
              size: 40,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No sales in this period',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different date range',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.warning_2, size: 48, color: kRedColor),
            const SizedBox(height: 12),
            Text(
              'Could not load sales',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              icon: const Icon(Iconsax.refresh, color: Colors.white, size: 16),
              label: Text(
                'Retry',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
