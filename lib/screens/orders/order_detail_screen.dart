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

/// Normal lifecycle shown in the progress stepper.
const List<String> _kStatusFlow = ['Pending', 'Accepted', 'Delivered'];

/// Statuses after which nothing more can be done to an order.
const Set<String> _kClosed = {'cancelled', 'returned'};

// ============================================================================
// Theme-driven palette
// ============================================================================

class _P {
  _P(BuildContext context) : theme = Theme.of(context);

  final ThemeData theme;
  ColorScheme get cs => theme.colorScheme;
  Color get ink => cs.onSurface;
  Color get muted => cs.onSurfaceVariant;
  Color get line => theme.dividerColor;
  Color get soft => cs.surfaceContainerHighest;
  Color get surface => cs.surface;
  Color get primary => cs.primary;
  Color get onPrimary => cs.onPrimary;
  Color get secondary => cs.secondary;
  Color get error => cs.error;

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
  switch (status.toLowerCase()) {
    case 'pending':
      return AppColors.warning;
    case 'accepted':
      return Theme.of(context).colorScheme.primary;
    case 'delivered':
      return AppColors.ok;
    case 'returned':
      return Theme.of(context).colorScheme.secondary;
    case 'cancelled':
      return Theme.of(context).colorScheme.error;
    default:
      return Theme.of(context).colorScheme.primary;
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
    case 'cancelled':
      return PhosphorIconsRegular.xCircle;
    default:
      return PhosphorIconsRegular.info;
  }
}

