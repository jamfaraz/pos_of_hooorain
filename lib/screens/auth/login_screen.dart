import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/controllers/login_controller.dart';

import '../../utils/toas_message.dart';

/// Hoorain landing page with a sign-in popup, all in one screen.
/// - Fixed nav bar that frosts on scroll, staggered hero, scroll-reveal sections.
/// - "Admin login" opens the sign-in card over a blurred backdrop
///   (Esc or tap outside closes it).
/// Colours match the Hoorain control room web design.

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------

class _C {
  static const bg = Color(0xFFF1F5F3);
  static const ink = Color(0xFF10231D);
  static const sub = Color(0xFF566B63);
  static const line = Color(0xFFE1E9E5);
  static const pri = Color(0xFF0F7B5F);
  static const priInk = Color(0xFF0B6650);
  static const priSoft = Color(0xFFE1F2EB);
  static const deep = Color(0xFF0B3D31);
  static const mint = Color(0xFF8FE0C4);
  static const acc = Color(0xFFE8590C);
  static const info = Color(0xFF1D4FC4);
  static const infoSoft = Color(0xFFE7EEFD);
}

Color _a(Color c, double o) => c.withAlpha((o * 255).clamp(0, 255).round());

TextStyle _display(Color c, double size, {FontWeight w = FontWeight.w700}) =>
    GoogleFonts.fraunces(
      color: c,
      fontSize: size,
      height: 1.06,
      fontWeight: w,
      letterSpacing: -size * .02,
    );

