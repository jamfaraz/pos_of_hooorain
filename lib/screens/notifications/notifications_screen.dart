import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../models/order_model.dart';
import '../../services/notification_service.dart';
import '../../utils/toas_message.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notifications = NotificationService();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String? _userId;
  String _filter = 'all';
  bool _markingAll = false;
  final Map<String, Future<_NotificationSender>> _senderCache = {};

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _watchNotifications();
  }

  void _watchNotifications() {
    final userId = _userId;
    _stream = userId == null ? null : _notifications.watchForUser(userId);
  }

  Future<void> _markAllRead() async {
    final userId = _userId;
    if (userId == null || _markingAll) return;

    setState(() => _markingAll = true);
    try {
      final count = await _notifications.markAllAsRead(userId);
      if (count > 0) {
        MessageToast.showSuccess(
          msg:
              '$count ${count == 1 ? 'notification' : 'notifications'} marked as read.',
        );
      }
    } catch (exception) {
      MessageToast.showError(
        msg: exception.toString(),
        title: 'Could not mark notifications as read',
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    if (data['isRead'] != true) {
      try {
        await _notifications.markAsRead(document.id);
      } catch (exception) {
        MessageToast.showError(
          msg: exception.toString(),
          title: 'Could not update notification',
        );
      }
    }

    final orderId = _orderDocumentId(data);
    if (orderId == null) {
      MessageToast.showInfo(
        msg: 'This notification does not link to an order.',
      );
      return;
    }

    try {
      final orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      final orderData = orderSnapshot.data();
      if (!orderSnapshot.exists || orderData == null) {
        MessageToast.showError(msg: 'Order details not found.');
        return;
      }
      final order = OrderModel.fromMap(orderData, orderSnapshot.id);
      Get.toNamed('/orders/detail', arguments: order);
    } catch (exception) {
      MessageToast.showError(
        msg: exception.toString(),
        title: 'Could not open order',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null || _stream == null) {
      return const _NotificationEmpty(
        title: 'Sign in to view notifications',
        message: 'Notifications for your admin account will appear here.',
        icon: PhosphorIconsRegular.bell,
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _NotificationError(
            error: snapshot.error.toString(),
            onRetry: () => setState(_watchNotifications),
          );
        }
        if (!snapshot.hasData) return const _NotificationLoading();

        final documents = snapshot.data!.docs;
        final unreadCount = documents
            .where((document) => document.data()['isRead'] != true)
            .length;
        final visible = _filter == 'unread'
            ? documents
                  .where((document) => document.data()['isRead'] != true)
                  .toList()
            : documents;

        return LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 560;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 24,
                compact ? 18 : 28,
                compact ? 12 : 24,
                40,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pageHeader(
                        context,
                        unreadCount: unreadCount,
                        compact: compact,
                      ),
                      const SizedBox(height: 22),
                      _filterBar(context, unreadCount, compact),
                      const SizedBox(height: 14),
                      if (visible.isEmpty)
                        _NotificationEmpty(
                          title: _filter == 'unread'
                              ? 'You’re all caught up'
                              : 'No notifications yet',
                          message: _filter == 'unread'
                              ? 'Unread notifications will appear here.'
                              : 'New customer and order updates will appear here.',
                          icon: _filter == 'unread'
                              ? PhosphorIconsRegular.checkCircle
                              : PhosphorIconsRegular.bell,
                        )
                      else
                        for (final document in visible)
                          FutureBuilder<_NotificationSender>(
                            future: _senderFor(
                              document.data()['currentUserId']?.toString(),
                            ),
                            builder: (context, senderSnapshot) {
                              final sender =
                                  senderSnapshot.data ??
                                  const _NotificationSender(
                                    name: 'Customer',
                                    image: '',
                                  );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _NotificationCard(
                                  data: document.data(),
                                  senderName: senderSnapshot.hasError
                                      ? 'Sender unavailable'
                                      : sender.name,
                                  senderImage: sender.image,
                                  onTap: () => _openNotification(document),
                                ),
                              );
                            },
                          ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pageHeader(
    BuildContext context, {
    required int unreadCount,
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (unreadCount > 0)
          OutlinedButton.icon(
            onPressed: _markingAll ? null : _markAllRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.checks, size: 17),
            label: Text(_markingAll ? 'Saving…' : 'Mark all as read'),
          ),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$unreadCount unread',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notifications',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Customer messages and order updates for your store.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (unreadCount > 0) ...[const SizedBox(height: 16), actions],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        if (unreadCount > 0) actions,
      ],
    );
  }

  Widget _filterBar(BuildContext context, int unreadCount, bool compact) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: 'All',
          selected: _filter == 'all',
          onSelected: () => setState(() => _filter = 'all'),
        ),
        _FilterChip(
          label: unreadCount > 0 ? 'Unread · $unreadCount' : 'Unread',
          selected: _filter == 'unread',
          onSelected: () => setState(() => _filter = 'unread'),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 10),
            child: Text(
              'Most recent first',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Future<_NotificationSender> _senderFor(String? senderId) {
    final id = senderId?.trim() ?? '';
    if (id.isEmpty) {
      return Future.value(
        const _NotificationSender(name: 'Order activity', image: ''),
      );
    }
    return _senderCache.putIfAbsent(id, () async {
      if (id == _userId) {
        return const _NotificationSender(name: 'System Update', image: '');
      }

      final admin = await FirebaseFirestore.instance
          .collection('Admin')
          .doc(id)
          .get();
      if (admin.exists) return _senderFrom(admin.data(), 'Admin User');

      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (user.exists) return _senderFrom(user.data(), 'Customer');
      return const _NotificationSender(name: 'Customer', image: '');
    });
  }

  _NotificationSender _senderFrom(Map<String, dynamic>? data, String fallback) {
    final name = data?['fullName'];
    final image = data?['image'];
    return _NotificationSender(
      name: name is String && name.trim().isNotEmpty ? name.trim() : fallback,
      image: image is String ? image : '',
    );
  }
}

class _NotificationSender {
  const _NotificationSender({required this.name, required this.image});

  final String name;
  final String image;
}

String? _orderDocumentId(Map<String, dynamic> data) {
  for (final key in ['orderDocId', 'orderId']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

DateTime? _notificationDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

String _relativeTime(DateTime? date) {
  if (date == null) return 'Time unavailable';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.isNegative || elapsed.inSeconds < 60) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  return DateFormat('d MMM yyyy').format(date);
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.data,
    required this.senderName,
    required this.senderImage,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final String senderName;
  final String senderImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final unread = data['isRead'] != true;
    final isChat = data['isChat'] == true;
    final orderId = _orderDocumentId(data);
    final title =
        data['title'] is String && (data['title'] as String).trim().isNotEmpty
        ? (data['title'] as String).trim()
        : isChat
        ? 'New message'
        : orderId != null
        ? 'Order update'
        : 'Notification';
    final message = data['message'] is String
        ? (data['message'] as String).trim()
        : '';
    final orderNumber = data['orderNumber']?.toString().trim();
    final status = data['status']?.toString().trim();
    final time = _relativeTime(_notificationDate(data['time']));
    final surface = unread
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.045), cs.surface)
        : cs.surface;

    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 600;
        return Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: unread
                  ? cs.primary.withValues(alpha: 0.28)
                  : theme.dividerColor,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotificationIcon(
                        icon: isChat
                            ? PhosphorIconsRegular.chatCircleText
                            : orderId == null
                            ? PhosphorIconsRegular.bell
                            : PhosphorIconsRegular.package,
                        unread: unread,
                        name: senderName,
                        image: senderImage,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        senderName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: unread
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    time,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                message,
                                maxLines: compact ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (orderId != null ||
                                (status != null && status.isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (orderId != null)
                                    _InfoPill(
                                      icon: PhosphorIconsRegular.receipt,
                                      label:
                                          'Order #${orderNumber?.isNotEmpty == true ? orderNumber : orderId}',
                                    ),
                                  if (status != null && status.isNotEmpty)
                                    _InfoPill(
                                      icon: PhosphorIconsRegular.circle,
                                      label: status,
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          time,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (orderId != null) ...[
                          Text(
                            'Open order',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIconsRegular.arrowRight,
                            size: 15,
                            color: cs.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({
    required this.icon,
    required this.unread,
    required this.name,
    required this.image,
  });

  final IconData icon;
  final bool unread;
  final String name;
  final String image;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 46,
        height: 46,
        child: image.isEmpty
            ? ColoredBox(
                color: unread
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                child: Center(
                  child: name == 'System Update'
                      ? Icon(
                          icon,
                          size: 21,
                          color: unread
                              ? cs.onPrimaryContainer
                              : cs.onSurfaceVariant,
                        )
                      : Text(
                          initial,
                          style: TextStyle(
                            color: unread
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                ),
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: unread
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: unread
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : ColoredBox(
                        color: cs.surfaceContainerHighest,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
              ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected ? cs.primaryContainer : cs.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _NotificationLoading extends StatelessWidget {
  const _NotificationLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: CircularProgressIndicator(color: cs.primary),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsRegular.warningCircle,
                size: 42,
                color: cs.error,
              ),
              const SizedBox(height: 14),
              Text(
                'Could not load notifications',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 17),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 38),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 27, color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
