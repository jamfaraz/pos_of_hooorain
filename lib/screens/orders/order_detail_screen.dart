import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../widgets/loading_placeholder.dart';
import 'package:hoorain_pos/screens/main_screen/main_screen.dart';

import '../../constants.dart';
import '../../controllers/common_controller.dart';
import '../../controllers/order_controller.dart';
import '../../controllers/order_actions_controller.dart';
import '../../controllers/user_controller.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../utils/toas_message.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/full_image.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../users/user_detail_screen.dart';
import 'bill_viewer_screen.dart';

// ============================================================================
// Status flow
// ============================================================================

/// Ordered lifecycle used to drive the timeline.
const List<String> _kStatusFlow = ['Pending', 'Accepted', 'Delivered'];

/// Which statuses an order can move to from its current status.
const Map<String, List<String>> _kNextStatusOptions = {
  'Pending': ['Accepted', 'Cancelled'],
  'Accepted': ['Delivered', 'Cancelled'],
  'Delivered': [],
  'Cancelled': [],
};

const Map<String, String> _kStatusDialogMessage = {
  'Accepted': 'Accept this order and move it into fulfillment?',
  'Delivered': 'Confirm this order has been delivered to the customer?',
};

// ============================================================================
// Design tokens
// ============================================================================

const Color _ink = Color(0xFF0B1220);
const Color _ink2 = Color(0xFF1B2540);
const Color _muted = Color(0xFF64748B);
const Color _line = Color(0xFFE6E9F0);
const Color _soft = Color(0xFFF8FAFC);

