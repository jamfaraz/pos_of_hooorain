import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/controllers/login_controller.dart';

/// Premium landing page with a sign-in popup.
/// - Fixed blurred nav bar, animated hero, scroll-reveal sections.
/// - Sign-in card opens over a blurred backdrop (Esc or tap outside closes).
/// All colours come from Theme.of(context).colorScheme.
Color _a(Color c, double o) => c.withAlpha((o * 255).clamp(0, 255).round());
bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

TextStyle _display(Color c, double size) => GoogleFonts.fraunces(
    color: c,
    fontSize: size,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -size * .03);

TextStyle _body(Color c, double size,
        {FontWeight w = FontWeight.w400, double? h}) =>
    GoogleFonts.plusJakartaSans(
        color: c, fontSize: size, fontWeight: w, height: h);

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
  final GlobalKey _featuresKey = GlobalKey();

  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))
        ..repeat();
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  late final AnimationController _panel = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480));
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  bool _open = false;
  bool _hide = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _scroll.dispose();
    _bg.dispose();
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

  void _fail() {
    HapticFeedback.mediumImpact();
    _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text.trim();
    String? e, p;
    if (email.isEmpty) {
      e = 'Please enter your email';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      e = 'Enter a valid email, like name@hoorain.com';
    }
    if (password.isEmpty) p = 'Please enter your password';
    setState(() {
      _emailError = e;
      _passwordError = p;
    });
    if (e != null || p != null) {
      _fail();
      return;
    }
    FocusScope.of(context).unfocus();
    await _controller.loginAdmin(email: email, password: password);
  }

  void _toFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic);
    }
  }

  void _toTopAndOpen() {
    _scroll.animateTo(0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic);
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
        final t = Interval(start, end, curve: Curves.easeOutCubic)
            .transform(_enter.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: c),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_open) _closeLogin();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bg,
                  builder: (_, __) => CustomPaint(
                    painter: _GlowPainter(
                        t: _bg.value,
                        c1: cs.primary,
                        c2: cs.secondary,
                        c3: cs.tertiary,
                        dark: _dark(context)),
                  ),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(builder: (context, box) {
                  final wide = box.maxWidth >= 900;
                  final topPad = MediaQuery.of(context).padding.top + 72;
                  final inner = math.min<double>(box.maxWidth, 1180.0) -
                      (wide ? 80.0 : 40.0);
                  return SingleChildScrollView(
                    controller: _scroll,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(wide ? 40 : 20,
                              topPad + (wide ? 56 : 28), wide ? 40 : 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              wide ? _heroWide() : _heroNarrow(),
                              SizedBox(height: wide ? 90 : 56),
                              _Reveal(
                                  scroll: _scroll, child: _strip(wide, inner)),
                              SizedBox(height: wide ? 120 : 76),
                              KeyedSubtree(
                                  key: _featuresKey,
                                  child: _features(wide, inner)),
                              SizedBox(height: wide ? 120 : 76),
                              _workflow(wide),
                              SizedBox(height: wide ? 110 : 70),
                              _Reveal(scroll: _scroll, child: _cta(wide)),
                              const SizedBox(height: 56),
                              _footerBar(),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
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
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width >= 900;
    final top = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _scroll,
      builder: (_, __) {
        final off = _scroll.hasClients ? _scroll.offset : 0.0;
        final t = (off / 90).clamp(0.0, 1.0);
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: .001 + 18 * t, sigmaY: .001 + 18 * t),
            child: Container(
              padding: EdgeInsets.only(top: top),
              decoration: BoxDecoration(
                color: _a(cs.surface, .78 * t),
                border: Border(
                    bottom: BorderSide(color: _a(cs.outline, .25 * t))),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20),
                    child: SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          const _Logo(size: 38),
                          const SizedBox(width: 12),
                          Text('Hoorain',
                              style: GoogleFonts.fraunces(
                                  color: cs.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (wide) ...[
                            _NavLink('Features', _toFeatures),
                            const SizedBox(width: 30),
                          ],
                          _PremiumButton(
                              label: 'Sign in',
                              icon: Icons.arrow_forward_rounded,
                              height: 44,
                              fontSize: 14.5,
                              onPressed: _openLogin),
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
        Expanded(flex: 11, child: _heroText(66)),
        const SizedBox(width: 56),
        Expanded(flex: 9, child: _seq(3, _HeroVisual(bg: _bg))),
      ],
    );
  }

  Widget _heroNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroText(40),
        const SizedBox(height: 44),
        _seq(3, _HeroVisual(bg: _bg)),
      ],
    );
  }

  Widget _heroText(double size) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seq(
          0,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: _a(cs.primary, .12),
              border: Border.all(color: _a(cs.primary, .35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PulseDot(color: cs.primary),
              const SizedBox(width: 8),
              Text('Synced live with the Hoorain app',
                  style: _body(cs.primary, 12.5, w: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        _seq(
          1,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The control room', style: _display(cs.onSurface, size)),
            Text('for your shop.',
                style: _display(_a(cs.onSurface, .5), size)),
          ]),
        ),
        const SizedBox(height: 24),
        _seq(
          2,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              'Run the counter, stockroom and deliveries behind the Hoorain app from one secure dashboard. Track sales, approve customers and restock before shelves go empty.',
              style: _body(_a(cs.onSurface, .68), 16.5, h: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 34),
        _seq(
          3,
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _PremiumButton(
                  label: 'Sign in to admin',
                  icon: Icons.arrow_forward_rounded,
                  height: 58,
                  fontSize: 16,
                  onPressed: _openLogin),
              _GhostButton(label: 'Explore features', onPressed: _toFeatures),
            ],
          ),
        ),
        const SizedBox(height: 34),
        _seq(
          4,
          Wrap(spacing: 26, runSpacing: 10, children: [
            _trust(Icons.verified_user_outlined, 'Role-based access'),
            _trust(Icons.sync_rounded, 'Synced with the app'),
            _trust(Icons.devices_rounded, 'Works on any screen'),
          ]),
        ),
      ],
    );
  }

  Widget _trust(IconData i, String t) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(t, style: _body(_a(cs.onSurface, .72), 13.5, w: FontWeight.w500)),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Strip
  // ---------------------------------------------------------------------------

  Widget _strip(bool wide, double inner) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      (Icons.verified_user_outlined, 'Role-based access',
          'Staff see only their screens'),
      (Icons.sync_rounded, 'Live sync', 'Changes reach the app at once'),
      (Icons.devices_rounded, 'Any screen', 'Phone, tablet or desktop'),
      (Icons.print_outlined, 'Receipt ready', '58 mm and 80 mm paper'),
    ];

    Widget cell((IconData, String, String) it) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: _a(cs.primary, .13)),
              child: Icon(it.$1, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.$2,
                      style: _body(cs.onSurface, 14.5, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(it.$3, style: _body(_a(cs.onSurface, .6), 12.5)),
                ],
              ),
            ),
          ],
        );

    return _Glass(
      radius: 24,
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 20, vertical: 22),
      child: wide
          ? Row(children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: cell(items[i])),
                if (i != items.length - 1)
                  Container(
                      width: 1,
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: _a(cs.outline, .3)),
              ],
            ])
          : Column(children: [
              for (var i = 0; i < items.length; i++) ...[
                Align(alignment: Alignment.centerLeft, child: cell(items[i])),
                if (i != items.length - 1) const SizedBox(height: 18),
              ],
            ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Features
  // ---------------------------------------------------------------------------

  Widget _heading(String title, String sub, bool wide) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _display(cs.onSurface, wide ? 44 : 30)),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(sub, style: _body(_a(cs.onSurface, .65), 16, h: 1.55)),
        ),
      ],
    );
  }

  Widget _features(bool wide, double inner) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      (Icons.point_of_sale_rounded, 'Counter billing',
          'Ring up sales, hold bills and print receipts on 58 mm or 80 mm paper.'),
      (Icons.local_shipping_outlined, 'Delivery orders',
          'Move every order from new to delivered and see cash collected.'),
      (Icons.inventory_2_outlined, 'Inventory and suppliers',
          'Add stock, track costs and record what you owe each supplier.'),
      (Icons.people_alt_outlined, 'Customers',
          'Approve requests, add a verified tag or block an account.'),
      (Icons.insights_rounded, 'Reports',
          'Revenue, gross profit, expenses and net profit by day or month.'),
      (Icons.notifications_none_rounded, 'Banners and notifications',
          'Update app banners and send an offer to one user or everyone.'),
    ];
    final cols = wide ? 3 : 1;
    final w = (inner - (cols - 1) * 18) / cols;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Reveal(
          scroll: _scroll,
          child: _heading('Everything your shop does in a day',
              'Each person on your team sees only what their role allows.', wide),
        ),
        const SizedBox(height: 38),
        Wrap(spacing: 18, runSpacing: 18, children: [
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _a(cs.primary, .24),
                              _a(cs.primary, .08),
                            ],
                          ),
                          border: Border.all(color: _a(cs.primary, .25)),
                        ),
                        child: Icon(items[i].$1, color: cs.primary, size: 25),
                      ),
                      const SizedBox(height: 20),
                      Text(items[i].$2,
                          style:
                              _body(cs.onSurface, 17.5, w: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(items[i].$3,
                          style: _body(_a(cs.onSurface, .65), 14.5, h: 1.55)),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Workflow section
  // ---------------------------------------------------------------------------

  Widget _workflow(bool wide) {
    final cs = Theme.of(context).colorScheme;
    const points = [
      'Hold a bill and come back to it later',
      'Print receipts on 58 mm or 80 mm paper',
      'Follow each delivery until the cash is in',
      'Track what you owe every supplier',
    ];

    final text = _Reveal(
      scroll: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('From the counter to the doorstep',
              'One order, one trail. Watch it move from the first tap to the last delivery.', wide),
          const SizedBox(height: 28),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _a(cs.primary, .16)),
                  child: Icon(Icons.check_rounded, size: 15, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(p,
                        style: _body(_a(cs.onSurface, .82), 15.5,
                            w: FontWeight.w500))),
              ]),
            ),
        ],
      ),
    );

    final visual = _Reveal(
      scroll: _scroll,
      delay: const Duration(milliseconds: 150),
      child: _PipelineCard(bg: _bg),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 9, child: text),
          const SizedBox(width: 64),
          Expanded(flex: 10, child: visual),
        ],
      );
    }
    return Column(children: [text, const SizedBox(height: 36), visual]);
  }

  // ---------------------------------------------------------------------------
  // CTA + footer
  // ---------------------------------------------------------------------------

  Widget _cta(bool wide) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: wide ? 56 : 24, vertical: wide ? 60 : 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(cs.primary, Colors.black, .35)!,
              Color.lerp(cs.primary, Colors.black, .72)!,
            ],
          ),
          border: Border.all(color: _a(Colors.white, .14)),
          boxShadow: [
            BoxShadow(
                color: _a(cs.primary, .3),
                blurRadius: 60,
                offset: const Offset(0, 28)),
          ],
        ),
        child: Column(
          children: [
            Text('Ready to open the shop?',
                textAlign: TextAlign.center,
                style: _display(Colors.white, wide ? 42 : 28)),
            const SizedBox(height: 12),
            Text('Sign in with your admin account to continue.',
                textAlign: TextAlign.center,
                style: _body(_a(Colors.white, .72), 16)),
            const SizedBox(height: 30),
            _LightButton(label: 'Sign in', onPressed: _toTopAndOpen),
          ],
        ),
      ),
    );
  }

  Widget _footerBar() {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      const _Logo(size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Text('© 2026 Hoorain. For authorised staff only.',
            style: _body(_a(cs.onSurface, .5), 12.5)),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Sign-in layer
  // ---------------------------------------------------------------------------

  Widget _loginLayer() {
    final cs = Theme.of(context).colorScheme;
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
                    filter:
                        ImageFilter.blur(sigmaX: .001 + 14 * t, sigmaY: .001 + 14 * t),
                    child: Container(
                        color: _a(_dark(context) ? Colors.black : cs.onSurface,
                            .5 * t)),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 24, 20,
                        24 + MediaQuery.of(context).viewInsets.bottom),
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
                                    offset: Offset(dx, 0), child: c);
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
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 30,
      strong: true,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 30),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const _Logo(size: 46),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                onPressed: _closeLogin,
                icon: Icon(Icons.close_rounded, color: _a(cs.onSurface, .6)),
              ),
            ]),
            const SizedBox(height: 20),
            Text('Welcome back',
                style: GoogleFonts.fraunces(
                    color: cs.onSurface,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Sign in to manage sales, stock and deliveries.',
                style: _body(_a(cs.onSurface, .62), 14.5, h: 1.5)),
            const SizedBox(height: 28),
            _AuthField(
              controller: _email,
              label: 'Email address',
              hint: 'name@hoorain.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              error: _emailError,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
            ),
            const SizedBox(height: 18),
            _AuthField(
              controller: _password,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: _hide,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              error: _passwordError,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              suffix: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                splashRadius: 20,
                icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: _a(cs.onSurface, .5)),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            const SizedBox(height: 26),
            Obx(() => _PremiumButton(
                  label: 'Sign in',
                  icon: Icons.arrow_forward_rounded,
                  height: 58,
                  expand: true,
                  loading: _controller.isLoading.value,
                  onPressed: _submit,
                )),
            const SizedBox(height: 22),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_outlined,
                  size: 15, color: _a(cs.onSurface, .45)),
              const SizedBox(width: 7),
              Flexible(
                child: Text('Secure session. Authorised staff only.',
                    textAlign: TextAlign.center,
                    style: _body(_a(cs.onSurface, .5), 12.5)),
              ),
            ]),
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
      vsync: this, duration: const Duration(milliseconds: 750));
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
// Hero visual
// -----------------------------------------------------------------------------

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({required this.bg});
  final AnimationController bg;

  Widget _float(double phase, double amp, Widget child) {
    return AnimatedBuilder(
      animation: bg,
      child: child,
      builder: (_, c) {
        final dy = math.sin(bg.value * math.pi * 2 * 6 + phase) * amp;
        return Transform.translate(offset: Offset(0, dy), child: c);
      },
    );
  }

  Widget _chip(BuildContext context, IconData icon, String title, String sub,
      Color tint) {
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 18,
      strong: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11), color: _a(tint, .16)),
          child: Icon(icon, size: 18, color: tint),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _body(cs.onSurface, 12.5, w: FontWeight.w700)),
            Text(sub, style: _body(_a(cs.onSurface, .6), 11.5)),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _float(0, 5, const _DashPreview()),
          Positioned(
            top: -26,
            right: 14,
            child: _float(
                1.6,
                8,
                _chip(context, Icons.check_circle_outline_rounded,
                    'Order delivered', 'H-1041 · Cash received', cs.primary)),
          ),
          Positioned(
            bottom: -26,
            left: 14,
            child: _float(
                3.2,
                7,
                _chip(context, Icons.notifications_active_outlined,
                    'Low stock alert', 'Basmati rice 5 kg', cs.secondary)),
          ),
        ],
      ),
    );
  }
}

