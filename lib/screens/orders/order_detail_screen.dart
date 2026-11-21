import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../controllers/common_controller.dart';
import '../../controllers/order_actions_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../utils/toas_message.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/full_image.dart';
import '../../widgets/loading_placeholder.dart';
import '../../widgets/primary_textfield.dart'; // CommonDropdown
import '../../widgets/retry_widget.dart';
import '../users/user_detail_screen.dart';
import 'bill_viewer_screen.dart';

/// Normal lifecycle shown in the progress timeline.
const List<String> _kStatusFlow = ['Pending', 'Accepted', 'Delivered'];

/// Statuses after which nothing more can be done to an order.
const Set<String> _kClosed = {'cancelled', 'rejected', 'returned'};

// ============================================================================
// Theme-driven palette (no hard-coded brand colours)
// ============================================================================

class _P {
  _P(BuildContext context) : theme = Theme.of(context);

  final ThemeData theme;
  ColorScheme get cs => theme.colorScheme;
  Color get ink => cs.onSurface;
  Color get muted =>
      theme.inputDecorationTheme.labelStyle?.color ?? cs.onSurfaceVariant;
  Color get line => theme.dividerColor;
  Color get soft => theme.inputDecorationTheme.fillColor ?? cs.surfaceContainerLow;
  Color get surface => cs.surface;
  Color get primary => cs.primary;
  Color get error => cs.error;
  Color get hero1 => Color.lerp(cs.primary, Colors.black, 0.6)!;
  Color get hero2 => Color.lerp(cs.primary, Colors.black, 0.84)!;

  TextStyle t(
    double size, {
    FontWeight w = FontWeight.w500,
    Color? c,
    double? h,
    double? ls,
  }) => TextStyle(
    fontSize: size,
    fontWeight: w,
    color: c ?? ink,
    height: h,
    letterSpacing: ls,
  );
}

String _rs(double v) => 'Rs. ${v.toStringAsFixed(1)}';

Color _statusColor(BuildContext context, String status) {
  final cs = Theme.of(context).colorScheme;
  switch (status.toLowerCase()) {
    case 'pending':
      return AppColors.warning;
    case 'accepted':
      return AppColors.info;
    case 'delivered':
      return AppColors.ok;
    case 'returned':
      return cs.secondary;
    case 'cancelled':
    case 'rejected':
      return cs.error;
    default:
      return cs.primary;
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return PhosphorIconsRegular.clock;
    case 'accepted':
      return PhosphorIconsRegular.package;
    case 'delivered':
      return PhosphorIconsRegular.checkCircle;
    case 'returned':
      return PhosphorIconsRegular.arrowCounterClockwise;
    case 'rejected':
      return PhosphorIconsRegular.prohibit;
    case 'cancelled':
      return PhosphorIconsRegular.xCircle;
    default:
      return PhosphorIconsRegular.info;
  }
}

String _statusMessage(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Waiting for your review. Accept it or reject it.';
    case 'accepted':
      return 'Accepted and being prepared for delivery.';
    case 'delivered':
      return 'Delivered to the customer.';
    case 'returned':
      return 'The customer returned this order.';
    case 'rejected':
      return 'You declined this order. The customer was notified.';
    case 'cancelled':
      return 'This order was cancelled.';
    default:
      return 'Order status: $status';
  }
}

String _formatDateTime(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}, ${date.year} at '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

// ============================================================================
// Screen: listens to the order live so status changes appear instantly
// ============================================================================

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderController _orders = Get.put(OrderController());
  late final UsersController _users = Get.put(UsersController());
  Stream<OrderModel?>? _stream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _users.fetchUserById(widget.order.userId);
    });
    if (widget.order.id.isNotEmpty) {
      _stream = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.order.id)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) return null;
            return OrderModel.fromMap(data, snapshot.id);
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OrderModel?>(
      initialData: widget.order,
      stream: _stream,
      builder: (context, snapshot) => _OrderView(
        order: snapshot.data ?? widget.order,
        orders: _orders,
        users: _users,
      ),
    );
  }
}

// ============================================================================
// View
// ============================================================================

class _OrderView extends StatelessWidget {
  const _OrderView({
    required this.order,
    required this.orders,
    required this.users,
  });

  final OrderModel order;
  final OrderController orders;
  final UsersController users;