String _statusMessage(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Waiting for your review. Accept or cancel this order.';
    case 'accepted':
      return 'Accepted and being prepared for delivery.';
    case 'delivered':
      return 'Delivered to the customer.';
    case 'returned':
      return 'The customer returned this order.';
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

BoxDecoration _cardDeco(_P p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: p.line),
  boxShadow: [
    BoxShadow(
      color: p.theme.colorScheme.shadow.withValues(alpha: 0.045),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

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
        final wide = w >= 1020;
        final narrow = w < 560;
        const gap = SizedBox(height: 16);

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _timeline(context, w),
            if (_hasReason) ...[gap, _reasonCard(context)],
            gap,
            _ItemsCard(items: order.items),
            gap,
            _deliveryCard(context),
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              gap,
              _noteCard(context),
            ],
            gap,
            _billCard(context),
          ],
        );

        final Widget side = wide || w < 760
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
            : Row(
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
                  const SizedBox(width: 16),
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
              );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 28,
            narrow ? 14 : 24,
            narrow ? 12 : 28,
            40,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, w),
                  const SizedBox(height: 20),
                  _kpiStrip(context, w),
                  const SizedBox(height: 20),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: main),
                        const SizedBox(width: 24),
                        SizedBox(width: w >= 1280 ? 360 : 320, child: side),
                      ],
                    )
                  else ...[
                    main,
                    const SizedBox(height: 16),
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
  // Header: breadcrumb, title, status, actions
  // --------------------------------------------------------------------

  Widget _header(BuildContext context, double w) {
    final p = _P(context);
    final narrow = w < 560;
    final statusColor = _statusColor(context, order.status);
    final displayId = '#${order.orderId ?? order.id}';
    final forward = _forwardAction(context);

    final crumbs = Row(
      children: [
        Text(
          'Orders',
          style: p.t(12.5, c: p.muted, w: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Icon(PhosphorIconsRegular.caretRight, size: 11, color: p.muted),
        const SizedBox(width: 6),
        Text('Order details', style: p.t(12.5, w: FontWeight.w700)),
      ],
    );

    final back = _Hover(
      onTap: () => Get.back(),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: h ? p.soft : p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        child: Icon(PhosphorIconsRegular.arrowLeft, size: 18, color: p.ink),
      ),
    );

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              'Order $displayId',
              style: p.t(narrow ? 20 : 26, w: FontWeight.w800, ls: -0.5),
            ),
            _statusPill(p, order.status, statusColor),
          ],
        ),
        const SizedBox(height: 6),
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
        _btn(
          icon: PhosphorIconsRegular.copy,
          label: 'Copy ID',
          onTap: () {
            Clipboard.setData(ClipboardData(text: order.orderId ?? order.id));
            MessageToast.showToast(msg: 'Order ID copied');
          },
        ),
        if (forward != null) forward,
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        crumbs,
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            back,
            SizedBox(width: narrow ? 12 : 16),
            Expanded(child: title),
            if (w >= 1100) ...[const SizedBox(width: 20), actions],
          ],
        ),
        if (w < 1100) ...[const SizedBox(height: 14), actions],
      ],
    );
  }

  Widget _statusPill(_P p, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            status.toUpperCase(),
            style: p.t(10.5, w: FontWeight.w800, c: color, ls: 0.9),
          ),
        ],
      ),
    );
  }

  /// Standard button used in the header.
  Widget _btn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Builder(
      builder: (context) {
        final p = _P(context);
        final fg = filled ? p.onPrimary : p.ink;
        return _Hover(
          onTap: onTap,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: filled
                  ? (h ? p.primary.withValues(alpha: 0.9) : p.primary)
                  : (h ? p.soft : p.surface),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: filled ? p.primary : p.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: p.t(12.5, w: FontWeight.w700, c: fg),
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
        return _btn(
          icon: PhosphorIconsBold.check,
          label: 'Accept order',
          filled: true,
          onTap: () => _accept(context),
        );
      case 'accepted':
        return _btn(
          icon: PhosphorIconsBold.checkCircle,
          label: 'Mark delivered',
          filled: true,
          onTap: () => _deliver(context),
        );
      case 'delivered':
        return _btn(
          icon: PhosphorIconsRegular.arrowCounterClockwise,
          label: 'Process return',
          onTap: () => _returnOrder(context),
        );
      default:
        return null;
    }
  }

  // --------------------------------------------------------------------
  // KPI strip: one bordered card, divided cells
  // --------------------------------------------------------------------

  Widget _kpiStrip(BuildContext context, double w) {
    final p = _P(context);
    final units = order.items.fold<num>(0, (a, i) => a + i.quantity);
    final stats = <(IconData, String, String, bool)>[
      (PhosphorIconsRegular.wallet, 'Grand total', _rs(order.total), true),
      (
        PhosphorIconsRegular.package,
        'Items',
        '${order.items.length} items · $units units',
        false,
      ),
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
    final cols = w >= 760 ? 4 : 2;

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += cols) {
      final slice = stats.sublist(i, math.min(i + cols, stats.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < slice.length; j++) ...[
                if (j > 0) VerticalDivider(width: 1, color: p.line),
                Expanded(child: _kpiCell(p, slice[j])),
              ],
            ],
          ),
        ),
      );
      if (i + cols < stats.length) {
        rows.add(Divider(height: 1, color: p.line));
      }
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco(p),
      child: Column(children: rows),
    );
  }

  Widget _kpiCell(_P p, (IconData, String, String, bool) s) {
    final hero = s.$4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.$2.toUpperCase(),
                  style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  s.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.t(
                    hero ? 24 : 18,
                    w: FontWeight.w800,
                    c: hero ? p.primary : p.ink,
                    ls: hero ? -0.3 : 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Progress stepper (adapts to cancelled / returned)
  // --------------------------------------------------------------------

  Widget _timeline(BuildContext context, double pageW) {
    final p = _P(context);
    final s = order.status.toLowerCase();
    late final List<String> labels;
    late int current;
    switch (s) {
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

    return _section(
      context,
      icon: PhosphorIconsRegular.path,
      title: 'Order progress',
      trailing: pageW >= 700
          ? Text(
              _statusMessage(order.status),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: p.t(12, c: p.muted),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: LayoutBuilder(
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
                top: 15,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: p.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: inset,
                top: 15,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  width: lineW * frac,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [p.primary, negative ? currentColor : p.primary],
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
      iconColor = p.onPrimary;
    } else if (terminal) {
      fill = currentColor;
      border = currentColor;
      iconColor = p.onPrimary;
    } else if (isCurrent) {
      fill = currentColor.withValues(alpha: 0.12);
      border = currentColor;
      iconColor = currentColor;
    } else {
      fill = p.soft;
      border = p.line;
      iconColor = p.muted;
    }

    final caption = (done || deliveredFinal)
        ? 'Completed'
        : terminal
        ? label
        : isCurrent
        ? 'In progress'
        : 'Upcoming';

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.surface),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: border, width: 2),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: (done || terminal || deliveredFinal)
                ? Icon(
                    done ? PhosphorIconsBold.check : _statusIcon(label),
                    size: 15,
                    color: iconColor,
                  )
                : null,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
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
                              'REASON · ${order.status.toUpperCase()}',
                              style: p.t(
                                10.5,
                                w: FontWeight.w800,
                                c: color,
                                ls: 1,
                              ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteCard(BuildContext context) {
    final p = _P(context);
    return _section(
      context,
      icon: PhosphorIconsRegular.notePencil,
      title: 'Customer note',
      child: Text(order.notes!.trim(), style: p.t(13.5, c: p.muted, h: 1.6)),
    );
  }

  // --------------------------------------------------------------------
  // Delivery + bill
  // --------------------------------------------------------------------

  Widget _deliveryCard(BuildContext context) {
    final p = _P(context);
    return _section(
      context,
      icon: PhosphorIconsRegular.truck,
      title: 'Delivery information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 12,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsFill.mapPin,
                  size: 20,
                  color: p.primary,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DELIVERY ADDRESS',
                      style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.deliveryAddress.isEmpty
                          ? 'No address provided'
                          : order.deliveryAddress,
                      style: p.t(13.5, w: FontWeight.w600, h: 1.5),
                    ),
                  ],
                ),
              ),
              _Hover(
                onTap: () => CommonController.openMapsByCoordinates(
                  order.location.latitude,
                  order.location.longitude,
                ),
                builder: (h) => AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: h ? p.primary.withValues(alpha: 0.08) : p.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: h ? p.primary.withValues(alpha: 0.5) : p.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsBold.navigationArrow,
                        size: 14,
                        color: p.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Open in Maps',
                        style: p.t(12, w: FontWeight.w700, c: p.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, box) {
              final two = box.maxWidth >= 520;
              final cw = two ? (box.maxWidth - 16) / 2 : box.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cw,
                    child: _metaTile(
                      p,
                      PhosphorIconsRegular.calendarBlank,
                      'Order date',
                      _formatDateTime(order.orderDate),
                    ),
                  ),
                  SizedBox(
                    width: cw,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: p.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1),
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
    final billUrl = order.billImageUrl ?? '';
    final hasBill = billUrl.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: _cardDeco(p),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  PhosphorIconsRegular.receipt,
                  size: 20,
                  color: p.muted,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill', style: p.t(14.5, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    hasBill
                        ? '1 image attached to this order'
                        : 'No bill uploaded for this order',
                    style: p.t(12, c: p.muted),
                  ),
                ],
              ),
            ],
          ),
          _btn(
            icon: PhosphorIconsRegular.eye,
            label: 'See bill image',
            onTap: () {
              if (!hasBill) {
                MessageToast.showToast(msg: 'No bill image for this order');
                return;
              }
              Get.dialog(_BillDialog(order: order, billUrl: billUrl));
            },
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
              icon: PhosphorIconsRegular.xCircle,
              title: 'Cancel order',
              subtitle:
                  'Stop this order. Stock is restored and the customer is told.',
              color: p.error,
              onTap: () => _cancelOrder(context),
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
            color: p.secondary,
            onTap: () => _returnOrder(context),
          ),
        );
      default:
        final color = _statusColor(context, order.status);
        children.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_statusIcon(order.status), size: 19, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${order.status.toLowerCase()}',
                        style: p.t(13.5, w: FontWeight.w800, c: color),
                      ),
                      const SizedBox(height: 3),
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

    return _section(
      context,
      icon: PhosphorIconsRegular.lightning,
      title: 'Order actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
    final onColor = filled ? p.onPrimary : color;
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? (hovering ? color.withValues(alpha: 0.92) : color)
              : color.withValues(alpha: hovering ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled
                ? color
                : color.withValues(alpha: hovering ? 0.5 : 0.3),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: p.t(13.5, w: FontWeight.w800, c: onColor),
                  ),
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
    Widget row(String label, double amount, {bool negative = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: p.t(13, c: p.muted)),
          Text(
            '${negative ? '− ' : ''}${_rs(amount)}',
            style: p.t(
              13,
              w: FontWeight.w700,
              c: negative ? AppColors.ok : p.ink,
            ),
          ),
        ],
      ),
    );
    return _section(
      context,
      icon: PhosphorIconsRegular.wallet,
      title: 'Payment summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Items total', order.subtotal),
          row('Delivery fee', order.deliveryFee),
          row('Service charges', order.serviceFee),
          if (order.discount > 0)
            row('Discount', order.discount, negative: true),
          Divider(height: 8, color: p.line),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAND TOTAL',
                      style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _rs(order.total),
                        style: p.t(24, w: FontWeight.w800, ls: -0.5),
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
                    color: p.soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.line),
                  ),
                  child: Text(
                    order.paymentMethod,
                    style: p.t(11, w: FontWeight.w700, c: p.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerCard(BuildContext context) {
    final p = _P(context);
    return _section(
      context,
      icon: PhosphorIconsRegular.user,
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final user = users.selectedUser.value;
            final loading = users.isUserLoading.value;
            return Row(
              children: [
                loading
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.soft,
                          border: Border.all(color: p.line),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
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
                          Icon(
                            PhosphorIconsRegular.phone,
                            size: 13,
                            color: p.muted,
                          ),
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled
              ? p.primary.withValues(alpha: hovering ? 0.14 : 0.07)
              : (hovering ? p.soft : p.surface),
          borderRadius: BorderRadius.circular(10),
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
                style: p.t(
                  12,
                  w: FontWeight.w700,
                  c: filled ? p.primary : p.ink,
                ),
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
    final parts = order.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((e) => e[0].toUpperCase()).join();
    final fallback = Container(
      color: p.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: p.t(15, w: FontWeight.w800, c: p.primary),
      ),
    );
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.line, width: 1.5),
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
    return _section(
      context,
      icon: PhosphorIconsRegular.motorcycle,
      title: 'Rider assignment',
      child: Obx(() {
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
                const DropdownMenuItem(value: '', child: Text('Not assigned')),
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
                      final riderId = value == null || value.isEmpty
                          ? null
                          : value;
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
                        MessageToast.showError(
                          msg: exception.toString(),
                          title: 'Could not assign rider',
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
        color: _P(context).error,
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
        color: _P(context).secondary,
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
  // Shared building block: titled section card with a header divider
  // --------------------------------------------------------------------

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
    EdgeInsetsGeometry? padding,
  }) {
    final p = _P(context);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: p.primary),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: p.t(14, w: FontWeight.w800, ls: -0.1),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: p.line),
          Padding(padding: padding ?? const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

// ============================================================================
// Reason dialog (cancel / return)
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
        borderRadius: BorderRadius.circular(16),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kind.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(kind.icon, color: kind.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      kind.title,
                      style: p.t(17, w: FontWeight.w800, ls: -0.2),
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
              Text(
                'Reason',
                style: p.t(12.5, w: FontWeight.w700, c: p.muted),
              ),
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
                      selectedColor: kind.color.withValues(alpha: 0.12),
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
                    borderRadius: BorderRadius.circular(10),
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
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: kind.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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

Widget _itemThumb(BuildContext context, OrderItem item) {
  final p = _P(context);
  final name = item.productName.trim();
  final fallback = Text(
    name.isEmpty ? '?' : name[0].toUpperCase(),
    style: p.t(16, w: FontWeight.w800, c: p.primary),
  );
  return Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: p.soft,
      border: Border.all(color: p.line),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(9),
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
// Items: data table, first 3 shown, "See more" expands the rest
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
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 14),
                child: Row(
                  children: [
                    Text(
                      'Order items',
                      style: p.t(14.5, w: FontWeight.w800, ls: -0.1),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
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
              Divider(height: 1, color: p.line),
              if (!compact) ...[
                Container(
                  color: p.soft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
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
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      _row(context, shown[i], i + 1, compact),
                      if (i != shown.length - 1)
                        Divider(height: 1, color: p.line),
                    ],
                  ],
                ),
              ),
              if (hasMore) ...[
                Divider(height: 1, color: p.line),
                _toggle(p, hidden),
              ],
              Divider(height: 1, color: p.line),
              Container(
                color: p.soft,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 20,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items total', style: p.t(13, c: p.muted)),
                    Text(_rs(itemsTotal), style: p.t(15, w: FontWeight.w800)),
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
    return _Hover(
      onTap: () => setState(() => _expanded = !_expanded),
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: h ? p.primary.withValues(alpha: 0.06) : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded
                  ? 'Show less'
                  : 'See $hidden more ${hidden == 1 ? 'item' : 'items'}',
              style: p.t(12.5, w: FontWeight.w800, c: p.primary),
            ),
            const SizedBox(width: 8),
            Icon(
              _expanded
                  ? PhosphorIconsBold.caretUp
                  : PhosphorIconsBold.caretDown,
              size: 13,
              color: p.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _th(_P p, String text, {bool right = false}) => Text(
    text,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1.1),
  );

  Widget _row(BuildContext context, OrderItem item, int number, bool compact) {
    final p = _P(context);
    return _Hover(
      onTap: () => Get.to(() => FullImageScreen(imageUrl: item.imageUrl ?? '')),
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: hovering
            ? p.primary.withValues(alpha: 0.035)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: 12,
        ),
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
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.soft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: p.line),
                        ),
                        child: Text(
                          '×${item.quantity}',
                          style: p.t(12, w: FontWeight.w800),
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

// ============================================================================
// Bill dialog: opens from "See bill image"
// ============================================================================

class _BillDialog extends StatelessWidget {
  const _BillDialog({required this.order, required this.billUrl});

  final OrderModel order;
  final String billUrl;

  Widget _row(_P p, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: p.t(13, c: p.muted)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: p.t(13, w: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _P(context);
    final screenH = MediaQuery.of(context).size.height;
    final imageH = math.min(560.0, math.max(300.0, screenH * 0.6));

    final image = SizedBox(
      height: imageH,
      child: ColoredBox(
        color: p.soft,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.network(
                billUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (_, _, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 38,
                        color: p.muted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Could not load the bill image.',
                        style: p.t(12.5, c: p.muted),
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

    final details = Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(p, 'Customer', order.userName.isEmpty ? '—' : order.userName),
          _row(
            p,
            'Payment',
            order.paymentMethod.isEmpty ? '—' : order.paymentMethod,
          ),
          _row(p, 'Order date', _formatDateTime(order.orderDate)),
          Divider(height: 8, color: p.line),
          const SizedBox(height: 14),
          Text(
            'BILL TOTAL',
            style: p.t(10, w: FontWeight.w700, c: p.muted, ls: 1.2),
          ),
          const SizedBox(height: 4),
          Text(_rs(order.total), style: p.t(26, w: FontWeight.w800, ls: -0.6)),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: () {
              Get.back();
              Get.to(
                () => BillViewScreen(
                  billImageUrl: billUrl,
                  orderId: order.orderId,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: p.primary,
              foregroundColor: p.onPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Open full size'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.line),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: p.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.receipt,
                        size: 18,
                        color: p.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bill image',
                            style: p.t(15.5, w: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order #${order.orderId ?? order.id}',
                            style: p.t(12, c: p.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.close_rounded, color: p.muted),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.line),
              LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: image),
                        Container(
                          width: 320,
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: p.line)),
                          ),
                          child: details,
                        ),
                      ],
                    );
                  }
                  return Column(children: [image, details]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