/// Dashboard preview: counting total, growing bars, recent activity.
class _DashPreview extends StatelessWidget {
  const _DashPreview();

  static const _bars = [.38, .52, .44, .66, .58, .74, 1.0];

  String _fmt(int n) => n
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Today’s sales',
                style: _body(_a(cs.onSurface, .65), 13.5, w: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _a(cs.primary, .14)),
              child: Text('▲ 12%',
                  style: _body(cs.primary, 12, w: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 184520),
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('Rs ${_fmt(v.round())}',
                style: GoogleFonts.fraunces(
                    color: cs.onSurface,
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.3)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var k = 0; k < _bars.length; k++) ...[
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _bars[k]),
                      duration: Duration(milliseconds: 900 + k * 130),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => FractionallySizedBox(
                        heightFactor: v.clamp(.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: k == _bars.length - 1
                                ? cs.primary
                                : _a(cs.primary, .28),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (k != _bars.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _row(cs, 'Counter', 'Bill H-1042', 'Rs 3,480', false),
          _row(cs, 'Delivery', 'Order H-1043 · Madina Town', 'Rs 6,150', true),
          _row(cs, 'Low stock', 'Basmati rice 5 kg', '4 left', true),
        ],
      ),
    );
  }

  Widget _row(ColorScheme cs, String tag, String label, String value, bool warm) {
    final tint = warm ? cs.secondary : cs.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _a(cs.onSurface, .045),
        border: Border.all(color: _a(cs.outline, .2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9), color: _a(tint, .16)),
          child: Text(tag, style: _body(tint, 11, w: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: _body(cs.onSurface, 12.5)),
        ),
        const SizedBox(width: 8),
        Text(value, style: _body(cs.onSurface, 12.5, w: FontWeight.w700)),
      ]),
    );
  }
}