TextStyle _t(
  double size, {
  FontWeight w = FontWeight.w500,
  Color? c,
  double? h,
  double? ls,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: w,
  color: c,
  height: h,
  letterSpacing: ls,
);

String _rs(double v) => 'Rs. ${v.toStringAsFixed(1)}';

// ============================================================================
// Screen
// ============================================================================

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.put(OrderController());
    final UsersController usersController = Get.put(UsersController());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      usersController.fetchUserById(order.userId);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final isCancelled = order.status.toLowerCase() == 'cancelled';

        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCancelled) _buildCancelledBanner() else _buildTimeline(),
            const SizedBox(height: 20),
            _buildItemsCard(context),
            const SizedBox(height: 20),
            _buildDeliveryCard(context),
            if (order.billImageUrl?.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              _buildBillCard(context),
            ],
          ],
        );

        final side = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context, orderController),
            const SizedBox(height: 20),
            _buildCustomerCard(context, usersController),
            const SizedBox(height: 20),
            _buildRiderCard(context),
          ],
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 8 : 0, 4, wide ? 8 : 0, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(context, orderController, wide),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 68, child: main),
                        const SizedBox(width: 24),
                        SizedBox(width: 400, child: side),
                      ],
                    )
                  else ...[
                    main,
                    const SizedBox(height: 20),
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
  // Hero
  // --------------------------------------------------------------------

  Widget _buildHero(
    BuildContext context,
    OrderController controller,
    bool wide,
  ) {
    final statusColor = _getStatusColor(order.status);
    final displayId = '#${order.orderId ?? order.id}';

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ORDERS',
              style: _t(
                11,
                w: FontWeight.w700,
                c: Colors.white54,
                ls: 1.4,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.caretRight,
              size: 12,
              color: Colors.white38,
            ),
            const SizedBox(width: 8),
            Text(
              'ORDER DETAILS',
              style: _t(
                11,
                w: FontWeight.w700,
                c: Colors.white,
                ls: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: [
            Text(
              'Order $displayId',
              style: _t(30, w: FontWeight.w800, c: Colors.white, ls: -0.6),
            ),
            _statusPill(order.status, statusColor),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Placed on ${_formatDateTime(order.orderDate)}',
          style: _t(13, c: Colors.white60),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        _heroGhostButton(
          icon: PhosphorIconsRegular.copy,
          label: 'Copy ID',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: '${order.orderId ?? order.id}'),
            );
            MessageToast.showToast(msg: 'Order ID copied');
          },
        ),
        _heroGhostButton(
          icon: PhosphorIconsRegular.arrowLeft,
          label: 'Back to orders',
          onTap: Get.back,
        ),
        _buildPrimaryAction(context, controller, onDark: true),
      ],
    );

    final stats = Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _heroStat(
          icon: PhosphorIconsRegular.wallet,
          label: 'Grand total',
          value: _rs(order.total),
          emphasize: true,
        ),
        _heroStat(
          icon: PhosphorIconsRegular.package,
          label: 'Items',
          value: '${order.items.length}',
        ),
        _heroStat(
          icon: PhosphorIconsRegular.creditCard,
          label: 'Payment',
          value: order.paymentMethod,
        ),
        _heroStat(
          icon: PhosphorIconsRegular.user,
          label: 'Customer',
          value: order.userName,
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ink, _ink2],
          ),
        ),
        child: Stack(
          children: [
            // Soft status-tinted glows for depth
            Positioned(
              right: -90,
              top: -110,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withAlpha(46),
                ),
              ),
            ),
            Positioned(
              left: -70,
              bottom: -130,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(8),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(wide ? 32 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: titleBlock),
                        const SizedBox(width: 20),
                        Flexible(child: actions),
                      ],
                    )
                  else ...[
                    titleBlock,
                    const SizedBox(height: 18),
                    actions,
                  ],
                  const SizedBox(height: 26),
                  stats,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withAlpha(140)),
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
            style: _t(11, w: FontWeight.w800, c: Colors.white, ls: 1),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(emphasize ? 26 : 14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: _t(
                      10,
                      w: FontWeight.w700,
                      c: Colors.white54,
                      ls: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                      emphasize ? 17 : 14,
                      w: FontWeight.w800,
                      c: Colors.white,
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

  Widget _heroGhostButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(hovering ? 30 : 16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(36)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: _t(12.5, w: FontWeight.w700, c: Colors.white)),
          ],
        ),
      ),
    );
  }

  /// The main "Update status" CTA, or a final-state badge.
  Widget _buildPrimaryAction(
    BuildContext context,
    OrderController controller, {
    bool onDark = false,
    bool fullWidth = false,
  }) {
    final nextOptions = _kNextStatusOptions[order.status] ?? [];
    final isFinal = nextOptions.isEmpty;
    final color = _getStatusColor(order.status);

    if (isFinal) {
      final cancelled = order.status.toLowerCase() == 'cancelled';
      return Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withAlpha(16) : color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onDark ? Colors.white.withAlpha(36) : color.withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(order.status),
              size: 16,
              color: onDark ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              cancelled ? 'Order cancelled' : 'Order completed',
              style: _t(
                12.5,
                w: FontWeight.w800,
                c: onDark ? Colors.white : color,
              ),
            ),
          ],
        ),
      );
    }

    return _Hover(
      onTap: () => _showStatusChooser(context, controller, nextOptions),
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        transform: Matrix4.translationValues(0, hovering ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          color: onDark ? Colors.white : kPrimaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (onDark ? Colors.white : kPrimaryColor).withAlpha(
                hovering ? 90 : 50,
              ),
              blurRadius: hovering ? 22 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsBold.arrowsLeftRight,
              size: 16,
              color: onDark ? _ink : Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              'Update status',
              style: _t(
                13,
                w: FontWeight.w800,
                c: onDark ? _ink : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Timeline
  // --------------------------------------------------------------------

  Widget _buildTimeline() {
    final currentIndex = _kStatusFlow.indexOf(order.status);
    if (currentIndex == -1) return const SizedBox.shrink();
    final color = _getStatusColor(order.status);

    return _card(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: PhosphorIconsRegular.path,
            title: 'Order progress',
            trailing: Text(
              _getStatusMessage(order.status),
              style: _t(12, c: _muted),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_kStatusFlow.length * 2 - 1, (i) {
              // Connectors sit between steps.
              if (i.isOdd) {
                final leftIndex = i ~/ 2;
                final filled = leftIndex < currentIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 19),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: 3,
                      decoration: BoxDecoration(
                        color: filled ? kPrimaryColor : _line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }
              final index = i ~/ 2;
              final done = index < currentIndex;
              final active = index == currentIndex;
              final reached = done || active;
              final stepName = _kStatusFlow[index];

              return SizedBox(
                width: 130,
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? kPrimaryColor
                            : active
                            ? color.withAlpha(24)
                            : _soft,
                        border: Border.all(
                          color: reached ? (active ? color : kPrimaryColor) : _line,
                          width: 2,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: color.withAlpha(70),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : _getStatusIcon(stepName),
                        size: 19,
                        color: done
                            ? Colors.white
                            : active
                            ? color
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      stepName,
                      style: _t(
                        13,
                        w: active ? FontWeight.w800 : FontWeight.w600,
                        c: reached ? _ink : _muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'Completed'
                          : active
                          ? 'Current'
                          : 'Upcoming',
                      style: _t(
                        11,
                        c: active ? color : Colors.grey.shade500,
                        w: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledBanner() {
    final color = _getStatusColor(order.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_outlined, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This order was cancelled',
                  style: _t(15, w: FontWeight.w800, c: color),
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock for the items below was returned to inventory.',
                  style: _t(12.5, c: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Items table
  // --------------------------------------------------------------------

  Widget _buildItemsCard(BuildContext context) {
    return _card(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                child: _cardHeader(
                  icon: PhosphorIconsRegular.shoppingBag,
                  title: 'Order items',
                  trailing: _countChip('${order.items.length} items'),
                ),
              ),
              // Table header
              Container(
                color: _soft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 34, child: _th('#')),
                    Expanded(child: _th('PRODUCT')),
                    if (!compact) SizedBox(width: 110, child: _th('UNIT PRICE')),
                    SizedBox(width: compact ? 50 : 70, child: _th('QTY')),
                    SizedBox(
                      width: compact ? 90 : 120,
                      child: _th('TOTAL', right: true),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _line),
              ...order.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == order.items.length - 1;
                return Column(
                  children: [
                    _buildItemRow(context, item, index + 1, compact),
                    if (!isLast) Divider(height: 1, color: _line),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _th(String text, {bool right = false}) => Text(
    text,
    textAlign: right ? TextAlign.right : TextAlign.left,
    style: _t(10, w: FontWeight.w800, c: _muted, ls: 1.2),
  );

  Widget _buildItemRow(
    BuildContext context,
    OrderItem item,
    int number,
    bool compact,
  ) {
    return _Hover(
      onTap: () => Get.to(() => FullImageScreen(imageUrl: item.imageUrl ?? '')),
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        color: hovering ? kPrimaryColor.withAlpha(8) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '$number'.padLeft(2, '0'),
                style: _t(12, w: FontWeight.w700, c: Colors.grey.shade400),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildProductImage(context, item),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _t(13.5, w: FontWeight.w700, c: _ink, h: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              SizedBox(
                width: 110,
                child: Text(_rs(item.price), style: _t(12.5, c: _muted)),
              ),
            SizedBox(
              width: compact ? 50 : 70,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _line),
                  ),
                  child: Text(
                    '×${item.quantity}',
                    style: _t(12, w: FontWeight.w800, c: _ink),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: compact ? 90 : 120,
              child: Text(
                _rs(item.price * item.quantity),
                textAlign: TextAlign.right,
                style: _t(13.5, w: FontWeight.w800, c: _ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, OrderItem item) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: _soft,
        border: Border.all(color: _line),
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
                    child: Container(
                      width: 52,
                      height: 52,
                      color: theme.colorScheme.surface,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.image_not_supported_outlined,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              )
            : Icon(
                Icons.inventory_2_outlined,
                size: 22,
                color: Colors.grey.shade400,
              ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Delivery
  // --------------------------------------------------------------------

  Widget _buildDeliveryCard(BuildContext context) {
    return _card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: PhosphorIconsRegular.truck,
            title: 'Delivery information',
          ),
          const SizedBox(height: 20),
          _Hover(
            onTap: () => CommonController.openMapsByCoordinates(
              order.location.latitude,
              order.location.longitude,
            ),
            builder: (hovering) => AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kPrimaryColor.withAlpha(hovering ? 20 : 11),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: kPrimaryColor.withAlpha(hovering ? 90 : 45),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withAlpha(24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsFill.mapPin,
                      size: 22,
                      color: kPrimaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVERY ADDRESS',
                          style: _t(
                            10,
                            w: FontWeight.w800,
                            c: _muted,
                            ls: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.deliveryAddress,
                          style: _t(
                            13.5,
                            w: FontWeight.w700,
                            c: _ink,
                            h: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsBold.navigationArrow,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Open in Maps',
                          style: _t(
                            11.5,
                            w: FontWeight.w800,
                            c: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _metaTile(
                icon: PhosphorIconsRegular.calendarBlank,
                label: 'Order date',
                value: _formatDateTime(order.orderDate),
              ),
              _metaTile(
                icon: PhosphorIconsRegular.creditCard,
                label: 'Payment method',
                value: order.paymentMethod,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _muted),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: _t(10, w: FontWeight.w800, c: _muted, ls: 1.1),
                ),
                const SizedBox(height: 3),
                Text(value, style: _t(13, w: FontWeight.w700, c: _ink)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Bill image
  // --------------------------------------------------------------------

  Widget _buildBillCard(BuildContext context) {
    final billUrl = order.billImageUrl!;
    return _card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: PhosphorIconsRegular.receipt,
            title: 'Bill image',
          ),
          const SizedBox(height: 18),
          _Hover(
            onTap: () => Get.to(
              () =>
                  BillViewScreen(billImageUrl: billUrl, orderId: order.orderId),
            ),
            builder: (hovering) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _soft,
                  border: Border.all(color: _line),
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
                            child: Container(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 34,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      color: Colors.black.withAlpha(hovering ? 90 : 0),
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
                          color: Colors.black.withAlpha(170),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              PhosphorIconsBold.magnifyingGlassPlus,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Click to view',
                              style: _t(
                                11,
                                w: FontWeight.w700,
                                c: Colors.white,
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
  // Side column: summary
  // --------------------------------------------------------------------

  Widget _buildSummaryCard(BuildContext context, OrderController controller) {
    return _card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: PhosphorIconsRegular.receiptX,
            title: 'Payment summary',
          ),
          const SizedBox(height: 20),
          _priceRow('Items total', order.subtotal),
          const SizedBox(height: 12),
          _priceRow('Delivery fee', order.deliveryFee),
          const SizedBox(height: 12),
          _priceRow('Service charges', order.serviceFee),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_ink, _ink2],
              ),
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
                        style: _t(
                          10,
                          w: FontWeight.w800,
                          c: Colors.white54,
                          ls: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _rs(order.total),
                        style: _t(
                          24,
                          w: FontWeight.w800,
                          c: Colors.white,
                          ls: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.paymentMethod,
                    style: _t(11, w: FontWeight.w700, c: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildPrimaryAction(context, controller, fullWidth: true),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _t(13, c: _muted)),
        Text(_rs(amount), style: _t(13, w: FontWeight.w700, c: _ink)),
      ],
    );
  }

  // --------------------------------------------------------------------
  // Side column: customer
  // --------------------------------------------------------------------

  Widget _buildCustomerCard(
    BuildContext context,
    UsersController usersController,
  ) {
    return _card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(icon: PhosphorIconsRegular.user, title: 'Customer'),
          const SizedBox(height: 18),
          Obx(() {
            final user = usersController.selectedUser.value;
            final loading = usersController.isUserLoading.value;
            return Row(
              children: [
                if (loading)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _soft,
                      border: Border.all(color: _line),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimaryColor,
                        ),
                      ),
                    ),
                  )
                else
                  _buildCustomerAvatar(user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _t(15, w: FontWeight.w800, c: _ink),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.phone,
                            size: 13,
                            color: _muted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              order.userPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(12.5, c: _muted),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _outlineAction(
                  icon: PhosphorIconsRegular.copy,
                  label: 'Copy phone',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: order.userPhone));
                    MessageToast.showToast(msg: 'Phone number copied');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlineAction(
                  icon: PhosphorIconsRegular.userCircle,
                  label: 'View profile',
                  filled: true,
                  onTap: () =>
                      Get.to(() => UserDetailScreen(userId: order.userId)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled
              ? kPrimaryColor.withAlpha(hovering ? 30 : 16)
              : (hovering ? _soft : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? kPrimaryColor.withAlpha(80) : _line,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? kPrimaryColor : _ink),
            const SizedBox(width: 7),
            Text(
              label,
              style: _t(
                12,
                w: FontWeight.w700,
                c: filled ? kPrimaryColor : _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAvatar(UserModel? user) {
    final String? imageUrl = user?.image;
    final fallback = Container(
      color: kPrimaryColor.withAlpha(20),
      child: const Icon(
        PhosphorIconsRegular.user,
        size: 24,
        color: kPrimaryColor,
      ),
    );

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kPrimaryColor.withAlpha(70), width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return LoadingPlaceholder.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => fallback,
              )
            : fallback,
      ),
    );
  }

  // --------------------------------------------------------------------
  // Side column: rider
  // --------------------------------------------------------------------

  Widget _buildRiderCard(BuildContext context) {
    final controller = Get.find<OrderActionsController>();
    return _card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: PhosphorIconsRegular.motorcycle,
            title: 'Rider assignment',
          ),
          const SizedBox(height: 18),
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
            return CommonDropdown<String>(
              label: 'Assign rider',
              value: controller.assignedRiderId.value ?? '',
              bottomSpacing: 0,
              items: [
                const DropdownMenuItem(value: '', child: Text('Not assigned')),
                ...controller.riders.map(
                  (rider) => DropdownMenuItem(
                    value: rider.id,
                    child: Text('${rider.name} · ${rider.phone}'),
                  ),
                ),
              ],
              onChanged: (value) async {
                final riderId = value == null || value.isEmpty ? null : value;
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
                  iconColor: Theme.of(context).colorScheme.primary,
                  positiveButtonText: riderId == null
                      ? 'Remove assignment'
                      : 'Assign rider',
                );
                if (confirmed != true) return;
                try {
                  await controller.assignRider(riderId);
                } catch (exception) {
                  Get.snackbar('Could not assign rider', exception.toString());
                }
              },
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------
  // Status chooser (desktop dialog) + confirmations
  // --------------------------------------------------------------------

  void _showStatusChooser(
    BuildContext context,
    OrderController controller,
    List<String> nextOptions,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Update order status',
                        style: _t(18, w: FontWeight.w800, c: _ink),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, color: _muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Currently ${order.status}. Choose what happens next.',
                  style: _t(12.5, c: _muted),
                ),
                const SizedBox(height: 20),
                ...nextOptions.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildStatusOptionTile(
                      status: status,
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        if (status == 'Cancelled') {
                          _showCancelOrderDialog(context, controller);
                        } else {
                          _showStatusUpdateDialog(
                            context,
                            controller,
                            status,
                            _getStatusColor(status),
                            '${status == 'Delivered' ? 'Mark as Delivered' : status} Order',
                            _kStatusDialogMessage[status] ??
                                'Update this order to "$status"?',
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOptionTile({
    required String status,
    required VoidCallback onTap,
  }) {
    final color = _getStatusColor(status);
    return _Hover(
      onTap: onTap,
      builder: (hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(hovering ? 26 : 12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(hovering ? 120 : 55)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(_getStatusIcon(status), size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == 'Delivered'
                        ? 'Mark as Delivered'
                        : 'Mark as $status',
                    style: _t(14, w: FontWeight.w800, c: color),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _getStatusMessage(status),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _t(11.5, c: _muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: color.withAlpha(180)),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateDialog(
    BuildContext context,
    OrderController controller,
    String newStatus,
    Color color,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => CommonDialog(
        title: title,
        message: message,
        icon: _getStatusIcon(newStatus),
        iconColor: color,
        negativeButtonText: 'No',
        positiveButtonText: 'Confirm',
        onPositiveButtonPressed: () async {
          Navigator.of(context).pop();
          await controller.updateOrderStatus(
            id: order.id,
            status: newStatus,
            orderId: order.orderId ?? '',
          );
        },
      ),
    );
  }

  void _showCancelOrderDialog(
    BuildContext context,
    OrderController controller,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CommonDialog(
        title: 'Cancel Order',
        message:
            'Are you sure you want to cancel this order? The product quantities will be restored to inventory. This action cannot be undone.',
        icon: Icons.cancel_outlined,
        iconColor: Colors.red,
        negativeButtonText: 'Exit',
        positiveButtonText: 'Confirm',
        onPositiveButtonPressed: () async {
          Navigator.of(dialogContext).pop();

          Get.dialog(
            Center(
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: kGreenColor),
                      const SizedBox(height: 16),
                      Text(
                        'Cancelling order...',
                        style: _t(13, c: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            barrierDismissible: false,
          );

          try {
            final success = await controller.cancelOrder(order.id);

            if (Get.isDialogOpen ?? false) {
              Get.back();
            }

            if (success) {
              MessageToast.showToast(msg: 'Order cancelled successfully');
              Future.delayed(const Duration(milliseconds: 500), () {
                if (Get.context != null && Navigator.canPop(Get.context!)) {
                  Get.offAll(() => MainScreen());
                }
              });
            }
          } catch (e) {
            if (Get.isDialogOpen ?? false) {
              Get.back();
            }
            MessageToast.showToast(msg: 'Error: ${e.toString()}');
          }
        },
      ),
    );
  }

  // --------------------------------------------------------------------
  // Shared building blocks
  // --------------------------------------------------------------------

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1220).withAlpha(10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kPrimaryColor.withAlpha(18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: kPrimaryColor),
        ),
        const SizedBox(width: 12),
        Text(title, style: _t(15, w: FontWeight.w800, c: _ink, ls: -0.1)),
        if (trailing != null) ...[
          const Spacer(),
          Flexible(child: trailing),
        ],
      ],
    );
  }

  Widget _countChip(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _line),
        ),
        child: Text(text, style: _t(11.5, w: FontWeight.w700, c: _muted)),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Formatting / status helpers
  // --------------------------------------------------------------------

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
    return '${date.day} ${months[date.month - 1]}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'The order is awaiting admin review and acceptance.';
      case 'accepted':
        return 'The order has been accepted and is being prepared.';
      case 'delivered':
        return 'The order was successfully delivered and completed.';
      case 'cancelled':
        return 'This order has been officially cancelled.';
      default:
        return 'Order status: $status';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions_outlined;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'delivered':
        return Icons.verified_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'accepted':
        return AppColors.info;
      case 'delivered':
        return AppColors.ok;
      case 'cancelled':
        return AppColors.bad;
      default:
        return kPrimaryColor;
    }
  }
}

// ============================================================================
// Small hover + click wrapper for desktop/web interactions
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