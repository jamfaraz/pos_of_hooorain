import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'order_screen.dart';

class OrdersWorkspaceScreen extends StatefulWidget {
  const OrdersWorkspaceScreen({super.key});

  @override
  State<OrdersWorkspaceScreen> createState() => _OrdersWorkspaceScreenState();
}

class _OrdersWorkspaceScreenState extends State<OrdersWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  static const _statuses = ['Pending', 'Accepted', 'Delivered', 'Cancelled'];
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: ValueKey(_statuses[_tabs.index]),
      child: OrdersScreen(
        orderStatus: _statuses[_tabs.index],
        showHeader: false,
        topContent: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Online orders',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: _statuses
                  .map(
                    (status) => Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status == 'Pending')
                            const Icon(PhosphorIconsRegular.clock, size: 16),
                          if (status == 'Accepted')
                            const Icon(PhosphorIconsRegular.package, size: 16),
                          if (status == 'Delivered')
                            const Icon(
                              PhosphorIconsRegular.checkCircle,
                              size: 16,
                            ),
                          if (status == 'Cancelled')
                            const Icon(PhosphorIconsRegular.xCircle, size: 16),
                          const SizedBox(width: 8),
                          Text(status),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              dividerColor: theme.dividerColor,
              indicatorSize: TabBarIndicatorSize.label,
            ),
          ],
        ),
      ),
    );
  }
}