/// Order trail card: the active stage keeps moving on its own.
class _PipelineCard extends StatelessWidget {
  const _PipelineCard({required this.bg});
  final AnimationController bg;

  static const _stages = [
    (Icons.receipt_long_rounded, 'New'),
    (Icons.inventory_2_outlined, 'Packed'),
    (Icons.local_shipping_outlined, 'On the way'),
    (Icons.check_circle_outline_rounded, 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 28,
      padding: const EdgeInsets.all(26),
      child: AnimatedBuilder(
        animation: bg,
        builder: (_, __) {
          final step = (bg.value * 14).floor() % 4;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order H-1043',
                          style: _body(cs.onSurface, 16, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Madina Town',
                          style: _body(_a(cs.onSurface, .6), 13)),
                    ],
                  ),
                ),
                Text('Rs 6,150',
                    style: GoogleFonts.fraunces(
                        color: cs.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 26),
              Row(children: [
                for (var i = 0; i < _stages.length; i++)
                  Expanded(
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= step
                              ? cs.primary
                              : _a(cs.onSurface, .06),
                          border: Border.all(
                              color: i <= step
                                  ? _a(Colors.white, .25)
                                  : _a(cs.outline, .35)),
                          boxShadow: [
                            if (i == step)
                              BoxShadow(
                                  color: _a(cs.primary, .45),
                                  blurRadius: 22,
                                  spreadRadius: 1),
                          ],
                        ),
                        child: Icon(_stages[i].$1,
                            size: 21,
                            color: i <= step
                                ? cs.onPrimary
                                : _a(cs.onSurface, .5)),
                      ),
                      const SizedBox(height: 10),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: _body(
                            i <= step ? cs.onSurface : _a(cs.onSurface, .5),
                            12,
                            w: i == step ? FontWeight.w700 : FontWeight.w500),
                        child: Text(_stages[i].$2,
                            textAlign: TextAlign.center, maxLines: 1),
                      ),
                    ]),
                  ),
              ]),
              const SizedBox(height: 24),
              Container(
                height: 7,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _a(cs.onSurface, .08)),
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: (step + 1) / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: [
                        _a(cs.primary, .6),
                        cs.primary,
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _a(cs.onSurface, .045),
                  border: Border.all(color: _a(cs.outline, .2)),
                ),
                child: Row(children: [
                  Icon(Icons.payments_outlined, size: 19, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Cash to collect on delivery',
                        style: _body(_a(cs.onSurface, .75), 13.5,
                            w: FontWeight.w500)),
                  ),
                  Text('Rs 6,150',
                      style: _body(cs.onSurface, 13.5, w: FontWeight.w700)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared widgets
// -----------------------------------------------------------------------------

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14 * _c.value,
              height: 14 * _c.value,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _a(widget.color, .35 * (1 - _c.value))),
            ),
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(cs.primary, Colors.white, .12)!,
            Color.lerp(cs.primary, Colors.black, .3)!,
          ],
        ),
        border: Border.all(color: _a(Colors.white, .25)),
        boxShadow: [
          BoxShadow(
              color: _a(cs.primary, .4),
              blurRadius: size * .55,
              offset: Offset(0, size * .16)),
        ],
      ),
      child: Text('H',
          style: GoogleFonts.fraunces(
              color: cs.onPrimary,
              fontSize: size * .52,
              fontWeight: FontWeight.w600)),
    );
  }
}

