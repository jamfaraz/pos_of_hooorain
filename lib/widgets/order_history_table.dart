import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/order_model.dart';
import '../utils/money.dart';
import 'order_card.dart';

const List<int> _columnFlex = [2, 3, 4, 2, 1, 2, 3];
const double _horizontalPadding = 24;

class OrderHistoryTableHeader extends StatelessWidget {
  const OrderHistoryTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.labelMedium?.copyWith(
      fontSize: 11.5,
      color: colors.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );

    Widget heading(
      String label,
      int column, {
      TextAlign align = TextAlign.left,
    }) => Expanded(
      flex: _columnFlex[column],
      child: Text(label.toUpperCase(), style: style, textAlign: align),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          heading('Order', 0),
          heading('Placed', 1),
          heading('Customer', 2),
          heading('Channel', 3),
          heading('Items', 4, align: TextAlign.center),
          heading('Total', 5, align: TextAlign.right),
          Expanded(
            flex: _columnFlex[6],
            child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text('STATUS', style: style),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderHistoryTableRow extends StatelessWidget {
  const OrderHistoryTableRow({
    super.key,
    required this.order,
    required this.placedAt,
    required this.loadCustomerImage,
    required this.onTap,
    this.isLast = false,
  });

  final OrderModel order;
  final String placedAt;
  final Future<String?> Function() loadCustomerImage;
  final VoidCallback onTap;
  final bool isLast;

  Color _statusColor(BuildContext context) =>
      switch (order.status.toLowerCase().trim()) {
        'delivered' => AppColors.ok,
        'accepted' || 'packed' => AppColors.info,
        'out for delivery' => const Color(0xFF0B7A5E),
        'pending' => AppColors.warning,
        'cancelled' => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = colors.outlineVariant.withValues(alpha: 0.6);
    final radius = isLast
        ? const BorderRadius.vertical(bottom: Radius.circular(16))
        : null;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final mutedStyle = textStyle?.copyWith(color: colors.onSurfaceVariant);
    final customerName = order.userName.isEmpty
        ? 'Walk-in customer'
        : order.userName;
    final channel = order.channel.isEmpty
        ? ''
        : '${order.channel[0].toUpperCase()}${order.channel.substring(1)}';
    final statusColor = _statusColor(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border(
          left: BorderSide(color: border),
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: colors.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: 13,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: _columnFlex[0],
                  child: Text(
                    order.orderId ?? order.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: _columnFlex[1],
                  child: Text(placedAt, style: mutedStyle),
                ),
                Expanded(
                  flex: _columnFlex[2],
                  child: Row(
                    children: [
                      OrderCustomerAvatar(
                        name: order.userName,
                        customerId: order.userId,
                        radius: 14,
                        loadImage: loadCustomerImage,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: _columnFlex[3],
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        channel,
                        style: textStyle?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: _columnFlex[4],
                  child: Text(
                    '${order.items.length}',
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
                Expanded(
                  flex: _columnFlex[5],
                  child: Text(
                    Money.rs(order.total),
                    textAlign: TextAlign.right,
                    style: textStyle?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: _columnFlex[6],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusPill(
                        status: order.status,
                        color: statusColor,
                      ),
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
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = Color.alphaBlend(
      color.withValues(alpha: 0.14),
      theme.colorScheme.surface,
    );
    final foreground = Color.lerp(
      color,
      theme.brightness == Brightness.dark ? Colors.white : Colors.black,
      0.25,
    )!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
