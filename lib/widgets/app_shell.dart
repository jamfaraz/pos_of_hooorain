import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../controllers/theme_controller.dart';
import '../services/admin_access_service.dart';
import '../services/notification_service.dart';
import 'common_dialog.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

/// Emerald sidebar palette (the sidebar keeps its own deep-green look in
/// both light and dark themes).
class _Emerald {
  static const top = Color(0xFF0F3D33);
  static const mid = Color(0xFF0B2F28);
  static const bottom = Color(0xFF09261F);
  static const ink = Color(0xFF073028);
  static const mint = Color(0xFF7DF0B6);
  static const mintSoft = Color(0xFFB6FFD9);
  static const label = Color(0xFF8DB8A8);
  static const text = Color(0xFFC2DDD2);
  static const textMuted = Color(0xFF9FC7B8);
  static const white = Color(0xFFF2FFF8);
  static const danger = Color(0xFFFFB4B4);
}

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
  final NotificationService _notificationService = NotificationService();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _unreadNotifications;

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
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _unreadNotifications = _notificationService.watchUnread(userId);
    }
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
      MessageToast.showError(
        msg: exception.toString(),
        title: 'Could not log out',
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
        final railWidth = isDesktop ? 260.0 : 84.0;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: showDrawer
              ? Drawer(
                  width: 300,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: _sidebarDecoration(),
                      child: SafeArea(
                        child: _navigationRail(expanded: true, inDrawer: true),
                      ),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.all(showDrawer ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!showDrawer) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: railWidth,
                      clipBehavior: Clip.antiAlias,
                      decoration: _sidebarDecoration(),
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
  // Sidebar surface: deep emerald gradient with a deep shadow
  // --------------------------------------------------------------------

  BoxDecoration _sidebarDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_Emerald.top, _Emerald.mid, _Emerald.bottom],
        stops: [0, 0.55, 1],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ],
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
    Color? background,
    Color? borderColor,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor ?? theme.dividerColor),
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

  Widget _bellButton(BuildContext context, {double size = 40}) {
    final unreadStream = _unreadNotifications;
    if (unreadStream == null) {
      return _squareButton(
        context,
        size: size,
        tooltip: 'Notifications',
        onTap: () => Get.toNamed('/notifications'),
        child: const Icon(Iconsax.notification),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: unreadStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        final hasUnread = unreadCount > 0;
        final surface = Theme.of(context).colorScheme.surface;
        final error = snapshot.hasError ? ' · unable to load unread count' : '';
        return _squareButton(
          context,
          size: size,
          tooltip: hasUnread
              ? 'Notifications · $unreadCount unread$error'
              : 'Notifications$error',
          onTap: () => Get.toNamed('/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Iconsax.notification),
              if (hasUnread)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Logout button styled for the dark emerald sidebar.
  Widget _logoutButton(BuildContext context, {double size = 40}) {
    return Tooltip(
      message: 'Log out',
      child: Material(
        color: _Emerald.danger.withValues(alpha: 0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _Emerald.danger.withValues(alpha: 0.22)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _confirmLogout(context),
          child: SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: Icon(Iconsax.logout, size: 18, color: _Emerald.danger),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Sidebar
  // --------------------------------------------------------------------

  Widget _brand({required bool expanded}) {
    final tile = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _Emerald.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/landing/appLogo.png', fit: BoxFit.cover),
    );
    if (!expanded) return tile;
    return Row(
      children: [
        tile,
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOORAIN',
                maxLines: 1,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacing: 0.8,
                  color: _Emerald.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'CONTROL ROOM',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  letterSpacing: 2.4,
                  color: _Emerald.mint,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fadeDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _accountFooter({required bool expanded}) {
    if (!expanded) return _logoutButton(context, size: 46);

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_Emerald.mintSoft, Color(0xFF4FD99A)],
            ),
          ),
          child: const Icon(Iconsax.user, size: 18, color: _Emerald.ink),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _Emerald.mint,
              shape: BoxShape.circle,
              border: Border.all(color: _Emerald.mid, width: 2),
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: _Emerald.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Full access',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: _Emerald.textMuted,
                    fontWeight: FontWeight.w500,
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

  Widget _groupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
          color: _Emerald.label,
        ),
      ),
    );
  }

  Widget _navigationRail({required bool expanded, required bool inDrawer}) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            expanded ? 12 : 16,
            22,
            expanded ? 12 : 16,
            14,
          ),
          child: Column(
            crossAxisAlignment: expanded
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(expanded ? 6 : 0, 0, 6, 14),
                child: _brand(expanded: expanded),
              ),
              _fadeDivider(),
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
                        for (final group in _groups) ...[
                          if (expanded)
                            _groupLabel(group.label)
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              child: _fadeDivider(),
                            ),
                          for (final item in group.items)
                            _navItem(
                              item,
                              expanded: expanded,
                              selected: _isActive(item),
                              inDrawer: inDrawer,
                            ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _accountFooter(expanded: expanded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _navItem(
    _NavItem item, {
    required bool expanded,
    required bool selected,
    required bool inDrawer,
  }) {
    return Padding(
      key: _navigationKeys.putIfAbsent(item.path, GlobalKey.new),
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: _NavTile(
        item: item,
        expanded: expanded,
        selected: selected,
        onTap: () {
          setState(() => _tapped = item.path);
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
          if (Get.currentRoute != item.path) Get.offNamed(item.path);
        },
      ),
    );
  }
}

/// A single emerald sidebar entry: soft white hover, and a bright mint-white
/// pill with a dark green icon tile when selected.
class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final expanded = widget.expanded;

    final icon = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      child: Icon(
        widget.item.icon,
        size: 18,
        color: selected
            ? _Emerald.mint
            : (_hover ? Colors.white : _Emerald.text),
      ),
    );

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: selected
            ? Colors.white.withValues(alpha: 0.10)
            : (_hover ? Colors.white.withValues(alpha: 0.05) : null),
        border: Border.all(
          color: selected
              ? _Emerald.mint.withValues(alpha: 0.28)
              : Colors.transparent,
        ),
      ),
      child: expanded
          ? Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      letterSpacing: -0.1,
                      color: selected
                          ? Colors.white
                          : (_hover ? Colors.white : _Emerald.text),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: icon),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: expanded ? '' : widget.item.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: body,
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