/// Primary button: gradient, glow, hover lift, sliding arrow, press feedback,
/// and a built-in loading state.
class _PremiumButton extends StatefulWidget {
  const _PremiumButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
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
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !widget.loading;
    final r = widget.height * .3;

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: widget.loading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: cs.onPrimary))
          : Row(
              key: const ValueKey('label'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label,
                    style: _body(cs.onPrimary, widget.fontSize,
                        w: FontWeight.w700)),
                if (widget.icon != null)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(left: _hover ? 14 : 8),
                    child: Icon(widget.icon,
                        size: widget.fontSize + 4, color: cs.onPrimary),
                  ),
              ],
            ),
    );

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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: widget.height,
            width: widget.expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: widget.expand ? 0 : 26),
            transform:
                Matrix4.translationValues(0, _hover && enabled ? -2 : 0, 0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(cs.primary, Colors.white, .14)!,
                  cs.primary,
                  Color.lerp(cs.primary, Colors.black, .26)!,
                ],
                stops: const [0, .45, 1],
              ),
              border: Border.all(color: _a(Colors.white, .22)),
              boxShadow: [
                BoxShadow(
                    color: _a(cs.primary, _hover ? .5 : .32),
                    blurRadius: _hover ? 36 : 24,
                    offset: Offset(0, _hover ? 15 : 10)),
                BoxShadow(
                    color: _a(Colors.black, .16),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// White button used on the dark call-to-action band.
class _LightButton extends StatefulWidget {
  const _LightButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_LightButton> createState() => _LightButtonState();
}

class _LightButtonState extends State<_LightButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = Color.lerp(cs.primary, Colors.black, .45)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: _a(Colors.black, _hover ? .35 : .22),
                  blurRadius: _hover ? 34 : 22,
                  offset: Offset(0, _hover ? 14 : 10)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: _body(fg, 16, w: FontWeight.w700)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: EdgeInsets.only(left: _hover ? 14 : 8),
              child: Icon(Icons.arrow_forward_rounded, size: 20, color: fg),
            ),
          ]),
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
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: _a(cs.onSurface, _hover ? .09 : .04),
            border: Border.all(color: _a(cs.outline, _hover ? .6 : .38)),
          ),
          child: Text(widget.label,
              style: _body(cs.onSurface, 15.5, w: FontWeight.w600)),
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
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: _body(_hover ? cs.onSurface : _a(cs.onSurface, .65), 14.5,
              w: FontWeight.w600),
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
    final cs = Theme.of(context).colorScheme;
    final dark = _dark(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hover ? -6 : 0, 0),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _a(cs.surface, dark ? .6 : .82),
          border: Border.all(
              color: _hover
                  ? _a(cs.primary, .55)
                  : _a(cs.outline, dark ? .28 : .22)),
          boxShadow: [
            BoxShadow(
                color: _hover
                    ? _a(cs.primary, .2)
                    : _a(Colors.black, dark ? .3 : .07),
                blurRadius: _hover ? 44 : 30,
                offset: Offset(0, _hover ? 24 : 16)),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Frosted surface that takes its colours from the theme.
class _Glass extends StatelessWidget {
  const _Glass(
      {required this.child, this.radius = 24, this.padding, this.strong = false});
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = _dark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color:
                _a(cs.surface, strong ? (dark ? .88 : .94) : (dark ? .55 : .78)),
            border: Border.all(color: _a(cs.outline, dark ? .28 : .22)),
            boxShadow: [
              BoxShadow(
                  color: _a(Colors.black, dark ? .4 : .1),
                  blurRadius: 50,
                  offset: const Offset(0, 26)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Text field with the label above, soft filled surface, animated focus ring
/// and an animated error message.
class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.error,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? error;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  final FocusNode _focus = FocusNode();
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = _dark(context);
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;
    final accent = hasError ? cs.error : cs.primary;

    final borderColor =
        hasError || focused ? accent : _a(cs.outline, _hover ? .7 : .4);
    final fill = focused
        ? _a(cs.surface, dark ? .9 : 1)
        : _a(cs.onSurface, dark ? .06 : .035);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: _body(
                hasError || focused ? accent : _a(cs.onSurface, .78), 13.5,
                w: FontWeight.w600),
            child: Text(widget.label),
          ),
        ),
        MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: fill,
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                if (focused || hasError)
                  BoxShadow(
                      color: _a(accent, .16), blurRadius: 0, spreadRadius: 4),
                if (focused)
                  BoxShadow(
                      color: _a(accent, .12),
                      blurRadius: 22,
                      offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(widget.icon,
                    size: 21,
                    color: hasError
                        ? cs.error
                        : (focused ? cs.primary : _a(cs.onSurface, .45))),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: widget.obscure,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    cursorColor: cs.primary,
                    autocorrect: false,
                    enableSuggestions: !widget.obscure,
                    style: _body(cs.onSurface, 15.5, w: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: _body(_a(cs.onSurface, .35), 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 19),
                    ),
                  ),
                ),
                if (widget.suffix != null) widget.suffix!,
                if (widget.suffix == null) const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.error_outline_rounded,
                            size: 15, color: cs.error),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(widget.error!,
                            style: _body(cs.error, 12.5, h: 1.35)),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Soft, slow-moving theme-coloured glows behind the page.
class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.t,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.dark,
  });

  final double t;
  final Color c1, c2, c3;
  final bool dark;

  void _blob(Canvas c, Offset o, double r, Color col, double op) {
    final p = Paint()
      ..shader = RadialGradient(colors: [_a(col, op), _a(col, 0)])
          .createShader(Rect.fromCircle(center: o, radius: r));
    c.drawCircle(o, r, p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * math.pi * 2;
    final m = math.max(size.width, size.height);
    final k = dark ? 1.0 : .42;
    _blob(
        canvas,
        Offset(size.width * (.12 + .08 * math.sin(a)),
            size.height * (.08 + .06 * math.cos(a))),
        m * .55,
        c1,
        .5 * k);
    _blob(
        canvas,
        Offset(size.width * (.92 + .05 * math.cos(a)),
            size.height * (.55 + .08 * math.sin(a))),
        m * .4,
        c2,
        .22 * k);
    _blob(
        canvas,
        Offset(size.width * (.7 + .06 * math.sin(a + 2)),
            size.height * (.02 + .06 * math.cos(a + 1))),
        m * .35,
        c3,
        .2 * k);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.t != t || old.c1 != c1 || old.dark != dark;
}