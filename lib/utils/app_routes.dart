import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/auth/login_screen.dart';
import '../screens/common/control_room_placeholder.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/item_profit/item_profit_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/billing/billing_screen.dart';
import '../screens/orders/orders_workspace_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/category/category_management_screen.dart';
import '../screens/products/product_management_screen.dart';
import '../screens/offers/offers_screen.dart';
import '../screens/riders/riders_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import 'admin_route_guard.dart';
import 'auth_gate.dart';
import '../widgets/app_shell.dart';
import '../bindings/category_management_binding.dart';
import '../bindings/product_management_binding.dart';
import '../bindings/offers_binding.dart';
import '../bindings/riders_binding.dart';
import '../bindings/order_detail_binding.dart';
import '../bindings/dashboard_binding.dart';
import '../bindings/item_profit_binding.dart';
import '../bindings/inventory_binding.dart';
import '../bindings/reports_binding.dart';
import '../bindings/billing_binding.dart';
import '../models/order_model.dart';

abstract final class AppRoutes {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: '/', page: () => const AuthGate()),
    GetPage(name: '/login', page: () => const LoginScreen()),
    GetPage(
      name: '/orders/detail',
      binding: OrderDetailBinding(),
      transition: Transition.noTransition,
      page: () => AdminRouteGuard(
        child: OrderDetailScreen(order: Get.arguments as OrderModel),
      ),
    ),
    _protected(
      '/dashboard',
      const DashboardScreen(),
      binding: DashboardBinding(),
    ),
    _protected(
      '/products',
      const ProductManagementScreen(),
      binding: ProductManagementBinding(),
    ),
    _protected(
      '/featured',
      const ProductManagementScreen(initialMode: 'featured'),
      binding: ProductManagementBinding(),
    ),
    _protected(
      '/hidden',
      const ProductManagementScreen(initialMode: 'hidden'),
      binding: ProductManagementBinding(),
    ),
    _protected(
      '/categories',
      const CategoryManagementScreen(),
      binding: CategoryManagementBinding(),
    ),
    _protected('/orders', const OrdersWorkspaceScreen()),
    _protected('/billing', const BillingScreen(), binding: BillingBinding()),
    _protected('/bill-history', SalesScreen()),
    _protected('/offers', const OffersScreen(), binding: OffersBinding()),
    _protected('/riders', const RidersScreen(), binding: RidersBinding()),
    _protected(
      '/item-profit',
      const ItemProfitScreen(),
      binding: ItemProfitBinding(),
    ),
    _protected(
      '/inventory',
      const InventoryScreen(),
      binding: InventoryBinding(),
    ),
    _protected('/reports', const ReportsScreen(), binding: ReportsBinding()),
    _placeholder('/notifications', 'Notifications'),
  ];

  static GetPage<dynamic> _protected(
    String path,
    Widget screen, {
    Bindings? binding,
  }) {
    return GetPage(
      name: path,
      binding: binding,
      transition: Transition.noTransition,
      page: () => AdminRouteGuard(child: AppShell(child: screen)),
    );
  }

  static GetPage<dynamic> _placeholder(String path, String title) {
    return GetPage(
      name: path,
      transition: Transition.noTransition,
      page: () => AdminRouteGuard(
        child: AppShell(
          child: ControlRoomPlaceholder(
            title: title,
            description: 'This section will be added in its planned phase.',
          ),
        ),
      ),
    );
  }
}
