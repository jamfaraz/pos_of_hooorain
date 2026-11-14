import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hoorain_pos/controllers/login_controller.dart';

/// Landing page first. The sign-in form appears only after the user taps
/// "Sign in". All colours come from Theme.of(context).colorScheme.
Color _a(Color c, double o) => c.withAlpha((o * 255).round());
bool _dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

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
      AnimationController(vsync: this, duration: const Duration(seconds: 30))
        ..repeat();
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
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

  void _forgot() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = 'Enter your email first, then tap Forgot password');
      _fail();
      return;
    }
    _controller.forgotPassword(email);
  }

  void _toFeatures() {
    final ctx = _featuresKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    }
  }

  Widget _seq(int i, Widget child) {
    final start = (0.06 + i * 0.08).clamp(0.0, 0.75);
    final end = (start + 0.4).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _enter,
      child: child,
      builder: (_, c) {
        final t = Interval(start, end, curve: Curves.easeOutCubic)
            .transform(_enter.value);
        return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 22 * (1 - t)), child: c));
      },
    );
  }

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
              SafeArea(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: LayoutBuilder(builder: (context, box) {
                        final wide = box.maxWidth >= 900;
                        return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: wide ? 40 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _seq(0, _nav(wide)),
                              SizedBox(height: wide ? 72 : 40),
                              wide ? _heroWide() : _heroNarrow(),
                              SizedBox(height: wide ? 120 : 72),
                              KeyedSubtree(
                                  key: _featuresKey, child: _features(wide, box.maxWidth)),
                              SizedBox(height: wide ? 90 : 56),
                              _cta(wide),
                              const SizedBox(height: 40),
                              _footerBar(),
                              const SizedBox(height: 28),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              if (_open) _loginLayer(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- landing ----------

  Widget _nav(bool wide) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 84,
      child: Row(
        children: [
          _logo(38, 21),
          const SizedBox(width: 12),
          Text('Hoorain',
              style: GoogleFonts.fraunces(
                  color: cs.onSurface, fontSize: 24, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (wide) ...[
            _NavLink('Features', _toFeatures),
            const SizedBox(width: 28),
          ],
          _PremiumButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              height: 46,
              fontSize: 14.5,
              onPressed: _openLogin),
        ],
      ),
    );
  }

  Widget _heroWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 11, child: _heroText(66, true)),
        const SizedBox(width: 56),
        Expanded(flex: 9, child: _seq(3, const _DashPreview())),
      ],
    );
  }

  Widget _heroNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroText(40, false),
        const SizedBox(height: 40),
        _seq(3, const _DashPreview()),
      ],
    );
  }

  Widget _heroText(double size, bool wide) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seq(
          1,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The control room',
                style: _display(cs.onSurface, size)),
            Text('for your shop.',
                style: _display(_a(cs.onSurface, .5), size)),
          ]),
        ),
        const SizedBox(height: 22),
        _seq(
          2,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              'Run the counter, stockroom and deliveries behind the Hoorain app from one secure dashboard. Track sales, approve customers and restock before shelves go empty.',
              style: GoogleFonts.plusJakartaSans(
                  color: _a(cs.onSurface, .68), fontSize: 16.5, height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 34),
        _seq(
          2,
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
          3,
          Wrap(spacing: 26, runSpacing: 10, children: [
            _trust(Icons.verified_user_outlined, 'Role-based access'),
            _trust(Icons.sync_rounded, 'Synced with the app'),
            _trust(Icons.devices_rounded, 'Works on any screen'),
          ]),
        ),
      ],
    );
  }

  TextStyle _display(Color c, double size) => GoogleFonts.fraunces(
      color: c,
      fontSize: size,
      height: 1.04,
      fontWeight: FontWeight.w600,
      letterSpacing: -size * .032);

  Widget _trust(IconData i, String t) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 18, color: cs.primary),
      const SizedBox(width: 8),
      Text(t,
          style: GoogleFonts.plusJakartaSans(
              color: _a(cs.onSurface, .72),
              fontSize: 13.5,
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _features(bool wide, double maxW) {
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
    final inner = math.min(maxW, 1180) - (wide ? 80 : 40);
    final cols = wide ? 3 : 1;
    final w = (inner - (cols - 1) * 18) / cols;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Everything your shop does in a day',
            style: _display(cs.onSurface, wide ? 42 : 30)),
        const SizedBox(height: 12),
        Text('Each person on your team sees only what their role allows.',
            style: GoogleFonts.plusJakartaSans(
                color: _a(cs.onSurface, .65), fontSize: 16)),
        const SizedBox(height: 34),
        Wrap(spacing: 18, runSpacing: 18, children: [
          for (final it in items)
            SizedBox(
              width: w,
              child: _Glass(
                radius: 22,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: _a(cs.primary, .14)),
                      child: Icon(it.$1, color: cs.primary, size: 24),
                    ),
                    const SizedBox(height: 18),
                    Text(it.$2,
                        style: GoogleFonts.plusJakartaSans(
                            color: cs.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(it.$3,
                        style: GoogleFonts.plusJakartaSans(
                            color: _a(cs.onSurface, .65),
                            fontSize: 14,
                            height: 1.55)),
                  ],
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _cta(bool wide) {
    final cs = Theme.of(context).colorScheme;
    return _Glass(
      radius: 28,
      padding: EdgeInsets.symmetric(horizontal: wide ? 56 : 24, vertical: wide ? 52 : 36),
      child: Column(
        children: [
          Text('Ready to open the shop?',
              textAlign: TextAlign.center, style: _display(cs.onSurface, wide ? 38 : 28)),
          const SizedBox(height: 10),
          Text('Sign in with your admin account to continue.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: _a(cs.onSurface, .65), fontSize: 15.5)),
          const SizedBox(height: 26),
          _PremiumButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              height: 56,
              onPressed: () {
                _scroll.animateTo(0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic);
                _openLogin();
              }),
        ],
      ),
    );
  }

  Widget _footerBar() {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: Text('© 2026 Hoorain. For authorised staff only.',
            style: GoogleFonts.plusJakartaSans(
                color: _a(cs.onSurface, .45), fontSize: 12.5)),
      ),
    ]);
  }

  Widget _logo(double size, double font) {
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
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, .3)!],
        ),
        boxShadow: [
          BoxShadow(
              color: _a(cs.primary, .35),
              blurRadius: size * .5,
              offset: Offset(0, size * .15)),
        ],
      ),
      child: Text('H',
          style: GoogleFonts.fraunces(
              color: cs.onPrimary, fontSize: font, fontWeight: FontWeight.w600)),
    );
  }

  // ---------- sign-in layer (appears after tapping Sign in) ----------

  Widget _loginLayer() {
    final cs = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _panel,
        builder: (_, __) {
          final t = Curves.easeOutCubic.transform(_panel.value);
          return Stack(
            children: [
              // blurred, dimmed backdrop; tap to close
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _closeLogin,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
                    child: Container(
                        color: _a(_dark(context) ? Colors.black : cs.onSurface,
                            .5 * t)),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, 24, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
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
      radius: 28,
      strong: true,
      padding: const EdgeInsets.fromLTRB(30, 26, 30, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _logo(44, 24),
            const Spacer(),
            IconButton(
              tooltip: 'Close',
              onPressed: _closeLogin,
              icon: Icon(Icons.close_rounded, color: _a(cs.onSurface, .6)),
            ),
          ]),
          const SizedBox(height: 18),
          Text('Sign in to your account',
              style: GoogleFonts.fraunces(
                  color: cs.onSurface,
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8)),
          const SizedBox(height: 8),
          Text('Please enter your details to continue.',
              style: GoogleFonts.plusJakartaSans(
                  color: _a(cs.onSurface, .65), fontSize: 14.5)),
          const SizedBox(height: 28),
          _AuthField(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            error: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: 16),
          _AuthField(
            controller: _password,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _hide,
            textInputAction: TextInputAction.done,
            error: _passwordError,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_passwordError != null) setState(() => _passwordError = null);
            },
            suffix: IconButton(
              tooltip: _hide ? 'Show password' : 'Hide password',
              icon: Icon(
                  _hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: _a(cs.onSurface, .5)),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgot,
              style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Text('Forgot password?',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          Obx(() => _PremiumButton(
                label: 'Login',
                height: 56,
                expand: true,
                loading: _controller.isLoading.value,
                onPressed: _submit,
              )),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline_rounded,
                size: 14, color: _a(cs.onSurface, .45)),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Secure admin session · Authorised staff only',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      color: _a(cs.onSurface, .5), fontSize: 12.5)),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Premium primary button: layered gradient, top highlight, glow, hover lift,
/// sliding arrow, press feedback and a built-in loading state.
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

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: widget.loading
              ? SizedBox(
                  key: const ValueKey('s'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.6, color: cs.onPrimary))
              : Row(
                  key: const ValueKey('t'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.label,
                        style: GoogleFonts.plusJakartaSans(
                            color: cs.onPrimary,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .1)),
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
        ),
      ],
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
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.expand ? 0 : 28),
            transform: Matrix4.translationValues(0, _hover && enabled ? -2 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(cs.primary, Colors.white, .14)!,
                  cs.primary,
                  Color.lerp(cs.primary, Colors.black, .28)!,
                ],
                stops: const [0, .45, 1],
              ),
              border: Border.all(color: _a(Colors.white, .22), width: 1),
              boxShadow: [
                BoxShadow(
                    color: _a(cs.primary, _hover ? .5 : .32),
                    blurRadius: _hover ? 38 : 26,
                    offset: Offset(0, _hover ? 16 : 12)),
                BoxShadow(
                    color: _a(Colors.black, .18),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: content,
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
              style: GoogleFonts.plusJakartaSans(
                  color: cs.onSurface, fontSize: 15.5, fontWeight: FontWeight.w600)),
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
          style: GoogleFonts.plusJakartaSans(
              color: _hover ? cs.onSurface : _a(cs.onSurface, .65),
              fontSize: 14.5,
              fontWeight: FontWeight.w600),
          child: Text(widget.label),
        ),
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
            color: _a(cs.surface, strong ? (dark ? .88 : .94) : (dark ? .55 : .78)),
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

