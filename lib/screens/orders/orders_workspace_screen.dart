import 'package:flutter/material.dart';

import 'order_screen.dart';

class OrdersWorkspaceScreen extends StatelessWidget {
  const OrdersWorkspaceScreen({super.key});

  static const _statuses = ['Pending', 'Accepted', 'Delivered', 'Cancelled'];

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _statuses.length,
    child: Column(
      children: [
        TabBar(
          isScrollable: true,
          tabs: _statuses.map((status) => Tab(text: status)).toList(),
        ),
        Expanded(
          child: TabBarView(
            children: _statuses
                .map((status) => OrdersScreen(orderStatus: status))
                .toList(),
          ),
        ),
      ],
    ),
  );
}
