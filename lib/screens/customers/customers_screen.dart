import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/user_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/retry_widget.dart';
import '../users/user_detail_screen.dart';

class CustomersSearchField extends StatefulWidget {
  const CustomersSearchField({super.key});

  @override
  State<CustomersSearchField> createState() => _CustomersSearchFieldState();
}

class _CustomersSearchFieldState extends State<CustomersSearchField> {
  late final UsersController _controller;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<UsersController>();
    _textController = TextEditingController(
      text: _controller.searchQuery.value,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 46,
      child: TextField(
        controller: _textController,
        onChanged: (value) {
          _controller.searchQuery.value = value;
          setState(() {});
        },
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          hintText: 'Search customers by name, email or phone',
          suffixIcon: _textController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _textController.clear();
                    _controller.searchQuery.value = '';
                    setState(() {});
                  },
                  icon: const Icon(PhosphorIconsRegular.x),
                ),
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class CustomersNewBillButton extends StatelessWidget {
  const CustomersNewBillButton({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    if (compact) {
      return IconButton.filled(
        tooltip: 'New bill',
        onPressed: () => Get.toNamed('/billing'),
        icon: const Icon(PhosphorIconsRegular.plus),
      );
    }
    return FilledButton.icon(
      onPressed: () => Get.toNamed('/billing'),
      icon: const Icon(PhosphorIconsRegular.plus, size: 18),
      label: const Text('New bill'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(132, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const _tabNames = [
    'All',
    'Shops',
    'Home users',
    'Blocked',
    'Shop requests',
  ];

  late final UsersController _controller = Get.find<UsersController>();
  final _tableScrollController = ScrollController(keepScrollOffset: false);
  int _selectedTab = 0;

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Obx(() {
      final users = _controller.users
          .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
          .map(_CustomerEntry.new)
          .toList();
      if (_controller.isLoading.value && users.isEmpty) {
        return const Center(child: AppLoader(label: 'Loading customers...'));
      }
      if (_controller.errorMessage.value.isNotEmpty && users.isEmpty) {
        return ErrorRetryWidget(
          errorMessage: _controller.errorMessage.value,
          onRetry: _controller.fetchUsers,
        );
      }

      final query = _controller.searchQuery.value.trim().toLowerCase();
      final filtered =
          users.where((customer) {
            final matchesTab = switch (_selectedTab) {
              1 => customer.type == 'Shop' && !customer.isShopRequest,
              2 => customer.type == 'Home' && !customer.isShopRequest,
              3 => customer.isBanned,
              4 => customer.isShopRequest,
              _ => true,
            };
            final matchesSearch =
                query.isEmpty ||
                customer.name.toLowerCase().contains(query) ||
                customer.email.toLowerCase().contains(query) ||
                customer.phone.toLowerCase().contains(query);
            return matchesTab && matchesSearch;
          }).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      final showGlobalSearch = constraints.maxWidth < 900;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGlobalSearch) ...[
            const CustomersSearchField(),
            const SizedBox(height: 18),
          ],
          _pageHeading(context),
          const SizedBox(height: 12),
          _tabs(context, users),
          const SizedBox(height: 2),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          Expanded(
            child: _customerTable(
              context,
              filtered,
              constraints.maxWidth,
              isSearching: query.isNotEmpty,
            ),
          ),
        ],
      );
    }),
  );

  Widget _pageHeading(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customers and shops',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.55,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Approve shops, verify buyers and manage customer access.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _tabs(BuildContext context, List<_CustomerEntry> customers) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _tabNames.length; index++)
            _tab(context, index, customers),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index, List<_CustomerEntry> users) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _selectedTab == index;
    final count = switch (index) {
      1 =>
        users
            .where((user) => user.type == 'Shop' && !user.isShopRequest)
            .length,
      2 =>
        users
            .where((user) => user.type == 'Home' && !user.isShopRequest)
            .length,
      3 => users.where((user) => user.isBanned).length,
      4 => users.where((user) => user.isShopRequest).length,
      _ => users.length,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
          if (_tableScrollController.hasClients) {
            _tableScrollController.jumpTo(0);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _tabNames[index],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerTable(
    BuildContext context,
    List<_CustomerEntry> customers,
    double availableWidth, {
    required bool isSearching,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (availableWidth < 900) {
            return _customerCards(
              context,
              customers,
              constraints.maxHeight,
              isSearching: isSearching,
            );
          }
          final tableWidth = math.max(availableWidth, 1080.0).toDouble();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _tableHeader(context),
                  Expanded(
                    child: customers.isEmpty
                        ? _emptyState(context, isSearching)
                        : ListView.separated(
                            controller: _tableScrollController,
                            primary: false,
                            itemCount: customers.length,
                            separatorBuilder: (_, index) => Divider(
                              height: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            itemBuilder: (context, index) =>
                                _customerRow(context, customers[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _customerCards(
    BuildContext context,
    List<_CustomerEntry> customers,
    double height, {
    required bool isSearching,
  }) => SizedBox(
    height: height,
    child: customers.isEmpty
        ? _emptyState(context, isSearching)
        : ListView.separated(
            controller: _tableScrollController,
            primary: false,
            itemCount: customers.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) =>
                _customerCompactRow(context, customers[index]),
          ),
  );

  Widget _customerCompactRow(BuildContext context, _CustomerEntry customer) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 540;
        return Material(
          color: colors.surface,
          child: InkWell(
            onTap: () => Get.to(
              () => UserDetailScreen(userId: customer.id),
              transition: Transition.cupertino,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _avatar(context, customer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              customer.email.isEmpty
                                  ? customer.phone.isEmpty
                                        ? 'No contact details'
                                        : customer.phone
                                  : customer.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!narrow) ...[
                        _typePill(context, customer.type),
                        const SizedBox(width: 8),
                        _statusPill(context, customer),
                      ],
                      _customerActionMenu(customer),
                    ],
                  ),
                  if (narrow) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _typePill(context, customer.type),
                        const SizedBox(width: 8),
                        _statusPill(context, customer),
                        const Spacer(),
                        Text(
                          '${customer.totalOrders} orders · ${Money.rs(customer.totalSpent)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          customer.phone.isEmpty ? 'No phone' : customer.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${customer.totalOrders} orders',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          Money.rs(customer.totalSpent),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          customer.lastOrderLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tableHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.25,
    );
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.32),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Row(
        children: [
          _headerCell('Customer', 5, style),
          _headerCell('Type', 2, style),
          _headerCell('Phone', 2, style),
          _headerCell('Orders', 1, style, align: TextAlign.center),
          _headerCell('Total spent', 2, style, align: TextAlign.right),
          _headerCell('Last order', 2, style),
          _headerCell('Status', 2, style),
        ],
      ),
    );
  }

  Widget _headerCell(
    String label,
    int flex,
    TextStyle? style, {
    TextAlign align = TextAlign.left,
  }) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        style: style,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );

  Widget _customerRow(BuildContext context, _CustomerEntry customer) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => Get.to(
          () => UserDetailScreen(userId: customer.id),
          transition: Transition.cupertino,
        ),
        hoverColor: colors.primary.withValues(alpha: 0.035),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _rowCell(
                  5,
                  Row(
                    children: [
                      _avatar(context, customer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    customer.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (customer.isVerified) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              customer.email.isEmpty
                                  ? 'No email'
                                  : customer.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _rowCell(2, _typePill(context, customer.type)),
                _rowCell(
                  2,
                  Text(
                    customer.phone.isEmpty ? '—' : customer.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                _rowCell(
                  1,
                  Text(
                    '${customer.totalOrders}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                _rowCell(
                  2,
                  Text(
                    Money.rs(customer.totalSpent),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _rowCell(
                  2,
                  Text(
                    customer.lastOrderLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                _rowCell(
                  2,
                  Row(
                    children: [
                      Expanded(child: _statusPill(context, customer)),
                      _customerActionMenu(customer),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowCell(int flex, Widget child) => Expanded(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: child,
    ),
  );

  Widget _customerActionMenu(
    _CustomerEntry customer,
  ) => PopupMenuButton<String>(
    tooltip: 'Customer actions',
    icon: const Icon(PhosphorIconsRegular.dotsThreeVertical, size: 18),
    onSelected: (action) => _handleCustomerAction(customer, action),
    itemBuilder: (context) => [
      if (customer.isShopRequest) ...[
        const PopupMenuItem(value: 'approve_shop', child: Text('Approve shop')),
        const PopupMenuItem(
          value: 'reject_shop',
          child: Text('Reject request'),
        ),
      ] else
        PopupMenuItem(
          value: 'toggle_verification',
          child: Text(
            customer.isVerified ? 'Mark unverified' : 'Verify customer',
          ),
        ),
      PopupMenuItem(
        value: 'toggle_block',
        child: Text(customer.isBanned ? 'Unblock account' : 'Block account'),
      ),
    ],
  );

  Widget _avatar(BuildContext context, _CustomerEntry customer) {
    final theme = Theme.of(context);
    final image = customer.image;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.55),
            theme.colorScheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: image.isEmpty
          ? Center(
              child: Text(
                customer.initial,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  customer.initial,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _typePill(BuildContext context, String type) {
    final theme = Theme.of(context);
    final isShop = type == 'Shop';
    final color = isShop
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          type,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _statusPill(BuildContext context, _CustomerEntry customer) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final String label;
    final Color color;
    if (customer.isBanned) {
      label = 'Blocked';
      color = colors.error;
    } else if (customer.isShopRequest) {
      label = 'Pending';
      color = colors.tertiary;
    } else {
      label = 'Active';
      color = const Color(0xFF2EAF70);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isSearching) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.usersThree,
            size: 38,
            color: colors.onSurfaceVariant.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching
                ? 'No customers match your search'
                : 'No customers here yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSearching
                ? 'Try another name, email or phone number.'
                : 'Customers will appear here when they create an account.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _handleCustomerAction(_CustomerEntry customer, String action) {
    switch (action) {
      case 'approve_shop':
        _controller.updateShopRequestStatus(customer.id, 'approved');
      case 'reject_shop':
        _controller.updateShopRequestStatus(customer.id, 'rejected');
      case 'toggle_verification':
        _controller.toggleVerificationStatus(customer.id, customer.isVerified);
      case 'toggle_block':
        _controller.toggleBanStatus(customer.id, customer.isBanned);
    }
  }
}

class _CustomerEntry {
  _CustomerEntry(this.document) : data = document.data();

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final Map<String, dynamic> data;

  String get id => document.id;
  String get name => (data['fullName'] ?? data['name'] ?? 'Unknown customer')
      .toString()
      .trim();
  String get email => (data['email'] ?? '').toString().trim();
  String get phone =>
      (data['phoneNumber'] ?? data['phone'] ?? '').toString().trim();
  String get image =>
      (data['image'] ?? data['profileImage'] ?? '').toString().trim();
  String get initial => name.isEmpty ? 'C' : name.substring(0, 1).toUpperCase();
  int get totalOrders => _toInt(data['totalOrders'] ?? data['orderCount']);
  double get totalSpent => _toDouble(data['totalSpent'] ?? data['amountSpent']);
  bool get isBanned => data['isBanned'] == true;
  bool get isVerified =>
      data['isVerified'] == true ||
      data['profileStatus']?.toString().toLowerCase() == 'verified';
  bool get isShopRequest => _shopRequestStatus(data) == 'pending';
  String get type => _customerType(data);
  String get lastOrderLabel => _formatLastOrder(
    data['lastOrderAt'] ?? data['lastOrderDate'] ?? data['lastOrder'],
  );

  static String _customerType(Map<String, dynamic> data) {
    final values = [
      data['customerType'],
      data['userType'],
      data['accountType'],
      data['type'],
    ];
    for (final value in values) {
      final normalized = value?.toString().trim().toLowerCase();
      if (normalized == null || normalized.isEmpty) continue;
      if (const {
        'shop',
        'shop owner',
        'shop_owner',
        'merchant',
        'business',
        'retailer',
        'store',
      }.contains(normalized)) {
        return 'Shop';
      }
      if (const {
        'home',
        'home user',
        'home_user',
        'customer',
        'buyer',
        'personal',
        'user',
      }.contains(normalized)) {
        return 'Home';
      }
    }
    if (data['isShop'] == true ||
        (data['shopName'] is String &&
            (data['shopName'] as String).trim().isNotEmpty) ||
        const {'pending', 'approved'}.contains(_shopRequestStatus(data))) {
      return 'Shop';
    }
    return 'Shop';
  }

  static String? _shopRequestStatus(Map<String, dynamic> data) {
    final request = data['shopRequest'];
    final value = request is Map
        ? request['status']
        : data['shopRequestStatus'] ??
              data['shopApprovalStatus'] ??
              data['shopStatus'];
    if (value is bool) return value ? 'pending' : null;
    final status = value?.toString().trim().toLowerCase();
    if (const {
      'pending',
      'requested',
      'submitted',
      'under review',
      'under_review',
    }.contains(status)) {
      return 'pending';
    }
    if (const {'approved', 'accepted'}.contains(status)) return 'approved';
    if (const {'rejected', 'declined'}.contains(status)) return 'rejected';
    if (data['isShopRequest'] == true || data['shopRequested'] == true) {
      return 'pending';
    }
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatLastOrder(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return '—';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(orderDay).inDays;
    if (daysAgo <= 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return '$daysAgo days ago';
    return DateFormat('d MMM').format(date);
  }
}