/// Clean dashboard preview: counting total, growing bars, recent activity.
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
      radius: 26,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Today’s sales',
                style: GoogleFonts.plusJakartaSans(
                    color: _a(cs.onSurface, .65),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _a(cs.primary, .14)),
              child: Text('▲ 12%',
                  style: GoogleFonts.plusJakartaSans(
                      color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 184520),
            duration: const Duration(milliseconds: 1800),
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
                      duration: Duration(milliseconds: 900 + k * 120),
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
          child: Text(tag,
              style: GoogleFonts.plusJakartaSans(
                  color: tint, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  color: cs.onSurface, fontSize: 12.5)),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: GoogleFonts.plusJakartaSans(
                color: cs.onSurface, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Text field with a floating label, focus ring and animated error message.
class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.error,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? error;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  final FocusNode _focus = FocusNode();

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
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;
    final accent = hasError ? cs.error : cs.primary;
    final border = hasError || focused ? accent : _a(cs.outline, .45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: _a(cs.onSurface, focused ? .07 : .04),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              if (focused || hasError)
                BoxShadow(color: _a(accent, .18), blurRadius: 0, spreadRadius: 4),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            cursorColor: cs.primary,
            autocorrect: false,
            enableSuggestions: !widget.obscure,
            style: GoogleFonts.plusJakartaSans(color: cs.onSurface, fontSize: 15.5),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: GoogleFonts.plusJakartaSans(
                  color: _a(cs.onSurface, .5), fontSize: 15),
              floatingLabelStyle: GoogleFonts.plusJakartaSans(
                  color: accent, fontSize: 13, fontWeight: FontWeight.w600),
              prefixIcon: Icon(widget.icon,
                  size: 20, color: focused ? cs.primary : _a(cs.onSurface, .5)),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
                  child: Text(widget.error!,
                      style: GoogleFonts.plusJakartaSans(
                          color: cs.error, fontSize: 12.5)),
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
            size.height * (.7 + .08 * math.sin(a))),
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