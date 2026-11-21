import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:hoorain_pos/models/order_model.dart';
import 'package:hoorain_pos/widgets/app_loader.dart';
import 'package:hoorain_pos/widgets/empty_state.dart';
import 'package:hoorain_pos/widgets/page_header.dart';
import '../../controllers/order_controller.dart';
import '../../widgets/order_card.dart';
import '../../widgets/order_history_table.dart';
import '../../widgets/retry_widget.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

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
  final bool showHeader;
  final Widget? topContent;
  const OrdersScreen({
    super.key,
    required this.orderStatus,
    this.showHeader = true,
    this.topContent,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderController controller = Get.put(OrderController());
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _orderDateFormat = DateFormat('dd MMM, HH:mm');

  DateTime? _startDate;
  DateTime? _endDate;
  String? _paymentMethodFilter;
  OrderSort _sort = OrderSort.newest;
  String _searchQuery = '';

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

    if (_hasDateFilter) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day + 1);
      result = result.where(
        (order) =>
            !order.orderDate.isBefore(start) && order.orderDate.isBefore(end),
      );
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    final filterSheet = _FilterSheet(
      asDialog: isDesktop,
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
        if (start == null || end == null) {
          controller.fetchOrders(orderStatus: widget.orderStatus);
        }
      },
    );
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: filterSheet,
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => filterSheet,
      );
    }
  }

  void _clearAllFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _paymentMethodFilter = null;
      _sort = OrderSort.newest;
      _searchQuery = '';
      _searchController.clear();
    });
    controller.fetchOrders(orderStatus: widget.orderStatus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: () => controller.fetchOrders(orderStatus: widget.orderStatus),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.topContent != null) widget.topContent!,
            if (widget.showHeader)
              PageHeader(
                title: 'Online orders',
                subtitle:
                    'Review customer orders and keep each delivery moving.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.fetchOrders(orderStatus: widget.orderStatus),
                    icon: const Icon(
                      PhosphorIconsRegular.arrowClockwise,
                      size: 18,
                    ),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                        hintText: 'Search order, customer or phone',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(PhosphorIconsRegular.funnel, size: 18),
                  label: Text(
                    _activeFilterCount == 0
                        ? 'Filter'
                        : 'Filter $_activeFilterCount',
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Refresh orders',
                  onPressed: () =>
                      controller.fetchOrders(orderStatus: widget.orderStatus),
                  icon: const Icon(
                    PhosphorIconsRegular.arrowClockwise,
                    size: 19,
                  ),
                ),
              ],
            ),
            if (_activeFilterCount > 0 || _searchQuery.isNotEmpty)
              _buildActiveFilterBar(context),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.hasError.value) {
                return ErrorRetryWidget(
                  onRetry: () =>
                      controller.fetchOrders(orderStatus: widget.orderStatus),
                  errorMessage: controller.errorMessage.value,
                );
              }
              if (controller.isLoading.value) {
                return const AppLoader(label: 'Loading orders...');
              }
              final filtered = _applyClientFilters(controller.orders);
              late final Widget ordersContent;
              if (filtered.isEmpty) {
                ordersContent = EmptyState(
                  title: controller.orders.isEmpty
                      ? 'No ${widget.orderStatus.toLowerCase()} orders'
                      : 'No matching orders',
                  message: controller.orders.isEmpty
                      ? 'New customer orders will appear here.'
                      : 'Try changing your search or filters.',
                  actionLabel: controller.orders.isEmpty
                      ? 'Refresh orders'
                      : 'Clear filters',
                  onAction: controller.orders.isEmpty
                      ? () => controller.fetchOrders(
                          orderStatus: widget.orderStatus,
                        )
                      : _clearAllFilters,
                );
              } else {
                ordersContent = LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 900) {
                      return Column(
                        children: [
                          const OrderHistoryTableHeader(),
                          for (var index = 0; index < filtered.length; index++)
                            OrderHistoryTableRow(
                              order: filtered[index],
                              placedAt: _orderDateFormat.format(
                                filtered[index].orderDate,
                              ),
                              loadCustomerImage: () => controller
                                  .getCustomerImage(filtered[index].userId),
                              onTap: () => Get.toNamed(
                                '/orders/detail',
                                arguments: filtered[index],
                              ),
                              isLast: index == filtered.length - 1,
                            ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (final order in filtered)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                            child: OrderCard(
                              order: order,
                              compact: true,
                              loadCustomerImage: () =>
                                  controller.getCustomerImage(order.userId),
                              onTap: () => Get.toNamed(
                                '/orders/detail',
                                arguments: order,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ordersContent,
                  if (controller.hasMoreOrders.value ||
                      controller.isLoadingMore.value ||
                      controller.loadMoreError.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: controller.isLoadingMore.value
                          ? const AppLoader(label: 'Loading more orders...')
                          : controller.loadMoreError.value.isNotEmpty
                          ? Column(
                              children: [
                                Text(
                                  'Could not load more orders: ${controller.loadMoreError.value}',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () => controller.loadMoreOrders(
                                    orderStatus: widget.orderStatus,
                                  ),
                                  child: const Text('Try again'),
                                ),
                              ],
                            )
                          : OutlinedButton(
                              onPressed: () => controller.loadMoreOrders(
                                orderStatus: widget.orderStatus,
                              ),
                              child: const Text('Load more orders'),
                            ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar(BuildContext context) {
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
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
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.error,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              child: Icon(
                PhosphorIconsRegular.x,
                size: 13,
                color: theme.colorScheme.onPrimaryContainer,
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
  final bool asDialog;
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
    required this.asDialog,
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.asDialog ? 0 : MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(widget.asDialog ? 20 : 22),
        ),
        padding: EdgeInsets.fromLTRB(20, widget.asDialog ? 20 : 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.asDialog)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter & Sort',
                    style: theme.textTheme.titleLarge?.copyWith(
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
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: widget.asDialog ? 12 : 18),

              _sectionLabel('Date range'),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dateField(
                      label: _end == null ? 'End date' : _formatDate(_end!),
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              _sectionLabel('Sort by'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: OrderSort.values.map((sort) {
                  final selected = _sort == sort;
                  return ChoiceChip(
                    label: Text(sort.label),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _sort = sort),
                    selectedColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if ((_start != null) ^ (_end != null)) {
                      MessageToast.showWarning(
                        msg:
                            'Please select both a start and end date, or clear both.',
                        title: 'Incomplete range',
                      );
                      return;
                    }
                    widget.onApply(_start, _end, _sort, _paymentMethod);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply filters',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
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
    style: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _dateField({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Icon(
              PhosphorIconsRegular.calendarBlank,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
