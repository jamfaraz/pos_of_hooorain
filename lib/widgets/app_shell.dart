import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../controllers/theme_controller.dart';
import '../services/admin_access_service.dart';
import 'common_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.child, this.topBarAction, super.key});

  final Widget child;
  final Widget? topBarAction;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  static const _groups = <_NavGroup>[
    _NavGroup('Overview', [
      _NavItem(
        'Dashboard',
        '/dashboard',
        PhosphorIconsRegular.squaresFour,
        PhosphorIconsFill.squaresFour,
      ),
    ]),
    _NavGroup('Sell', [
      _NavItem(
        'Billing',
        '/billing',
        PhosphorIconsRegular.cashRegister,
        PhosphorIconsFill.cashRegister,
      ),
      _NavItem(
        'Bill history',
        '/bill-history',
        PhosphorIconsRegular.receipt,
        PhosphorIconsFill.receipt,
      ),
      _NavItem(
        'Online orders',
        '/orders',
        PhosphorIconsRegular.truck,
        PhosphorIconsFill.truck,
      ),
    ]),
    _NavGroup('Stock', [
      _NavItem(
        'Products',
        '/products',
        PhosphorIconsRegular.tag,
        PhosphorIconsFill.tag,
      ),
      _NavItem(
        'Featured',
        '/featured',
        PhosphorIconsRegular.star,
        PhosphorIconsFill.star,
      ),
      _NavItem(
        'Hidden',
        '/hidden',
        PhosphorIconsRegular.eyeSlash,
        PhosphorIconsFill.eyeSlash,
      ),
      _NavItem(
        'Categories',
        '/categories',
        PhosphorIconsRegular.storefront,
        PhosphorIconsFill.storefront,
      ),
      _NavItem(
        'Inventory',
        '/inventory',
        PhosphorIconsRegular.package,
        PhosphorIconsFill.package,
      ),
    ]),
    _NavGroup('Money', [
      _NavItem(
        'Item profit',
        '/item-profit',
        PhosphorIconsRegular.chartLineUp,
        PhosphorIconsFill.chartLineUp,
      ),
      _NavItem(
        'Expenses',
        '/expenses',
        PhosphorIconsRegular.wallet,
        PhosphorIconsFill.wallet,
      ),
      _NavItem(
        'Reports',
        '/reports',
        PhosphorIconsRegular.chartBar,
        PhosphorIconsFill.chartBar,
      ),
    ]),
    _NavGroup('People', [
      _NavItem(
        'Riders',
        '/riders',
        PhosphorIconsRegular.usersThree,
        PhosphorIconsFill.usersThree,
      ),
    ]),
    _NavGroup('Grow', [
      _NavItem(
        'Offers',
        '/offers',
        PhosphorIconsRegular.megaphone,
        PhosphorIconsFill.megaphone,
      ),
    ]),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.slash &&
        FocusManager.instance.primaryFocus?.context?.widget is! EditableText) {
      _searchFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (Get.isDialogOpen == true) {
        Get.back();
        return KeyEventResult.handled;
      }
      _scaffoldKey.currentState?.closeDrawer();
    }
    return KeyEventResult.ignored;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Log out?',
      message: 'You will need to sign in again to access the control room.',
      icon: PhosphorIconsRegular.signOut,
      iconColor: Theme.of(context).colorScheme.error,
      positiveButtonText: 'Log out',
    );
    if (confirmed != true) return;
    try {
      await Get.find<AdminAccessService>().logout();
      if (mounted) Get.offAllNamed('/login');
    } catch (exception) {
      Get.snackbar(
        'Could not log out',
        exception.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 1100;
        final showDrawer = width < 900;
        final railWidth = isDesktop ? 233.0 : 80.0;

        return Focus(
          onKeyEvent: _handleKey,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: showDrawer
                ? Drawer(
                    width: 270,
                    child: SafeArea(
                      child: _navigationRail(expanded: true, inDrawer: true),
                    ),
                  )
                : null,
            body: Padding(
              padding: EdgeInsets.all(showDrawer ? 0 : 16),
              child: Row(
                children: [
                  if (!showDrawer) ...[
                    Container(
                      width: railWidth,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: theme.dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.045),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _navigationRail(
                        expanded: isDesktop,
                        inDrawer: false,
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        _topBar(
                          context,
                          showMenu: showDrawer,
                          surface: theme.scaffoldBackgroundColor,
                        ),
                        SizedBox(height: showDrawer ? 8 : 14),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1680),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  showDrawer ? 14 : 4,
                                  showDrawer ? 12 : 4,
                                  showDrawer ? 14 : 4,
                                  showDrawer ? 12 : 4,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: widget.child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(
    BuildContext context, {
    required bool showMenu,
    required Color surface,
  }) {
    final theme = Theme.of(context);
    final themeController = Get.find<ThemeController>();
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: showMenu ? 8 : 0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            IconButton(
              tooltip: 'Open navigation',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(PhosphorIconsRegular.list),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (query) {
                      if (query.trim().isNotEmpty) {
                        Get.toNamed(
                          '/products',
                          parameters: {'q': query.trim()},
                        );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: showMenu
                          ? 'Search products, bills...'
                          : 'Search products, bills, customers',
                      prefixIcon: const Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 19,
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 42,
                        minHeight: 40,
                      ),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '/',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: themeController.isDark.value
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: themeController.toggleTheme,
            icon: Obx(
              () => Icon(
                themeController.isDark.value
                    ? PhosphorIconsRegular.sun
                    : PhosphorIconsRegular.moon,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Get.toNamed('/notifications'),
            icon: const Icon(PhosphorIconsRegular.bell),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (action) {
              if (action == 'logout') _confirmLogout(context);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(PhosphorIconsRegular.signOut, size: 18),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            icon: const Icon(PhosphorIconsRegular.userCircle),
          ),
          if (widget.topBarAction != null) ...[
            const SizedBox(width: 6),
            widget.topBarAction!,
          ],
        ],
      ),
    );
  }

  Widget _navigationRail({required bool expanded, required bool inDrawer}) {
    final theme = Theme.of(context);
    final activePath = Get.currentRoute;
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        expanded ? 16 : 10,
        20,
        expanded ? 16 : 10,
        16,
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: [
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIconsFill.storefront,
                      color: theme.colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOORAIN',
                          style: GoogleFonts.fraunces(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'CONTROL ROOM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.1,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Icon(
                PhosphorIconsFill.storefront,
                size: 25,
                color: theme.colorScheme.primary,
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final group in _groups) ...[
                  if (expanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 13, 8, 6),
                      child: Text(
                        group.label.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final item in group.items)
                    _navItem(
                      item,
                      expanded: expanded,
                      selected:
                          activePath == item.path ||
                          (activePath == '/' && item.path == '/dashboard'),
                      inDrawer: inDrawer,
                    ),
                ],
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Admin workspace',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navItem(
    _NavItem item, {
    required bool expanded,
    required bool selected,
    required bool inDrawer,
  }) {
    final theme = Theme.of(context);
    final icon = Icon(
      selected ? item.activeIcon : item.icon,
      size: 20,
      color: selected ? theme.colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: expanded ? '' : item.label,
        child: InkWell(
          onTap: () {
            if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
            if (Get.currentRoute != item.path) Get.offNamed(item.path);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
            decoration: BoxDecoration(
              color: selected ? theme.colorScheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: expanded
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: selected
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _NavGroup {
  const _NavGroup(this.label, this.items);

  final String label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon, this.activeIcon);

  final String label;
  final String path;
  final PhosphorIconData icon;
  final PhosphorIconData activeIcon;
}