  bool get _isClosed => _kClosed.contains(order.status.toLowerCase());
  bool get _hasReason => (order.statusReason ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final wide = w >= 1180;
        final narrow = w < 560;
        const gap = SizedBox(height: 18);

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeline(context),
            if (_hasReason) ...[gap, _reasonCard(context)],
            gap,
            _itemsCard(context),
            gap,
            _deliveryCard(context),
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              gap,
              _noteCard(context),
            ],
            if (order.billImageUrl?.isNotEmpty == true) ...[
              gap,
              _billCard(context),
            ],
          ],
        );

        final Widget side = wide
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actionsCard(context),
                  gap,
                  _summaryCard(context),
                  gap,
                  _customerCard(context),
                  gap,
                  _riderCard(context),
                ],
              )
            : w >= 760
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _actionsCard(context),
                        gap,
                        _summaryCard(context),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      children: [
                        _customerCard(context),
                        gap,
                        _riderCard(context),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _actionsCard(context),
                  gap,
                  _summaryCard(context),
                  gap,
                  _customerCard(context),
                  gap,
                  _riderCard(context),
                ],
              );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(narrow ? 0 : 4, 4, narrow ? 0 : 4, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, w),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: main),
                        const SizedBox(width: 22),
                        SizedBox(width: 390, child: side),
                      ],
                    )
                  else ...[
                    main,
                    const SizedBox(height: 18),
                    side,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------
  // Header (light card, matches the sidebar / control-room look)
  // --------------------------------------------------------------------

  Widget _header(BuildContext context, double w) {
    final p = _P(context);
    final narrow = w < 560;
    final statusColor = _statusColor(context, order.status);
    final displayId = '#${order.orderId ?? order.id}';
    final forward = _forwardAction(context);

    final backBtn = _Hover(
      onTap: () => Get.back(),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: h ? p.cs.primaryContainer : p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: h ? Colors.transparent : p.line),
        ),
        child: Icon(
          PhosphorIconsRegular.arrowLeft,
          size: 20,
          color: h ? p.cs.onPrimaryContainer : p.ink,
        ),
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDERS  ›  ORDER DETAILS',
          style: p.t(10.5, w: FontWeight.w700, c: p.muted, ls: 1.3),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Order $displayId',
              style: p.t(narrow ? 21 : 28, w: FontWeight.w800, ls: -0.5),
            ),
            _statusPill(p, order.status, statusColor),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: p.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Placed on ${_formatDateTime(order.orderDate)}',
                style: p.t(12.5, c: p.muted),
              ),
            ),
          ],
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ghostButton(
          icon: PhosphorIconsRegular.copy,
          label: 'Copy ID',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: '${order.orderId ?? order.id}'),
            );
            MessageToast.showToast(msg: 'Order ID copied');
          },
        ),
        if (forward != null) forward,
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(narrow ? 16 : 24),
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backBtn,
              SizedBox(width: narrow ? 12 : 18),
              Expanded(child: titleBlock),
              if (w >= 900) ...[const SizedBox(width: 20), actions],
            ],
          ),
          if (w < 900) ...[const SizedBox(height: 16), actions],
          SizedBox(height: narrow ? 16 : 22),
          _heroStats(p, narrow),
        ],
      ),
    );
  }

  Widget _heroStats(_P p, bool narrow) {
    final stats = [
      (PhosphorIconsRegular.wallet, 'Grand total', _rs(order.total), true),
      (PhosphorIconsRegular.package, 'Items', '${order.items.length}', false),
      (
        PhosphorIconsRegular.creditCard,
        'Payment',
        order.paymentMethod.isEmpty ? '—' : order.paymentMethod,
        false,
      ),
      (
        PhosphorIconsRegular.user,
        'Customer',
        order.userName.isEmpty ? '—' : order.userName,
        false,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 760 ? 4 : 2;
        const gap = 12.0;
        final itemW = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats)
              SizedBox(
                width: itemW,
                child: _statTile(p, s.$1, s.$2, s.$3, hero: s.$4, narrow: narrow),
              ),
          ],
        );
      },
    );
  }

  Widget _statTile(
    _P p,
    IconData icon,
    String label,
    String value, {
    required bool hero,
    required bool narrow,
  }) {
    final bg = hero ? p.cs.primaryContainer : p.soft;
    final fg = hero ? p.cs.onPrimaryContainer : p.ink;
    final sub = hero ? p.cs.onPrimaryContainer.withValues(alpha: 0.7) : p.muted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 14, vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hero ? Colors.transparent : p.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: hero ? Colors.white.withValues(alpha: 0.55) : p.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: hero ? fg : p.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: p.t(9.5, w: FontWeight.w800, c: sub, ls: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.t(hero ? 16 : 13.5, w: FontWeight.w800, c: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(_P p, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.toUpperCase(),
            style: p.t(11, w: FontWeight.w800, c: color, ls: 1),
          ),
        ],
      ),
    );
  }

  Widget _ghostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    Color? fill,
  }) {
    return Builder(
      builder: (context) {
        final p = _P(context);
        final bg = filled ? (fill ?? p.primary) : p.surface;
        final fg = filled ? p.cs.onPrimary : p.ink;
        return _Hover(
          onTap: onTap,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(0, h && filled ? -1.5 : 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: filled
                  ? bg
                  : (h ? p.cs.primaryContainer : p.surface),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled
                    ? Colors.transparent
                    : (h ? Colors.transparent : p.line),
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: bg.withValues(alpha: h ? 0.4 : 0.25),
                        blurRadius: h ? 20 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: (!filled && h) ? p.cs.onPrimaryContainer : fg,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: (!filled && h) ? p.cs.onPrimaryContainer : fg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The single "next step" button shown in the header.
  Widget? _forwardAction(BuildContext context) {
    switch (order.status.toLowerCase()) {
      case 'pending':
        return _ghostButton(
          icon: PhosphorIconsBold.check,
          label: 'Accept order',
          filled: true,
          onTap: () => _accept(context),
        );
      case 'accepted':
        return _ghostButton(
          icon: PhosphorIconsBold.checkCircle,
          label: 'Mark delivered',
          filled: true,
          onTap: () => _deliver(context),
        );
      case 'delivered':
        return _ghostButton(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: 'Process return',
          onTap: () => _returnOrder(context),
        );
      default:
        return null;
    }
  }

  // --------------------------------------------------------------------
  // Timeline (adapts to rejected / cancelled / returned)
  // --------------------------------------------------------------------

  Widget _timeline(BuildContext context) {
    final p = _P(context);
    final s = order.status.toLowerCase();
    late final List<String> labels;
    late int current;
    switch (s) {
      case 'rejected':
        labels = ['Pending', 'Rejected'];
        current = 1;
      case 'cancelled':
        labels = ['Pending', 'Cancelled'];
        current = 1;
      case 'returned':
        labels = ['Pending', 'Accepted', 'Delivered', 'Returned'];
        current = 3;
      default:
        labels = _kStatusFlow;
        current = math.max(0, _kStatusFlow.indexOf(order.status));
    }
    final negative = _kClosed.contains(s);
    final currentColor = _statusColor(context, order.status);
    final n = labels.length;

    return _card(
      context,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            PhosphorIconsRegular.path,
            'Order progress',
            trailing: Text(
              _statusMessage(order.status),
              textAlign: TextAlign.right,
              style: p.t(12, c: p.muted),
            ),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, box) {
              final tw = box.maxWidth;
              final inset = tw / (2 * n);
              final lineW = math.max(0.0, tw - 2 * inset);
              final frac = n <= 1 ? 0.0 : current / (n - 1);
              return Stack(
                children: [
                  Positioned(
                    left: inset,
                    right: inset,
                    top: 19,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: p.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Positioned(
                    left: inset,
                    top: 19,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      width: lineW * frac,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(
                          colors: [
                            p.primary,
                            negative ? currentColor : p.primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _step(
                            context,
                            label: labels[i],
                            index: i,
                            current: current,
                            negativeEnd: negative,
                            currentColor: currentColor,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required String label,
    required int index,
    required int current,
    required bool negativeEnd,
    required Color currentColor,
  }) {
    final p = _P(context);
    final isCurrent = index == current;
    final done = index < current;
    final deliveredFinal = isCurrent && label == 'Delivered';
    final terminal = isCurrent && negativeEnd;

    Color fill;
    Color border;
    Color iconColor;
    if (done || deliveredFinal) {
      fill = deliveredFinal ? currentColor : p.primary;
      border = fill;
      iconColor = Colors.white;
    } else if (terminal) {
      fill = currentColor;
      border = currentColor;
      iconColor = Colors.white;
    } else if (isCurrent) {
      fill = currentColor.withValues(alpha: 0.12);
      border = currentColor;
      iconColor = currentColor;
    } else {
      fill = p.soft;
      border = p.line;
      iconColor = p.muted;
    }

    final caption = done
        ? 'Completed'
        : deliveredFinal
        ? 'Completed'
        : terminal
        ? label
        : isCurrent
        ? 'Current'
        : 'Upcoming';

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.surface,
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 2),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done ? PhosphorIconsBold.check : _statusIcon(label),
              size: 18,
              color: iconColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: p.t(
            12.5,
            w: isCurrent ? FontWeight.w800 : FontWeight.w600,
            c: (done || isCurrent) ? p.ink : p.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: p.t(
            11,
            c: isCurrent ? currentColor : p.muted,
            w: isCurrent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // Reason + notes
  // --------------------------------------------------------------------

  Widget _reasonCard(BuildContext context) {
    final p = _P(context);
    final color = _statusColor(context, order.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(order.status), size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REASON · ${order.status.toUpperCase()}',
                  style: p.t(10.5, w: FontWeight.w800, c: color, ls: 1.1),
                ),
                const SizedBox(height: 5),
                Text(
                  order.statusReason!.trim(),
                  style: p.t(14, w: FontWeight.w600, h: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(BuildContext context) {
    final p = _P(context);
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            PhosphorIconsRegular.notePencil,
            'Customer note',
          ),
          const SizedBox(height: 14),
          Text(order.notes!.trim(), style: p.t(13.5, c: p.muted, h: 1.55)),
        ],
      ),
    );
  }


  Widget _itemsCard(BuildContext context) => _ItemsCard(items: order.items);

  // --------------------------------------------------------------------
  // Delivery + bill
  // --------------------------------------------------------------------

  Widget _deliveryCard(BuildContext context) {
    final p = _P(context);
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            PhosphorIconsRegular.truck,
            'Delivery information',
          ),
          const SizedBox(height: 18),
          _Hover(
            onTap: () => CommonController.openMapsByCoordinates(
              order.location.latitude,
              order.location.longitude,
            ),
            builder: (hovering) => AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: hovering ? 0.1 : 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: p.primary.withValues(alpha: hovering ? 0.4 : 0.2),
                ),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsFill.mapPin,
                          size: 21,
                          color: p.primary,
                        ),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 160,
                      maxWidth: 560,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVERY ADDRESS',
                          style: p.t(
                            10,
                            w: FontWeight.w800,
                            c: p.muted,
                            ls: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.deliveryAddress.isEmpty
                              ? 'No address provided'
                              : order.deliveryAddress,
                          style: p.t(13.5, w: FontWeight.w700, h: 1.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: p.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsBold.navigationArrow,
                          size: 14,
                          color: p.cs.onPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Open in Maps',
                          style: p.t(
                            11.5,
                            w: FontWeight.w800,
                            c: p.cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final two = box.maxWidth >= 520;
              final w = two ? (box.maxWidth - 12) / 2 : box.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: w,
                    child: _metaTile(
                      p,
                      PhosphorIconsRegular.calendarBlank,
                      'Order date',
                      _formatDateTime(order.orderDate),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _metaTile(
                      p,
                      PhosphorIconsRegular.creditCard,
                      'Payment method',
                      order.paymentMethod.isEmpty ? '—' : order.paymentMethod,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metaTile(_P p, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: p.t(10, w: FontWeight.w800, c: p.muted, ls: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.t(13, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billCard(BuildContext context) {
    final p = _P(context);
    final billUrl = order.billImageUrl!;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, PhosphorIconsRegular.receipt, 'Bill image'),
          const SizedBox(height: 16),
          _Hover(
            onTap: () => Get.to(
              () =>
                  BillViewScreen(billImageUrl: billUrl, orderId: order.orderId),
            ),
            builder: (hovering) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: p.soft,
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 260),
                      scale: hovering ? 1.03 : 1,
                      child: Image.network(
                        billUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return LoadingPlaceholder.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(color: p.surface),
                          );
                        },
                        errorBuilder: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 34,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: Colors.black.withValues(alpha: hovering ? 0.3 : 0),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              PhosphorIconsBold.magnifyingGlassPlus,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'View full bill',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Side: actions
  // --------------------------------------------------------------------

  Widget _actionsCard(BuildContext context) {
    final p = _P(context);
    final status = order.status.toLowerCase();
    final children = <Widget>[];

    switch (status) {
      case 'pending':
        children
          ..add(
            _actionTile(
              context,
              icon: PhosphorIconsBold.check,
              title: 'Accept order',
              subtitle: 'Move it into fulfilment. The customer is notified.',
              color: p.primary,
              filled: true,
              onTap: () => _accept(context),
            ),
          )
          ..add(const SizedBox(height: 10))
          ..add(
            _actionTile(
              context,
              icon: PhosphorIconsRegular.prohibit,
              title: 'Reject order',
              subtitle: 'Decline it. Stock is restored and the customer is told.',
              color: p.error,
              onTap: () => _rejectOrder(context),
            ),
          );
      case 'accepted':
        children
          ..add(
            _actionTile(
              context,
              icon: PhosphorIconsBold.checkCircle,
              title: 'Mark as delivered',
              subtitle: 'Confirm the order reached the customer.',
              color: p.primary,
              filled: true,
              onTap: () => _deliver(context),
            ),
          )
          ..add(const SizedBox(height: 10))
          ..add(
            _actionTile(
              context,
              icon: PhosphorIconsRegular.xCircle,
              title: 'Cancel order',
              subtitle: 'Stop this order. Stock is restored.',
              color: p.error,
              onTap: () => _cancelOrder(context),
            ),
          );
      case 'delivered':
        children.add(
          _actionTile(
            context,
            icon: PhosphorIconsRegular.arrowCounterClockwise,
            title: 'Process a return',
            subtitle: 'The customer sent items back. Choose to restock or not.',
            color: p.cs.secondary,
            onTap: () => _returnOrder(context),
          ),
        );
      default:
        final color = _statusColor(context, order.status);
        children.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(order.status), size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${order.status.toLowerCase()}',
                        style: p.t(13.5, w: FontWeight.w800, c: color),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This order is closed, so there are no more actions.',
                        style: p.t(12, c: p.muted, h: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, PhosphorIconsRegular.lightning, 'Order actions'),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final p = _P(context);
    final onColor = filled ? p.cs.onPrimary : color;
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, hovering ? -1.5 : 0, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled
              ? color
              : color.withValues(alpha: hovering ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? color : color.withValues(alpha: hovering ? 0.5 : 0.28),
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: hovering ? 0.4 : 0.25),
                    blurRadius: hovering ? 20 : 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: filled
                    ? Colors.white.withValues(alpha: 0.18)
                    : color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: onColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: p.t(13.5, w: FontWeight.w800, c: onColor)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: p.t(
                      11.5,
                      c: filled ? onColor.withValues(alpha: 0.8) : p.muted,
                      h: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: onColor.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Side: summary / customer / rider
  // --------------------------------------------------------------------

  Widget _summaryCard(BuildContext context) {
    final p = _P(context);
    final onPc = p.cs.onPrimaryContainer;
    Widget row(String label, double amount, {bool negative = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: p.t(13, c: p.muted)),
          Text(
            '${negative ? '− ' : ''}${_rs(amount)}',
            style: p.t(13, w: FontWeight.w700),
          ),
        ],
      ),
    );
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, PhosphorIconsRegular.wallet, 'Payment summary'),
          const SizedBox(height: 18),
          row('Items total', order.subtotal),
          row('Delivery fee', order.deliveryFee),
          row('Service charges', order.serviceFee),
          if (order.discount > 0) row('Discount', order.discount, negative: true),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GRAND TOTAL',
                        style: p.t(
                          10,
                          w: FontWeight.w800,
                          c: onPc.withValues(alpha: 0.7),
                          ls: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _rs(order.total),
                          style: p.t(24, w: FontWeight.w800, c: onPc, ls: -0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.paymentMethod.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      order.paymentMethod,
                      style: p.t(11, w: FontWeight.w700, c: onPc),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context) {
    final p = _P(context);
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(context, PhosphorIconsRegular.user, 'Customer'),
          const SizedBox(height: 16),
          Obx(() {
            final user = users.selectedUser.value;
            final loading = users.isUserLoading.value;
            return Row(
              children: [
                loading
                    ? Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.soft,
                          border: Border.all(color: p.line),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : _avatar(context, user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.userName.isEmpty ? 'Customer' : order.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: p.t(15, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(PhosphorIconsRegular.phone, size: 13, color: p.muted),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              order.userPhone.isEmpty ? '—' : order.userPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: p.t(12.5, c: p.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _outlineAction(
                  p,
                  PhosphorIconsRegular.copy,
                  'Copy phone',
                  () {
                    Clipboard.setData(ClipboardData(text: order.userPhone));
                    MessageToast.showToast(msg: 'Phone number copied');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineAction(
                  p,
                  PhosphorIconsRegular.userCircle,
                  'View profile',
                  () => Get.to(() => UserDetailScreen(userId: order.userId)),
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlineAction(
    _P p,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled
              ? p.primary.withValues(alpha: hovering ? 0.16 : 0.08)
              : (hovering ? p.soft : p.surface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? p.primary.withValues(alpha: 0.35) : p.line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? p.primary : p.ink),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: p.t(12, w: FontWeight.w700, c: filled ? p.primary : p.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, UserModel? user) {
    final p = _P(context);
    final imageUrl = user?.image;
    final fallback = Container(
      color: p.primary.withValues(alpha: 0.1),
      child: Icon(PhosphorIconsRegular.user, size: 24, color: p.primary),
    );
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _riderCard(BuildContext context) {
    final p = _P(context);
    final controller = Get.find<OrderActionsController>();
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            context,
            PhosphorIconsRegular.motorcycle,
            'Rider assignment',
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (controller.loadingRiders.value) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const LinearProgressIndicator(minHeight: 4),
              );
            }
            if (controller.error.value != null && controller.riders.isEmpty) {
              return ErrorRetryWidget(
                errorMessage: controller.error.value!,
                onRetry: controller.reloadRiders,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CommonDropdown<String>(
                  label: 'Assign rider',
                  value: controller.assignedRiderId.value ?? '',
                  bottomSpacing: 0,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Not assigned'),
                    ),
                    ...controller.riders.map(
                      (rider) => DropdownMenuItem(
                        value: rider.id,
                        child: Text(
                          '${rider.name} · ${rider.phone}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _isClosed
                      ? null
                      : (value) async {
                          final riderId =
                              value == null || value.isEmpty ? null : value;
                          final rider = controller.riders.firstWhereOrNull(
                            (item) => item.id == riderId,
                          );
                          final confirmed = await CommonDialog.confirm(
                            context: context,
                            title: riderId == null
                                ? 'Remove rider assignment?'
                                : 'Assign this rider?',
                            message: riderId == null
                                ? 'This order will no longer be assigned to a rider.'
                                : 'Assign ${rider?.name ?? 'the selected rider'} to this order?',
                            icon: PhosphorIconsRegular.motorcycle,
                            iconColor: p.primary,
                            positiveButtonText: riderId == null
                                ? 'Remove assignment'
                                : 'Assign rider',
                          );
                          if (confirmed != true) return;
                          try {
                            await controller.assignRider(riderId);
                          } catch (exception) {
                            Get.snackbar(
                              'Could not assign rider',
                              exception.toString(),
                            );
                          }
                        },
                ),
                if (_isClosed) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Riders can’t be changed on a closed order.',
                    style: p.t(11.5, c: p.muted),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Actions (confirmation, reasons, progress)
  // --------------------------------------------------------------------

  Future<void> _accept(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Accept this order?',
      message: 'Move this order into fulfilment and notify the customer.',
      icon: PhosphorIconsRegular.checkCircle,
      iconColor: _statusColor(context, 'Accepted'),
      positiveButtonText: 'Accept',
    );
    if (confirmed != true) return;
    await _withProgress(
      'Accepting order...',
      () => orders.updateOrderStatus(
        id: order.id,
        status: 'Accepted',
        orderId: order.orderId ?? '',
      ),
    );
  }

  Future<void> _deliver(BuildContext context) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Mark as delivered?',
      message: 'Confirm this order has been delivered to the customer.',
      icon: PhosphorIconsRegular.checkCircle,
      iconColor: _statusColor(context, 'Delivered'),
      positiveButtonText: 'Mark delivered',
    );
    if (confirmed != true) return;
    await _withProgress(
      'Updating order...',
      () => orders.updateOrderStatus(
        id: order.id,
        status: 'Delivered',
        orderId: order.orderId ?? '',
      ),
    );
  }

  Future<void> _rejectOrder(BuildContext context) async {
    final result = await _askReason(
      context,
      _ReasonKind(
        title: 'Reject this order',
        message:
            'The customer will be told their order could not be fulfilled. '
            'Items go back into stock.',
        confirm: 'Reject order',
        icon: PhosphorIconsRegular.prohibit,
        color: Theme.of(context).colorScheme.error,
        reasons: const [
          'Out of stock',
          'Cannot deliver to this area',
          'Customer unreachable',
          'Suspicious order',
          'Other',
        ],
      ),
    );
    if (result == null) return;
    await _withProgress(
      'Rejecting order...',
      () => orders.rejectOrder(order.id, reason: result.reason),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final result = await _askReason(
      context,
      _ReasonKind(
        title: 'Cancel this order',
        message:
            'The order will be cancelled and its items returned to stock. '
            'This can’t be undone.',
        confirm: 'Cancel order',
        icon: PhosphorIconsRegular.xCircle,
        color: Theme.of(context).colorScheme.error,
        reasons: const [
          'Customer asked to cancel',
          'Item no longer available',
          'Payment problem',
          'Could not reach customer',
          'Other',
        ],
      ),
    );
    if (result == null) return;
    await _withProgress(
      'Cancelling order...',
      () => orders.cancelOrder(order.id, reason: result.reason),
    );
  }

  Future<void> _returnOrder(BuildContext context) async {
    final result = await _askReason(
      context,
      _ReasonKind(
        title: 'Process a return',
        message:
            'Record that the customer sent this delivered order back. '
            'You choose whether the items go back into stock.',
        confirm: 'Record return',
        icon: PhosphorIconsRegular.arrowCounterClockwise,
        color: Theme.of(context).colorScheme.secondary,
        offerRestock: true,
        reasons: const [
          'Damaged item',
          'Wrong item delivered',
          'Quality issue',
          'Customer changed mind',
          'Other',
        ],
      ),
    );
    if (result == null) return;
    await _withProgress(
      'Recording return...',
      () => orders.returnOrder(
        order.id,
        reason: result.reason,
        restock: result.restock,
      ),
    );
  }

  Future<_ReasonResult?> _askReason(BuildContext context, _ReasonKind kind) =>
      showDialog<_ReasonResult>(
        context: context,
        builder: (_) => _ReasonDialog(kind: kind),
      );

  Future<T> _withProgress<T>(String label, Future<T> Function() task) async {
    Get.dialog(
      PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      return await task();
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
    }
  }

  // --------------------------------------------------------------------
  // Shared building blocks
  // --------------------------------------------------------------------

  Widget _card(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final p = _P(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(
    BuildContext context,
    IconData icon,
    String title, {
    Widget? trailing,
  }) {
    final p = _P(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: p.cs.onPrimaryContainer),
        ),
        const SizedBox(width: 11),
        Text(title, style: p.t(15, w: FontWeight.w800, ls: -0.1)),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Reason dialog (reject / cancel / return)
// ============================================================================

class _ReasonKind {
  const _ReasonKind({
    required this.title,
    required this.message,
    required this.confirm,
    required this.icon,
    required this.color,
    required this.reasons,
    this.offerRestock = false,
  });

  final String title;
  final String message;
  final String confirm;
  final IconData icon;
  final Color color;
  final List<String> reasons;
  final bool offerRestock;
}

class _ReasonResult {
  const _ReasonResult(this.reason, this.restock);
  final String reason;
  final bool restock;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.kind});
  final _ReasonKind kind;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _note = TextEditingController();
  String? _reason;
  bool _restock = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _P(context);
    final kind = widget.kind;
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: p.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: kind.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(kind.icon, color: kind.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      kind.title,
                      style: p.t(18, w: FontWeight.w800, ls: -0.2),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(kind.message, style: p.t(13, c: p.muted, h: 1.5)),
              const SizedBox(height: 20),
              Text('Reason', style: p.t(12.5, w: FontWeight.w700, c: p.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in kind.reasons)
                    ChoiceChip(
                      label: Text(reason),
                      selected: _reason == reason,
                      showCheckmark: false,
                      selectedColor: kind.color.withValues(alpha: 0.14),
                      side: BorderSide(
                        color: _reason == reason ? kind.color : p.line,
                      ),
                      labelStyle: p.t(
                        12.5,
                        w: FontWeight.w600,
                        c: _reason == reason ? kind.color : p.ink,
                      ),
                      onSelected: (_) => setState(() {
                        _reason = reason;
                        if (kind.offerRestock) {
                          _restock = reason != 'Damaged item';
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLines: 2,
                style: p.t(13.5),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Add a note (optional)',
                ),
              ),
              if (kind.offerRestock) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add items back to stock',
                              style: p.t(13.5, w: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _restock
                                  ? 'Quantities will be added to inventory.'
                                  : 'Stock will stay as it is (e.g. damaged goods).',
                              style: p.t(11.5, c: p.muted),
                            ),
                          ],
                        ),
                      ),
                      AppToggle(
                        value: _restock,
                        onChanged: (value) => setState(() => _restock = value),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _reason == null
                          ? null
                          : () {
                              final note = _note.text.trim();
                              Navigator.of(context).pop(
                                _ReasonResult(
                                  note.isEmpty ? _reason! : '$_reason — $note',
                                  _restock,
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        backgroundColor: kind.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(kind.confirm),
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
}

// ============================================================================
// Hover + click wrapper for desktop/web
// ============================================================================

class _Hover extends StatefulWidget {
  final Widget Function(bool hovering) builder;
  final VoidCallback? onTap;

  const _Hover({required this.builder, this.onTap});

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_hovering),
      ),
    );
  }
}

// ============================================================================
// Shared card look
// ============================================================================

BoxDecoration _cardDeco(_P p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: p.line),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ],
);

Widget _itemThumb(BuildContext context, OrderItem item) {
  final p = _P(context);
  final fallback = Icon(PhosphorIconsRegular.image, size: 20, color: p.muted);
  return Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: p.soft,
      border: Border.all(color: p.line),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
          ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return LoadingPlaceholder.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Container(color: p.surface),
                );
              },
              errorBuilder: (_, _, _) => Center(child: fallback),
            )
          : Center(child: fallback),
    ),
  );
}

// ============================================================================
// Items: first 3 shown, "See more" expands the rest
// ============================================================================

class _ItemsCard extends StatefulWidget {
  const _ItemsCard({required this.items});
  final List<OrderItem> items;

  @override
  State<_ItemsCard> createState() => _ItemsCardState();
}

class _ItemsCardState extends State<_ItemsCard> {
  static const int _preview = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = _P(context);
    final items = widget.items;
    final hasMore = items.length > _preview;
    final hidden = items.length - _preview;
    final shown = (_expanded || !hasMore) ? items : items.sublist(0, _preview);
    final totalQty = items.fold<num>(0, (s, i) => s + i.quantity);
    final itemsTotal = items.fold<double>(
      0,
      (s, i) => s + i.price * i.quantity,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco(p),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: p.cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.shoppingBag,
                        size: 17,
                        color: p.cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'Order items',
                      style: p.t(15, w: FontWeight.w800, ls: -0.1),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.soft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.line),
                      ),
                      child: Text(
                        '${items.length} items · $totalQty units',
                        style: p.t(11.5, w: FontWeight.w700, c: p.muted),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                Container(
                  color: p.soft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 34, child: _th(p, '#')),
                      Expanded(child: _th(p, 'PRODUCT')),
                      SizedBox(width: 110, child: _th(p, 'UNIT PRICE')),
                      SizedBox(width: 70, child: _th(p, 'QTY')),
                      SizedBox(width: 120, child: _th(p, 'TOTAL', right: true)),
                    ],
                  ),
                ),
              Divider(height: 1, color: p.line),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      _row(context, shown[i], i + 1, compact),
                      if (i != shown.length - 1) Divider(height: 1, color: p.line),
                    ],
                  ],
                ),
              ),
              if (hasMore) ...[
                Divider(height: 1, color: p.line),
                _toggle(p, hidden),
              ],
              Container(
                color: p.soft,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 22,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items total', style: p.t(13, c: p.muted)),
                    Text(
                      _rs(itemsTotal),
                      style: p.t(15, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggle(_P p, int hidden) {
    final fg = p.cs.onPrimaryContainer;
    return _Hover(
      onTap: () => setState(() => _expanded = !_expanded),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: p.cs.primaryContainer.withValues(alpha: h ? 0.75 : 0.4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded
                  ? 'Show less'
                  : 'See $hidden more ${hidden == 1 ? 'item' : 'items'}',
              style: p.t(13, w: FontWeight.w800, c: fg),
            ),
            const SizedBox(width: 8),
            Icon(
              _expanded
                  ? PhosphorIconsBold.caretUp
                  : PhosphorIconsBold.caretDown,
              size: 14,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(_P p, String text, {bool right = false}) => Text(
    text,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: p.t(10, w: FontWeight.w800, c: p.muted, ls: 1.2),
  );

  Widget _row(BuildContext context, OrderItem item, int number, bool compact) {
    final p = _P(context);
    return _Hover(
      onTap: () => Get.to(() => FullImageScreen(imageUrl: item.imageUrl ?? '')),
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: hovering ? p.primary.withValues(alpha: 0.04) : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22, vertical: 13),
        child: compact
            ? Row(
                children: [
                  _itemThumb(context, item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: p.t(13, w: FontWeight.w700, h: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_rs(item.price)} × ${item.quantity}',
                          style: p.t(11.5, c: p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _rs(item.price * item.quantity),
                    style: p.t(13, w: FontWeight.w800),
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$number'.padLeft(2, '0'),
                      style: p.t(12, w: FontWeight.w700, c: p.muted),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _itemThumb(context, item),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: p.t(13.5, w: FontWeight.w700, h: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(_rs(item.price), style: p.t(12.5, c: p.muted)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '×${item.quantity}',
                          style: p.t(
                            12,
                            w: FontWeight.w800,
                            c: p.cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      _rs(item.price * item.quantity),
                      textAlign: TextAlign.right,
                      style: p.t(13.5, w: FontWeight.w800),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}