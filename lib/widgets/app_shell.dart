import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/theme_controller.dart';
import '../services/admin_access_service.dart';
import 'common_dialog.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.child,
    this.topBarAction,
    this.topBarLeading,
    super.key,
  });

  final Widget child;
  final Widget? topBarAction;
  final Widget? topBarLeading;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _navigationController = ScrollController(keepScrollOffset: false);
  final Map<String, GlobalKey> _navigationKeys = {};

  /// Set the moment a menu item is tapped so the highlight never lags.
  String? _tapped;

  static const _groups = <_NavGroup>[
    _NavGroup('Overview', [
      _NavItem('Dashboard', '/dashboard', Iconsax.element_3),
    ]),
    _NavGroup('Sell', [
      _NavItem('Billing', '/billing', Iconsax.calculator),
      _NavItem('Bill history', '/bill-history', Iconsax.receipt),
      _NavItem('Online orders', '/orders', Iconsax.truck),
    ]),
    _NavGroup('Stock', [
      _NavItem('Products', '/products', Iconsax.tag),
      _NavItem('Featured', '/featured', Iconsax.star),
      _NavItem('Hidden', '/hidden', Iconsax.eye_slash),
      _NavItem('Categories', '/categories', Iconsax.category),
      _NavItem('Inventory', '/inventory', Iconsax.box),
    ]),
    _NavGroup('Money', [
      _NavItem('Expenses', '/expenses', Iconsax.wallet_2),
      _NavItem('Reports', '/reports', Iconsax.chart_2),
    ]),
    _NavGroup('People', [
      _NavItem('Customers and shops', '/customers', Iconsax.profile_2user),
      _NavItem('Riders', '/riders', Iconsax.user_tag),
    ]),
    _NavGroup('Grow', [_NavItem('Offers', '/offers', Iconsax.discount_shape)]),
    _NavGroup('Admin', [
      _NavItem('Store setup', '/store-setup', Iconsax.setting_2),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    // GetX updates currentRoute just after the page is built; refresh once
    // so the highlight is right without needing a scroll or tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
      _revealActiveNavigationItem();
    });
  }

  void _revealActiveNavigationItem() {
    final path = _activePath();
    final key = _navigationKeys[path];
    final itemContext = key?.currentContext;
    if (itemContext == null) return;
    Scrollable.ensureVisible(
      itemContext,
      alignment: 0.35,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _navigationController.dispose();
    super.dispose();
  }

  String _activePath() {
    final name = ModalRoute.of(context)?.settings.name;
    final raw =
        _tapped ??
        ((name != null && name.isNotEmpty) ? name : Get.currentRoute);
    return Uri.tryParse(raw)?.path ?? raw;
  }

  bool _isActive(_NavItem item) {
    final path = _activePath();
    return path == item.path ||
        path.startsWith('${item.path}/') ||
        (path == '/' && item.path == '/dashboard');
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Log out?',
      message: 'You will need to sign in again to access the control room.',
      icon: Iconsax.logout,
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
        final railWidth = isDesktop ? 248.0 : 80.0;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: showDrawer
              ? Drawer(
                  width: 288,
                  backgroundColor: theme.colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(26),
                    ),
                  ),
                  child: SafeArea(
                    child: _navigationRail(expanded: true, inDrawer: true),
                  ),
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(showDrawer ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showDrawer) ...[
                    Container(
                      width: railWidth,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: theme.dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _navigationRail(
                        expanded: isDesktop,
                        inDrawer: false,
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            showDrawer ? 14 : 2,
                            showDrawer ? 8 : 0,
                            showDrawer ? 14 : 2,
                            0,
                          ),
                          child: _topBar(context, showMenu: showDrawer),
                        ),
                        SizedBox(height: showDrawer ? 6 : 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1680),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  showDrawer ? 14 : 2,
                                  0,
                                  showDrawer ? 14 : 2,
                                  showDrawer ? 12 : 0,
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

  // --------------------------------------------------------------------
  // Top bar: slim (48px), no card, shows where you are
  // --------------------------------------------------------------------

  Widget _topBar(BuildContext context, {required bool showMenu}) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (showMenu) ...[
            _squareButton(
              context,
              tooltip: 'Open navigation',
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: const Icon(Iconsax.menu),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: widget.topBarLeading ?? const SizedBox.shrink()),
          if (widget.topBarAction != null) ...[
            const SizedBox(width: 12),
            widget.topBarAction!,
          ],
          const SizedBox(width: 12),
          _themeButton(context),
          const SizedBox(width: 8),
          _bellButton(context),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Small reusable buttons
  // --------------------------------------------------------------------

  Widget _squareButton(
    BuildContext context, {
    required String tooltip,
    required VoidCallback onTap,
    required Widget child,
    double size = 40,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.dividerColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: IconTheme(
              data: IconThemeData(
                color: color ?? theme.colorScheme.onSurface,
                size: 19,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeButton(BuildContext context, {double size = 40}) {
    final c = Get.find<ThemeController>();
    return Obx(
      () => _squareButton(
        context,
        size: size,
        tooltip: c.isDark.value
            ? 'Switch to light theme'
            : 'Switch to dark theme',
        onTap: c.toggleTheme,
        child: Icon(c.isDark.value ? Iconsax.sun_1 : Iconsax.moon),
      ),
    );
  }

  Widget _bellButton(BuildContext context, {double size = 40}) => _squareButton(
    context,
    size: size,
    tooltip: 'Notifications',
    onTap: () => Get.toNamed('/notifications'),
    child: const Icon(Iconsax.notification),
  );

  Widget _logoutButton(BuildContext context, {double size = 40}) =>
      _squareButton(
        context,
        size: size,
        tooltip: 'Log out',
        color: Theme.of(context).colorScheme.error,
        onTap: () => _confirmLogout(context),
        child: const Icon(Iconsax.logout),
      );

  // --------------------------------------------------------------------
  // Sidebar
  // --------------------------------------------------------------------

  Widget _brand(ThemeData theme, {required bool expanded}) {
    final cs = theme.colorScheme;
    final tile = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(Iconsax.shop, color: cs.onPrimary, size: 22),
    );
    if (!expanded) return tile;
    return Row(
      children: [
        tile,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOORAIN',
                style: GoogleFonts.fraunces(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'CONTROL ROOM',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  letterSpacing: 1.7,
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _accountFooter(ThemeData theme, {required bool expanded}) {
    final cs = theme.colorScheme;
    if (!expanded) return _logoutButton(context, size: 44);
    final soft = theme.inputDecorationTheme.fillColor ?? cs.surfaceContainerLow;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.user, size: 18, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Admin workspace',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _logoutButton(context, size: 36),
        ],
      ),
    );
  }

  Widget _navigationRail({required bool expanded, required bool inDrawer}) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.fromLTRB(
        expanded ? 14 : 18,
        22,
        expanded ? 14 : 18,
        16,
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(expanded ? 6 : 0, 0, 6, 18),
            child: _brand(theme, expanded: expanded),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
              child: Text(
                'OVERVIEW',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: theme.dividerColor),
            ),
          _navItem(
            _groups.first.items.first,
            expanded: expanded,
            selected: _isActive(_groups.first.items.first),
            inDrawer: inDrawer,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                controller: _navigationController,
                child: Column(
                  crossAxisAlignment: expanded
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    for (final group in _groups.skip(1)) ...[
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 8, 6),
                          child: Text(
                            group.label.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: theme.dividerColor),
                        ),
                      for (final item in group.items)
                        _navItem(
                          item,
                          expanded: expanded,
                          selected: _isActive(item),
                          inDrawer: inDrawer,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _accountFooter(theme, expanded: expanded),
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
    final cs = theme.colorScheme;

    // Icon sits in a small tile: filled with the brand colour when selected.
    final iconTile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Icon(
        item.icon,
        size: 19,
        color: selected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
    );

    return Padding(
      key: _navigationKeys.putIfAbsent(item.path, GlobalKey.new),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: expanded ? '' : item.label,
        child: InkWell(
          onTap: () {
            setState(() => _tapped = item.path);
            if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
            if (Get.currentRoute != item.path) Get.offNamed(item.path);
          },
          borderRadius: BorderRadius.circular(14),
          hoverColor: cs.primary.withValues(alpha: 0.06),
          splashColor: cs.primary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 8 : 0),
            decoration: BoxDecoration(
              color: selected && expanded
                  ? cs.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: expanded
                ? Row(
                    children: [
                      iconTile,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            letterSpacing: -0.1,
                            color: selected
                                ? cs.onPrimaryContainer
                                : cs.onSurface.withValues(alpha: 0.78),
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: iconTile),
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
  const _NavItem(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}