TextStyle _body(
  Color c,
  double size, {
  FontWeight w = FontWeight.w400,
  double? h,
}) => GoogleFonts.plusJakartaSans(
  color: c,
  fontSize: size,
  fontWeight: w,
  height: h,
);

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final LoginController _controller = Get.put(LoginController());
  final ScrollController _scroll = ScrollController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _hide = true;

  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _pricesKey = GlobalKey();
  final GlobalKey _howKey = GlobalKey();

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool _open = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _scroll.dispose();
    _enter.dispose();
    _panel.dispose();
    _shake.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openLogin() {
    setState(() => _open = true);
    _panel.forward();
  }

  Future<void> _closeLogin() async {
    FocusScope.of(context).unfocus();
    await _panel.reverse();
    if (mounted) setState(() => _open = false);
  }

  void _fail(String message) {
    MessageToast.showToast(msg: message);
    HapticFeedback.mediumImpact();
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    // Ignore extra Enter presses while a login is already running.
    if (_controller.isLoading.value) return;
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty) {
      _fail('Please enter your email');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _fail('Enter a valid email, like name@hoorain.com');
      return;
    }
    if (password.isEmpty) {
      _fail('Please enter your password');
      return;
    }
    FocusScope.of(context).unfocus();
    await _controller.loginAdmin(email: email, password: password);
  }

  void _to(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _toTopAndOpen() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
    _openLogin();
  }

  /// Staggered entrance for the hero.
  Widget _seq(int i, Widget child) {
    final start = (0.06 + i * 0.09).clamp(0.0, 0.75);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _enter,
      child: child,
      builder: (_, c) {
        final t = Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ).transform(_enter.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c),
        );
      },
    );
  }

  Widget _wrap(bool wide, Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20),
        child: child,
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_open) _closeLogin();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: _C.bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final wide = box.maxWidth >= 900;
                    final cols = box.maxWidth >= 900
                        ? 3
                        : (box.maxWidth >= 620 ? 2 : 1);
                    final inner =
                        math.min<double>(box.maxWidth, 1200.0) -
                        (wide ? 80.0 : 40.0);
                    final topPad = MediaQuery.of(context).padding.top + 72;

                    return SingleChildScrollView(
                      controller: _scroll,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _wrap(
                            wide,
                            Padding(
                              padding: EdgeInsets.only(
                                top: topPad + (wide ? 40 : 20),
                                bottom: wide ? 96 : 60,
                              ),
                              child: wide ? _heroWide() : _heroNarrow(),
                            ),
                          ),
                          _featuresBand(wide, cols, inner),
                          _wrap(
                            wide,
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: wide ? 96 : 60,
                              ),
                              child: _Reveal(
                                scroll: _scroll,
                                child: _pricing(wide),
                              ),
                            ),
                          ),
                          _wrap(wide, _how(wide, cols, inner)),
                          _wrap(
                            wide,
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: wide ? 96 : 60,
                              ),
                              child: _Reveal(
                                scroll: _scroll,
                                child: _cta(wide),
                              ),
                            ),
                          ),
                          _footer(wide),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(top: 0, left: 0, right: 0, child: _navBar()),
              if (_open) _loginLayer(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Nav
  // ---------------------------------------------------------------------------

  Widget _navBar() {
    final wide = MediaQuery.of(context).size.width >= 900;
    final top = MediaQuery.of(context).padding.top;
    final tiny = MediaQuery.of(context).size.width < 380;

    return AnimatedBuilder(
      animation: _scroll,
      builder: (_, __) {
        final off = _scroll.hasClients ? _scroll.offset : 0.0;
        final t = (off / 90).clamp(0.0, 1.0);
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: .001 + 16 * t,
              sigmaY: .001 + 16 * t,
            ),
            child: Container(
              padding: EdgeInsets.only(top: top),
              decoration: BoxDecoration(
                color: _a(Colors.white, .86 * t),
                border: Border(bottom: BorderSide(color: _a(_C.line, t))),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20),
                    child: SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          _Logo(size: wide ? 40 : 36),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hoorain', style: _display(_C.ink, 23)),
                              if (!tiny)
                                Text(
                                  'Control room',
                                  style: _body(
                                    _C.sub,
                                    11.5,
                                    w: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          if (wide) ...[
                            _NavLink('Features', () => _to(_featuresKey)),
                            const SizedBox(width: 28),
                            _NavLink(
                              'Home and shop prices',
                              () => _to(_pricesKey),
                            ),
                            const SizedBox(width: 28),
                            _NavLink('How it works', () => _to(_howKey)),
                            const SizedBox(width: 28),
                          ],
                          _GreenButton(
                            label: wide ? 'Admin login' : 'Login',
                            height: 44,
                            fontSize: 14.5,
                            onPressed: _openLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Hero
  // ---------------------------------------------------------------------------

  Widget _heroWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: _heroText(64)),
        const SizedBox(width: 56),
        Expanded(flex: 10, child: _seq(3, const _ProductsMock())),
      ],
    );
  }

  Widget _heroNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroText(MediaQuery.of(context).size.width < 380 ? 30 : 34),
        const SizedBox(height: 36),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _seq(3, const _ProductsMock()),
          ),
        ),
      ],
    );
  }

  Widget _heroText(double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seq(
          0,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _C.priSoft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home_rounded, size: 16, color: _C.priInk),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'For grocery suppliers selling to shops and homes',
                    style: _body(_C.priInk, 12.5, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _seq(
          1,
          Text(
            'Supply every shop and every home from one control room.',
            style: _display(_C.ink, size),
          ),
        ),
        const SizedBox(height: 20),
        _seq(
          2,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              'Hoorain brings counter billing, stock, categories, offers and online orders together, with a separate price list for shops and for households.',
              style: _body(_C.sub, 17, h: 1.55),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _seq(
          3,
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _GreenButton(
                label: 'Admin login',
                icon: Icons.arrow_forward_rounded,
                height: 56,
                fontSize: 16,
                onPressed: _openLogin,
              ),
              _GhostButton(
                label: 'See what it does',
                onPressed: () => _to(_featuresKey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _seq(
          4,
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _trust('Home and shop pricing'),
              _trust('Optional bulk tiers'),
              _trust('Offers on any product'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trust(String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.check_rounded, size: 18, color: _C.pri),
      const SizedBox(width: 8),
      Text(t, style: _body(_C.sub, 13.5, w: FontWeight.w600)),
    ],
  );

  // ---------------------------------------------------------------------------
  // Features
  // ---------------------------------------------------------------------------

  Widget _heading(
    String eyebrow,
    String title,
    String? sub,
    bool wide, {
    bool light = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: _body(
            light ? _C.mint : _C.priInk,
            12.5,
            w: FontWeight.w800,
          ).copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: _display(light ? Colors.white : _C.ink, wide ? 44 : 27),
        ),
        if (sub != null) ...[
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Text(
              sub,
              style: _body(
                light ? _a(Colors.white, .82) : _C.sub,
                16.5,
                h: 1.55,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _featuresBand(bool wide, int cols, double inner) {
    const items = [
      (
        Icons.receipt_long_rounded,
        'Counter billing',
        'Bill walk-in customers fast. The right price list applies by customer type, bulk prices apply on their own, and stock drops when you print.',
      ),
      (
        Icons.home_rounded,
        'Separate home and shop prices',
        'Every product carries MRP, a home price and a shop price, with your margin shown for each so you never sell below cost by mistake.',
      ),
      (
        Icons.folder_outlined,
        'Categories and subcategories',
        'Group products the way customers shop. Tap a category to see its products, and hide a whole category from the app in one switch.',
      ),
      (
        Icons.inventory_2_outlined,
        'Stock and reorder alerts',
        'Track quantity per product, set a reorder level, and see low and out-of-stock items before customers do.',
      ),
      (
        Icons.local_offer_outlined,
        'Offers on any product',
        'Run a percent or rupee discount for everyone, home users or shops only. Top offers lead the app home screen.',
      ),
      (
        Icons.local_shipping_outlined,
        'Online orders',
        'Orders from the Home and Shop apps land in one queue, so you can confirm, pack and deliver without switching screens.',
      ),
    ];
    final w = (inner - (cols - 1) * 20) / cols;

    return Container(
      key: _featuresKey,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.symmetric(horizontal: BorderSide(color: _C.line)),
      ),
      child: _wrap(
        wide,
        Padding(
          padding: EdgeInsets.symmetric(vertical: wide ? 88 : 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Reveal(
                scroll: _scroll,
                child: _heading(
                  'Features',
                  'Everything the supplier side needs',
                  'One place to sell at the counter, manage the catalogue and decide what customers see in the app.',
                  wide,
                ),
              ),
              const SizedBox(height: 44),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  for (var i = 0; i < items.length; i++)
                    SizedBox(
                      width: w,
                      child: _Reveal(
                        scroll: _scroll,
                        delay: Duration(milliseconds: (i % cols) * 110),
                        child: _HoverCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: i == 4
                                      ? const Color(0xFFFDEBDD)
                                      : _C.priSoft,
                                ),
                                child: Icon(
                                  items[i].$1,
                                  size: 24,
                                  color: i == 4
                                      ? const Color(0xFFB53F00)
                                      : _C.priInk,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                items[i].$2,
                                style: _body(_C.ink, 18, w: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                items[i].$3,
                                style: _body(_C.sub, 14.5, h: 1.55),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Two price lists
  // ---------------------------------------------------------------------------

  Widget _pricing(bool wide) {
    const points = [
      'Home users see the home price in the Home app.',
      'Approved shops see the shop price, including their own bulk tiers.',
      'Bulk pricing is optional. Switch it on only for products that need it.',
    ];

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Two price lists',
          'One product, one stock count, two prices.',
          'You supply to shops and to households, so each customer type should see the price that fits. Set both once and Hoorain does the rest.',
          wide,
          light: true,
        ),
        const SizedBox(height: 26),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_rounded, size: 22, color: _C.mint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p, style: _body(Colors.white, 15.5, h: 1.45)),
                ),
              ],
            ),
          ),
      ],
    );

    final cards = wide
        ? const Row(
            children: [
              Expanded(
                child: _AppPriceCard(
                  label: 'Home app',
                  icon: Icons.home_rounded,
                  chipBg: _C.infoSoft,
                  chipFg: _C.info,
                  price: 'Rs 115',
                  caption: 'Home price',
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: _AppPriceCard(
                  label: 'Shop app',
                  icon: Icons.storefront_rounded,
                  chipBg: _C.priSoft,
                  chipFg: _C.priInk,
                  price: 'Rs 104',
                  caption: 'Shop price',
                  bulk: true,
                ),
              ),
            ],
          )
        : const Column(
            children: [
              _AppPriceCard(
                label: 'Home app',
                icon: Icons.home_rounded,
                chipBg: _C.infoSoft,
                chipFg: _C.info,
                price: 'Rs 115',
                caption: 'Home price',
              ),
              SizedBox(height: 16),
              _AppPriceCard(
                label: 'Shop app',
                icon: Icons.storefront_rounded,
                chipBg: _C.priSoft,
                chipFg: _C.priInk,
                price: 'Rs 104',
                caption: 'Shop price',
                bulk: true,
              ),
            ],
          );

    return Container(
      key: _pricesKey,
      padding: EdgeInsets.all(wide ? 56 : 20),
      decoration: BoxDecoration(
        color: _C.deep,
        borderRadius: BorderRadius.circular(32),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 10, child: text),
                const SizedBox(width: 48),
                Expanded(flex: 10, child: cards),
              ],
            )
          : Column(
              children: [
                text,
                const SizedBox(height: 32),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: cards,
                  ),
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // How it works
  // ---------------------------------------------------------------------------

  Widget _how(bool wide, int cols, double inner) {
    const steps = [
      (
        '1',
        'Build your catalogue',
        'Add categories and subcategories, then products with description, MRP, quantity, photos and an optional video.',
      ),
      (
        '2',
        'Set your prices',
        'Give each product a home price and a shop price. Turn on bulk tiers only where buying more should cost less.',
      ),
      (
        '3',
        'Sell and promote',
        'Bill at the counter, receive online orders and push top offers to the app home screen whenever you need a boost.',
      ),
    ];
    final c = wide ? 3 : 1;
    final w = (inner - (c - 1) * 20) / c;

    return Padding(
      key: _howKey,
      padding: EdgeInsets.only(bottom: wide ? 0 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Reveal(
            scroll: _scroll,
            child: _heading(
              'How it works',
              'From catalogue to first order in three steps',
              null,
              wide,
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (var i = 0; i < steps.length; i++)
                SizedBox(
                  width: w,
                  child: _Reveal(
                    scroll: _scroll,
                    delay: Duration(milliseconds: i * 110),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: _C.line, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(steps[i].$1, style: _display(_C.pri, 48)),
                          const SizedBox(height: 14),
                          Text(
                            steps[i].$2,
                            style: _body(_C.ink, 19, w: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            steps[i].$3,
                            style: _body(_C.sub, 14.5, h: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CTA + footer
  // ---------------------------------------------------------------------------

  Widget _cta(bool wide) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready to open the control room?',
          style: _display(Colors.white, wide ? 38 : 25),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in with your admin account to manage products, prices, offers and orders.',
          style: _body(_a(Colors.white, .9), 16.5, h: 1.5),
        ),
      ],
    );
    final button = _WhiteButton(label: 'Admin login', onPressed: _toTopAndOpen);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 56 : 24,
        vertical: wide ? 56 : 32,
      ),
      decoration: BoxDecoration(
        color: _C.pri,
        borderRadius: BorderRadius.circular(32),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 32),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 24), button],
            ),
    );
  }

  Widget _footer(bool wide) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.line)),
      ),
      child: _wrap(
        wide,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 16,
            spacing: 24,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Logo(size: 34),
                  const SizedBox(width: 10),
                  Text('Hoorain', style: _display(_C.ink, 20)),
                ],
              ),
              Text(
                '© 2026 Hoorain. For authorised staff only.',
                style: _body(_C.sub, 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sign-in layer
  // ---------------------------------------------------------------------------

  Widget _loginLayer() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _panel,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(_panel.value);
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeLogin,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: .001 + 12 * t,
                      sigmaY: .001 + 12 * t,
                    ),
                    child: Container(color: _a(_C.deep, .55 * t)),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 40 * (1 - t)),
                        child: Transform.scale(
                          scale: .95 + .05 * t,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: AnimatedBuilder(
                              animation: _shake,
                              child: _signInCard(),
                              builder: (_, c) {
                                final s = _shake.value;
                                final dx =
                                    math.sin(s * math.pi * 5) * 10 * (1 - s);
                                return Transform.translate(
                                  offset: Offset(dx, 0),
                                  child: c,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _signInCard() {
    final narrow = MediaQuery.of(context).size.width < 420;
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 20 : 32, 16, narrow ? 20 : 32, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _a(Colors.black, .25),
            blurRadius: 60,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _Logo(size: 46),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _closeLogin,
                  icon: const Icon(Icons.close_rounded, color: _C.sub),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to your account',
              textAlign: TextAlign.center,
              style: _display(
                const Color(0xFF1B1A1F),
                narrow ? 25 : 29,
                w: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please enter your details to continue.',
              textAlign: TextAlign.center,
              style: _body(_C.sub, 14.5, h: 1.5),
            ),
            const SizedBox(height: 28),
            _AuthField(
              controller: _email,
              focusNode: _emailFocus,
              label: 'Email',
              hint: 'Enter your email',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              // Enter on the email field: go to the password, or log in if
              // the password is already filled.
              onSubmitted: (_) {
                if (_password.text.trim().isEmpty) {
                  _passFocus.requestFocus();
                } else {
                  _submit();
                }
              },
            ),
            const SizedBox(height: 20),
            _AuthField(
              controller: _password,
              focusNode: _passFocus,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: _hide,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              // Enter on the password field starts the login.
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                splashRadius: 20,
                icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: _C.sub,
                ),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            const SizedBox(height: 28),
            Obx(
              () => _GreenButton(
                label: 'Login',
                icon: Icons.arrow_forward_rounded,
                height: 54,
                expand: true,
                loading: _controller.isLoading.value,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 15, color: _C.sub),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Admin access only. Authorised staff only.',
                    textAlign: TextAlign.center,
                    style: _body(_C.sub, 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Scroll reveal
// -----------------------------------------------------------------------------

/// Fades and lifts its child the first time it scrolls into view.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.scroll,
    required this.child,
    this.delay = Duration.zero,
  });

  final ScrollController scroll;
  final Widget child;
  final Duration delay;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_shown || !mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final dy = ro.localToGlobal(Offset.zero).dy;
    final h = MediaQuery.of(context).size.height;
    if (dy < h * .92) {
      _shown = true;
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, c) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 40 * (1 - t)), child: c),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Hero visual: products and prices
// -----------------------------------------------------------------------------

class _ProductsMock extends StatelessWidget {
  const _ProductsMock();

  static const _rows = [
    (
      'Cutter Mirch 200G',
      'Milan Foods · Spices',
      '115',
      '104',
      'assets/landing/cutter_mirch_200g.jpg',
    ),
    (
      'Cutter Mirch 500G',
      'Milan Foods · Spices',
      '285',
      '260',
      'assets/landing/cutter_mirch_500g.jpg',
    ),
    (
      'Dhaniya Powder 100G',
      'Milan Foods · Spices',
      '60',
      '54',
      'assets/landing/dhaniya_powder_100g.jpg',
    ),
  ];

  Widget _price(String v, {bool shop = false}) => SizedBox(
    width: 54,
    child: Text(
      v,
      textAlign: TextAlign.right,
      style: _body(shop ? _C.priInk : _C.ink, 14, w: FontWeight.w800),
    ),
  );

  Widget _priceChip(String label, String v, bool shop) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: shop ? _C.priSoft : _C.bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$label Rs $v',
      style: _body(shop ? _C.priInk : _C.ink, 12, w: FontWeight.w800),
    ),
  );

  Widget _offerCard(IconData? icon, Widget lead, String t1, String t2) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t1, style: _body(_C.ink, 13, w: FontWeight.w700, h: 1.25)),
                Text(t2, style: _body(_C.sub, 12.5, h: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 520;
    final offer = _offerCard(
      null,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _C.acc,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '8% off',
          style: _body(Colors.white, 13.5, w: FontWeight.w800),
        ),
      ),
      'Weekend spice sale',
      'Top offer on app home',
    );
    final bulk = _offerCard(
      null,
      const Icon(Icons.local_offer_outlined, size: 26, color: _C.pri),
      'Bulk price from 5 units',
      'Optional per product',
    );

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 24),
      decoration: BoxDecoration(
        color: _C.priSoft,
        borderRadius: BorderRadius.circular(compact ? 24 : 32),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 14 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _a(_C.ink, .08),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Products and prices',
                        style: _body(_C.ink, 16.5, w: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _C.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Sample view',
                        style: _body(_C.sub, 12, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!compact)
                  Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _C.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Product',
                            style: _body(_C.sub, 12, w: FontWeight.w700),
                          ),
                        ),
                        SizedBox(
                          width: 54,
                          child: Text(
                            'Home',
                            textAlign: TextAlign.right,
                            style: _body(_C.sub, 12, w: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 54,
                          child: Text(
                            'Shop',
                            textAlign: TextAlign.right,
                            style: _body(_C.sub, 12, w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < _rows.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: i == _rows.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: _C.line)),
                    ),
                    child: Row(
                      children: [
                        _ProductImage(
                          asset: _rows[i].$5,
                          width: 46,
                          height: 46,
                          radius: 10,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _rows[i].$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _body(_C.ink, 14, w: FontWeight.w700),
                              ),
                              Text(
                                _rows[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _body(_C.sub, 12),
                              ),
                              if (compact) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _priceChip('Home', _rows[i].$3, false),
                                    _priceChip('Shop', _rows[i].$4, true),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          _price(_rows[i].$3),
                          const SizedBox(width: 12),
                          _price(_rows[i].$4, shop: true),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, box) {
              if (box.maxWidth >= 440) {
                return Row(
                  children: [
                    Expanded(child: offer),
                    const SizedBox(width: 16),
                    Expanded(child: bulk),
                  ],
                );
              }
              return Column(
                children: [offer, const SizedBox(height: 12), bulk],
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared widgets
// -----------------------------------------------------------------------------

class _AppPriceCard extends StatelessWidget {
  const _AppPriceCard({
    required this.label,
    required this.icon,
    required this.chipBg,
    required this.chipFg,
    required this.price,
    required this.caption,
    this.bulk = false,
  });

  final String label;
  final IconData icon;
  final Color chipBg;
  final Color chipFg;
  final String price;
  final String caption;
  final bool bulk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: chipFg),
                const SizedBox(width: 8),
                Text(label, style: _body(chipFg, 13, w: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _ProductImage(
            asset: 'assets/landing/cutter_mirch_200g.jpg',
            width: double.infinity,
            height: 160,
            radius: 14,
            padding: 8,
          ),
          const SizedBox(height: 12),
          Text(
            'Cutter Mirch 200G',
            style: _body(_C.ink, 14.5, w: FontWeight.w700),
          ),
          Text('Milan Foods', style: _body(_C.sub, 12)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: _body(_C.priInk, 22, w: FontWeight.w800)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(caption, style: _body(_C.sub, 12)),
              ),
            ],
          ),
          if (bulk) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _C.priSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Bulk tiers available',
                style: _body(_C.priInk, 12, w: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Hoorain basket logo, drawn in code.
class _Logo extends StatelessWidget {
  const _Logo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _LogoPainter()),
  );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF16A57F), Color(0xFF0B6650)],
      ).createShader(const Rect.fromLTWH(0, 0, 64, 64));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 64, 64),
        const Radius.circular(18),
      ),
      bg,
    );

    final basket = Path()
      ..moveTo(15, 29)
      ..lineTo(49, 29)
      ..lineTo(45.4, 46.2)
      ..quadraticBezierTo(44.8, 49.4, 41.5, 49.4)
      ..lineTo(22.5, 49.4)
      ..quadraticBezierTo(19.2, 49.4, 18.6, 46.2)
      ..close();
    canvas.drawPath(basket, Paint()..color = Colors.white);

    final handle = Path()
      ..moveTo(22, 29)
      ..cubicTo(22, 18, 42, 18, 42, 29);
    canvas.drawPath(
      handle,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );

    final leaf = Path()
      ..moveTo(33, 19)
      ..cubicTo(32.5, 12.5, 37.5, 9, 44, 9.5)
      ..cubicTo(44.5, 16, 40, 20, 33, 19)
      ..close();
    canvas.drawPath(leaf, Paint()..color = const Color(0xFFF4B740));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Primary green button with hover lift, press feedback and a loading state.
class _GreenButton extends StatefulWidget {
  const _GreenButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.fontSize = 16,
    this.expand = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool expand;
  final bool loading;

  @override
  State<_GreenButton> createState() => _GreenButtonState();
}

class _GreenButtonState extends State<_GreenButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;

    final children = widget.loading
        ? const <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Colors.white,
              ),
            ),
          ]
        : <Widget>[
            Text(
              widget.label,
              style: _body(Colors.white, widget.fontSize, w: FontWeight.w800),
            ),
            if (widget.icon != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _hover ? 12 : 8,
              ),
              Icon(widget.icon, size: widget.fontSize + 4, color: Colors.white),
            ],
          ];

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? .98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.expand ? 0 : 24),
            transform: Matrix4.translationValues(
              0,
              _hover && enabled ? -2 : 0,
              0,
            ),
            decoration: BoxDecoration(
              color: _hover && enabled ? _C.priInk : _C.pri,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _a(_C.pri, _hover ? .38 : .24),
                  blurRadius: _hover ? 24 : 16,
                  offset: Offset(0, _hover ? 10 : 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// White button for the green call-to-action band.
class _WhiteButton extends StatefulWidget {
  const _WhiteButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_WhiteButton> createState() => _WhiteButtonState();
}

class _WhiteButtonState extends State<_WhiteButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 30),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: _hover ? _C.priSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: _body(_C.priInk, 16, w: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: _C.priInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? _C.pri : const Color(0xFFC9D6D0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: _body(
                  _hover ? _C.priInk : _C.ink,
                  15.5,
                  w: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: _body(_hover ? _C.pri : _C.ink, 14.5, w: FontWeight.w600),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

/// Card that lifts and lights its border on hover.
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child});
  final Widget child;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hover ? _C.pri : _C.line, width: 1.5),
          boxShadow: [
            if (_hover)
              BoxShadow(
                color: _a(_C.pri, .14),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Product photo from the app's assets, with a soft placeholder if the file
/// is missing.
class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.asset,
    required this.width,
    required this.height,
    required this.radius,
    this.padding = 2,
  });

  final String asset;
  final double width;
  final double height;
  final double radius;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _C.line),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_outlined, color: _C.sub),
      ),
    );
  }
}

/// Text field with the label above, a soft filled surface and a green focus
/// ring. Same layout as the old PrimaryTextField (header, hint, rounded box).
class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  bool _hover = false;

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final border = focused
        ? _C.pri
        : (_hover ? const Color(0xFFA9BBB3) : const Color(0xFFC9D6D0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            widget.label,
            style: _body(
              focused ? _C.priInk : _C.ink,
              13.5,
              w: FontWeight.w700,
            ),
          ),
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: focused ? Colors.white : const Color(0xFFF6F9F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 1.5),
              boxShadow: [
                if (focused)
                  BoxShadow(
                    color: _a(_C.pri, .16),
                    blurRadius: 0,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(widget.icon, size: 20, color: focused ? _C.pri : _C.sub),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: _C.pri,
                    autocorrect: false,
                    enableSuggestions: !widget.obscure,
                    style: _body(_C.ink, 15.5, w: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: _body(const Color(0xFF8DA098), 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 17,
                      ),
                    ),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
                if (widget.suffix == null) const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
