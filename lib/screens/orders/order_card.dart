import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../constants.dart';
import '../../models/order_model.dart';
import '../../utils/money.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.onTap});

  final OrderModel order;
  final VoidCallback onTap;

  Color _statusColor(BuildContext context) =>
      switch (order.status.toLowerCase()) {
        'pending' => AppColors.warning,
        'cancelled' || 'rejected' => Theme.of(context).colorScheme.error,
        'delivered' => AppColors.ok,
        'accepted' || 'confirmed' || 'packed' => AppColors.info,
        _ => Theme.of(context).colorScheme.primary,
      };

  String get _displayId {
    final raw = order.orderId ?? order.id;
    return raw.length > 10 ? raw.substring(0, 10) : raw;
  }

  String get _formattedDateTime {
    final date = order.orderDate;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} · $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '#$_displayId',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (order.isFirstOrder)
                                    _chip(
                                      context,
                                      'First order',
                                      colors.secondary,
                                    ),
                                ],
                              ),
                            ),
                            _chip(context, order.status, statusColor),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formattedDateTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: theme.dividerColor),
                        ),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.primaryContainer,
                              child: Text(
                                order.userName.isNotEmpty
                                    ? order.userName[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    order.userPhone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildItemsPreview(context),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              PhosphorIconsRegular.package,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: _chip(
                                context,
                                order.paymentMethod.isEmpty
                                    ? order.paymentStatus
                                    : order.paymentMethod,
                                colors.primary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              Money.rs(order.total),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildItemsPreview(BuildContext context) {
    final items = order.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shown = items.take(3).toList();
    final remaining = items.length - shown.length;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          for (var index = 0; index < shown.length; index++)
            Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 7),
              child: _ItemThumb(item: shown[index]),
            ),
          if (remaining > 0) ...[
            const SizedBox(width: 7),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Text(
                '+$remaining',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              items.map((item) => item.productName).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  const _ItemThumb({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.imageUrl?.isNotEmpty == true
          ? Image.network(
              item.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(context),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback(context),
            )
          : _fallback(context),
    );
  }

  Widget _fallback(BuildContext context) => Center(
    child: Icon(
      PhosphorIconsRegular.basket,
      size: 16,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
