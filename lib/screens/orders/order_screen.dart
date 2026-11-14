import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/constants.dart';
import 'package:hoorain_pos/models/order_model.dart';
import 'package:hoorain_pos/screens/orders/order_card.dart';
import 'package:hoorain_pos/widgets/app_loader.dart';
import '../../controllers/order_controller.dart';
import '../../widgets/backbutton.dart';
import '../../widgets/retry_widget.dart';

enum OrderSort { newest, oldest, amountHigh, amountLow }

extension on OrderSort {
  String get label {
    switch (this) {
      case OrderSort.newest:
        return 'Newest first';
      case OrderSort.oldest:
        return 'Oldest first';
      case OrderSort.amountHigh:
        return 'Amount: high to low';
      case OrderSort.amountLow:
        return 'Amount: low to high';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderSort.newest:
        return Icons.arrow_downward_rounded;
      case OrderSort.oldest:
        return Icons.arrow_upward_rounded;
      case OrderSort.amountHigh:
        return Icons.trending_down_rounded;
      case OrderSort.amountLow:
        return Icons.trending_up_rounded;
    }
  }
}

class OrdersScreen extends StatefulWidget {
  final String orderStatus;
  const OrdersScreen({super.key, required this.orderStatus});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderController controller = Get.put(OrderController());
  final TextEditingController _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _paymentMethodFilter;
  OrderSort _sort = OrderSort.newest;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    controller.fetchOrders(orderStatus: widget.orderStatus);
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_startDate != null && _endDate != null) count++;
    if (_paymentMethodFilter != null) count++;
    if (_sort != OrderSort.newest) count++;
    return count;
  }

  bool get _hasDateFilter => _startDate != null && _endDate != null;

  List<OrderModel> _applyClientFilters(List<OrderModel> source) {
    Iterable<OrderModel> result = source;

    if (_searchQuery.isNotEmpty) {
      result = result.where((order) {
        final orderIdMatch = (order.orderId ?? order.id).toLowerCase().contains(
          _searchQuery,
        );
        final nameMatch = order.userName.toLowerCase().contains(_searchQuery);
        final phoneMatch = order.userPhone.toLowerCase().contains(_searchQuery);
        return orderIdMatch || nameMatch || phoneMatch;
      });
    }

    if (_paymentMethodFilter != null) {
      result = result.where((o) => o.paymentMethod == _paymentMethodFilter);
    }

    final list = result.toList();

    switch (_sort) {
      case OrderSort.newest:
        list.sort((a, b) => b.orderDate.compareTo(a.orderDate));
        break;
      case OrderSort.oldest:
        list.sort((a, b) => a.orderDate.compareTo(b.orderDate));
        break;
      case OrderSort.amountHigh:
        list.sort((a, b) => b.total.compareTo(a.total));
        break;
      case OrderSort.amountLow:
        list.sort((a, b) => a.total.compareTo(b.total));
        break;
    }

    return list;
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FilterSheet(
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          initialSort: _sort,
          initialPaymentMethod: _paymentMethodFilter,
          onApply: (start, end, sort, paymentMethod) {
            setState(() {
              _startDate = start;
              _endDate = end;
              _sort = sort;
              _paymentMethodFilter = paymentMethod;
            });
            if (start != null && end != null) {
              controller.filterOrdersByDateRange(start, end);
            } else {
              controller.fetchOrders(orderStatus: widget.orderStatus);
            }
          },
        );
      },
    );
  }

  void _clearAllFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _paymentMethodFilter = null;
      _sort = OrderSort.newest;
      _searchQuery = '';
      _searchController.clear();
      _isSearching = false;
    });
    controller.fetchOrders(orderStatus: widget.orderStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_activeFilterCount > 0 || _searchQuery.isNotEmpty)
            _buildActiveFilterBar(),
          Expanded(
            child: Obx(() {
              if (controller.hasError.value) {
                return Center(
                  child: ErrorRetryWidget(
                    onRetry: () =>
                        controller.fetchOrders(orderStatus: widget.orderStatus),
                    errorMessage: controller.errorMessage.value,
                  ),
                );
              }

              if (controller.isLoading.value) {
                return const AppLoader(label: 'Loading orders...');
              }

              final filtered = _applyClientFilters(controller.orders);

              if (filtered.isEmpty) {
                return ErrorRetryWidget(
                  onRetry: () {
                    _clearAllFilters();
                  },
                  errorMessage: controller.orders.isEmpty
                      ? 'No orders found for this status yet.'
                      : 'No orders match your search or filters.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await controller.fetchOrders(orderStatus: widget.orderStatus);
                },
                backgroundColor: Colors.white,
                color: kGreenColor,
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 14.h),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return OrderCard(
                      order: order,
                      onTap: () =>
                          Get.toNamed('/orders/detail', arguments: order),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: const BackNavigatingButton(color: kblack),
      titleSpacing: 0,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              cursorColor: kPrimaryColor,
              style: GoogleFonts.interTight(fontSize: 14.sp, color: kblack),
              decoration: InputDecoration(
                hintText: 'Search by order ID, name or phone',
                hintStyle: GoogleFonts.interTight(
                  fontSize: 13.sp,
                  color: Colors.grey.shade500,
                ),
                border: InputBorder.none,
              ),
            )
          : Text(
              '${widget.orderStatus} Orders',
              style: GoogleFonts.interTight(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: kblack,
              ),
            ),
      centerTitle: !_isSearching,
      actions: [
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close_rounded : Icons.search_rounded,
            color: kblack,
          ),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
              _isSearching = !_isSearching;
            });
          },
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: kblack),
              onPressed: _openFilterSheet,
            ),
            if (_activeFilterCount > 0)
              Positioned(
                top: 10,
                right: 8,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: const BoxDecoration(
                    color: kRedColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                  child: Text(
                    '$_activeFilterCount',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.interTight(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 6.w),
      ],
    );
  }

  Widget _buildActiveFilterBar() {
    final chips = <Widget>[];

    if (_searchQuery.isNotEmpty) {
      chips.add(
        _filterChip(
          label: '"$_searchQuery"',
          onRemove: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        ),
      );
    }

    if (_hasDateFilter) {
      chips.add(
        _filterChip(
          label: '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
          onRemove: () {
            setState(() {
              _startDate = null;
              _endDate = null;
            });
            controller.fetchOrders(orderStatus: widget.orderStatus);
          },
        ),
      );
    }

    if (_paymentMethodFilter != null) {
      chips.add(
        _filterChip(
          label: _paymentMethodFilter!,
          onRemove: () => setState(() => _paymentMethodFilter = null),
        ),
      );
    }

    if (_sort != OrderSort.newest) {
      chips.add(
        _filterChip(
          label: _sort.label,
          icon: _sort.icon,
          onRemove: () => setState(() => _sort = OrderSort.newest),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: chips),
            ),
          ),
          TextButton(
            onPressed: _clearAllFilters,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              'Clear all',
              style: GoogleFonts.interTight(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: kRedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required VoidCallback onRemove,
    IconData? icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: kPrimaryColor.withAlpha(18),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: kPrimaryColor.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12.sp, color: kPrimaryColor),
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: GoogleFonts.interTight(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(width: 4.w),
            InkWell(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 13.sp,
                color: kPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

/// Bottom sheet housing date range, sort, and payment-method filters
/// as a single professional filtration surface.
class _FilterSheet extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final OrderSort initialSort;
  final String? initialPaymentMethod;
  final void Function(
    DateTime? start,
    DateTime? end,
    OrderSort sort,
    String? paymentMethod,
  )
  onApply;

  const _FilterSheet({
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialSort,
    required this.initialPaymentMethod,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _start;
  DateTime? _end;
  late OrderSort _sort;
  String? _paymentMethod;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStartDate;
    _end = widget.initialEndDate;
    _sort = widget.initialSort;
    _paymentMethod = widget.initialPaymentMethod;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: isStart ? DateTime(2000) : (_start ?? DateTime(2000)),
      lastDate: DateTime(2070),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: kPrimaryColor,
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = null;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: GoogleFonts.interTight(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _start = null;
                        _end = null;
                        _sort = OrderSort.newest;
                        _paymentMethod = null;
                      });
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.interTight(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: kRedColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              _sectionLabel('Date range'),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: _start == null
                          ? 'Start date'
                          : _formatDate(_start!),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _dateField(
                      label: _end == null ? 'End date' : _formatDate(_end!),
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 22.h),
              _sectionLabel('Sort by'),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: OrderSort.values.map((sort) {
                  final selected = _sort == sort;
                  return ChoiceChip(
                    label: Text(sort.label),
                    labelStyle: GoogleFonts.interTight(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey.shade700,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _sort = sort),
                    selectedColor: kPrimaryColor,
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                      side: BorderSide.none,
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),

              SizedBox(height: 22.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if ((_start != null) ^ (_end != null)) {
                      Get.snackbar(
                        'Incomplete range',
                        'Please select both a start and end date, or clear both.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: kRedColor,
                        colorText: Colors.white,
                      );
                      return;
                    }
                    widget.onApply(_start, _end, _sort, _paymentMethod);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Apply filters',
                    style: GoogleFonts.interTight(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.interTight(
      fontSize: 12.5.sp,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade800,
    ),
  );

  Widget _dateField({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.interTight(
                fontSize: 12.sp,
                color: Colors.black87,
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              size: 15.sp,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
