import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/user_detail_controller.dart';
import '../../models/order_model.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/full_image.dart';
import '../../widgets/retry_widget.dart';

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

String _text(Object? value) => value == null ? '' : '$value'.trim();

String _or(String value, [String fallback = 'Not provided']) =>
    value.isEmpty ? fallback : value;

typedef _StatusInfo = ({String label, Color color});

_StatusInfo _statusInfo(ColorScheme cs, String status) => switch (status) {
  UserDetailController.verified => (label: 'Verified', color: cs.primary),
  UserDetailController.rejected => (label: 'Rejected', color: cs.error),
  _ => (label: 'Not verified', color: cs.secondary),
};

Color _orderColor(ColorScheme cs, String status) {
  final s = status.toLowerCase();
  if (s.contains('cancel') || s.contains('return')) {
    return cs.error;
  }
  if (s.contains('deliver') || s.contains('complete')) return cs.primary;
  if (s.contains('pending')) return cs.secondary;
  return cs.onSurfaceVariant;
}

String _currentStatus(Map<String, dynamic> data) {
  final value = _text(data['profileStatus']);
  return value.isEmpty ? UserDetailController.notVerified : value;
}

BoxDecoration _panel(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: theme.dividerColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

Future<void> _changeStatus(
  BuildContext context,
  UserDetailController c,
  String current,
  String value,
) async {
  if (current == value) return;
  final cs = Theme.of(context).colorScheme;
  final title = UserDetailController.labelFor(value);
  final message = switch (value) {
    UserDetailController.verified =>
      'This customer will be able to place cash on delivery orders.',
    UserDetailController.rejected =>
      'This customer will not be able to use cash on delivery.',
    _ => 'This customer will need another review before cash on delivery.',
  };

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Mark as $title?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: value == UserDetailController.rejected
              ? FilledButton.styleFrom(backgroundColor: cs.error)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  if (ok == true) await c.setStatus(value);
}

// ----------------------------------------------------------------------------
// Screen
// ----------------------------------------------------------------------------

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final UserDetailController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(UserDetailController(widget.userId), tag: widget.userId);
  }

  @override
  void dispose() {
    Get.delete<UserDetailController>(tag: widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      topBarLeading: const _DetailTopBar(),
      child: SafeArea(
        child: Obx(() {
          if (c.loading.value && c.user.value == null) {
            return const AppLoader(label: 'Loading customer details...');
          }
          if (c.error.value != null) {
            return ErrorRetryWidget(
              errorMessage: c.error.value!,
              onRetry: () => c.load(),
            );
          }
          final data = c.user.value;
          if (data == null) return const _NotFound();
          return _Content(c: c, data: data);
        }),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Back to customers',
          onPressed: Get.back,
          icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 19),
        ),
        const SizedBox(width: 8),
        Text(
          'Customer profile',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.userMinus,
            size: 44,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text('Customer not found', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'This account may have been deleted.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Go back',
            style: AppButtonStyle.ghost,
            small: true,
            icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 16),
            onPressed: Get.back,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Page layout
// ----------------------------------------------------------------------------

class _Content extends StatelessWidget {
  const _Content({required this.c, required this.data});

  final UserDetailController c;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = _or(_text(data['fullName']), 'Unnamed customer');

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 1080;
        final pad = box.maxWidth >= 720 ? 32.0 : 16.0;

        final main = <Widget>[
          _PhotoViewer(
            locationUrl: _text(data['locationImage']),
            profileUrl: _text(data['image']),
          ),
          const SizedBox(height: 22),
          _AddressCard(c: c),
        ];
        final side = <Widget>[
          _ChecklistCard(data: data),
          const SizedBox(height: 22),
          _StatsGrid(c: c),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(name: name),
                  const SizedBox(height: 20),
                  _IdentityStrip(c: c, data: data),
                  const SizedBox(height: 22),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: main,
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: side,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [...main, const SizedBox(height: 22), ...side],
                    ),
                  const SizedBox(height: 22),
                  _OrdersTable(c: c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Text(
          'Customers',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(PhosphorIconsRegular.caretRight, size: 13, color: muted),
        ),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Identity strip with the decision buttons
// ----------------------------------------------------------------------------

class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({required this.c, required this.data});

  final UserDetailController c;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final name = _or(_text(data['fullName']), 'Unnamed customer');
    final current = _currentStatus(data);
    final status = _statusInfo(cs, current);
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : null;

    final meta = <String>[
      if (_text(data['uniqueId']).isNotEmpty) _text(data['uniqueId']),
      if (_text(data['email']).isNotEmpty) _text(data['email']),
      if (_text(data['phoneNumber']).isNotEmpty) _text(data['phoneNumber']),
      if (createdAt != null)
        'Joined ${DateFormat('d MMM yyyy').format(createdAt)}',
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final stacked = box.maxWidth < 960;
        final profile = Row(
          children: [
            _Avatar(
              url: _text(data['image']),
              name: name,
              size: stacked ? 56 : 68,
            ),
            SizedBox(width: stacked ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: stacked ? 20 : 26,
                        ),
                      ),
                      _Pill(label: status.label, color: status.color),
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in meta) _MetaTag(label: item),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(stacked ? 16 : 22),
          decoration: _panel(context),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    profile,
                    const SizedBox(height: 18),
                    Divider(height: 1, color: theme.dividerColor),
                    const SizedBox(height: 16),
                    _DecisionButtons(c: c, current: current),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: profile),
                    const SizedBox(width: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: _DecisionButtons(c: c, current: current),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({required this.c, required this.current});

  final UserDetailController c;
  final String current;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final busy = c.updatingStatus.value;
      final locked = busy != null;

      final reject = OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withValues(alpha: 0.45)),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: locked || current == UserDetailController.rejected
            ? null
            : () => _changeStatus(
                context,
                c,
                current,
                UserDetailController.rejected,
              ),
        child: Text(
          busy == UserDetailController.rejected ? 'Saving…' : 'Reject',
        ),
      );
      final pending = AppButton(
        label: busy == UserDetailController.notVerified
            ? 'Saving…'
            : 'Keep pending',
        style: AppButtonStyle.ghost,
        onPressed: locked || current == UserDetailController.notVerified
            ? null
            : () => _changeStatus(
                context,
                c,
                current,
                UserDetailController.notVerified,
              ),
      );
      final approve = AppButton(
        label: busy == UserDetailController.verified
            ? 'Saving…'
            : current == UserDetailController.verified
            ? 'Verified'
            : 'Approve & enable cash on delivery',
        icon: Icon(
          current == UserDetailController.verified
              ? PhosphorIconsFill.sealCheck
              : PhosphorIconsRegular.shieldCheck,
          size: 18,
        ),
        onPressed: locked || current == UserDetailController.verified
            ? null
            : () => _changeStatus(
                context,
                c,
                current,
                UserDetailController.verified,
              ),
      );

      return LayoutBuilder(
        builder: (context, box) {
          if (box.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: double.infinity, child: approve),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: reject),
                    const SizedBox(width: 10),
                    Expanded(child: pending),
                  ],
                ),
              ],
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [reject, pending, approve],
          );
        },
      );
    });
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.55,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    final fallback = Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: cs.onPrimaryContainer,
        ),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : fallback,
              ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Photo viewer
// ----------------------------------------------------------------------------

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.locationUrl, required this.profileUrl});

  final String locationUrl;
  final String profileUrl;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final photos = <({String title, String url, IconData icon})>[
      (
        title: 'Location photo',
        url: widget.locationUrl,
        icon: PhosphorIconsRegular.mapPin,
      ),
      (
        title: 'Profile photo',
        url: widget.profileUrl,
        icon: PhosphorIconsRegular.user,
      ),
    ];
    final current = photos[_index];
    final hasImage = current.url.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: _panel(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TabChip(
                          icon: photos[i].icon,
                          label: photos[i].title,
                          selected: i == _index,
                          onTap: () => setState(() => _index = i),
                        ),
                      ),
                  ],
                ),
                AppButton(
                  label: 'View full size',
                  style: AppButtonStyle.ghost,
                  small: true,
                  icon: const Icon(
                    PhosphorIconsRegular.arrowsOutSimple,
                    size: 15,
                  ),
                  onPressed: hasImage
                      ? () =>
                            Get.to(() => FullImageScreen(imageUrl: current.url))
                      : null,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.all(18),
            child: AspectRatio(
              aspectRatio: 1.78,
              child: _PhotoSurface(url: current.url, caption: current.title),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Row(
              children: [
                for (var i = 0; i < photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _Thumb(
                      url: photos[i].url,
                      selected: i == _index,
                      label: photos[i].title,
                      onTap: () => setState(() => _index = i),
                      fallbackColor: cs.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoSurface extends StatelessWidget {
  const _PhotoSurface({required this.url, required this.caption});

  final String url;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasImage = url.isNotEmpty;

    Widget empty(IconData icon, String text) => Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return MouseRegion(
      cursor: hasImage ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: hasImage
            ? () => Get.to(() => FullImageScreen(imageUrl: url))
            : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!hasImage)
                empty(PhosphorIconsRegular.imageSquare, 'No photo uploaded')
              else
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    final total = progress.expectedTotalBytes;
                    return Container(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: total == null
                              ? null
                              : progress.cumulativeBytesLoaded / total,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => empty(
                    PhosphorIconsRegular.imageBroken,
                    'Could not load photo',
                  ),
                ),
              if (hasImage)
                Positioned(
                  left: 16,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      caption,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.fallbackColor,
  });

  final String url;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 120,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? cs.primary : theme.dividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isEmpty
                ? Container(
                    color: fallbackColor,
                    alignment: Alignment.center,
                    child: Icon(
                      PhosphorIconsRegular.imageSquare,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: fallbackColor),
                  ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Delivery address (latest order)
// ----------------------------------------------------------------------------

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.c});

  final UserDetailController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Obx(() {
      final latest = c.lastOrder;
      final address = latest?.deliveryAddress.trim() ?? '';
      final loading = c.ordersLoading.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _panel(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIconsRegular.mapPin,
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery address on the latest order',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loading
                        ? 'Loading...'
                        : address.isEmpty
                        ? 'No orders with an address yet.'
                        : address,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: address.isEmpty ? cs.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compare this with the location photo before approving.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ----------------------------------------------------------------------------
// Checklist
// ----------------------------------------------------------------------------

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final checks = <(String, bool)>[
      ('Profile photo', _text(data['image']).isNotEmpty),
      ('Location photo', _text(data['locationImage']).isNotEmpty),
      ('Phone number', _text(data['phoneNumber']).isNotEmpty),
      ('Email address', _text(data['email']).isNotEmpty),
    ];
    final done = checks.where((e) => e.$2).length;
    final missing = checks.where((e) => !e.$2).map((e) => e.$1).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _panel(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'REVIEW CHECKLIST',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '$done of ${checks.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: done / checks.length,
              minHeight: 6,
              backgroundColor: theme.dividerColor,
            ),
          ),
          const SizedBox(height: 14),
          for (final check in checks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    check.$2
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    size: 22,
                    color: check.$2
                        ? cs.primary
                        : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    check.$1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: check.$2 ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.secondary.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Still missing: ${missing.join(', ').toLowerCase()}. You can still make a decision.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Stats
// ----------------------------------------------------------------------------

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.c});

  final UserDetailController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = c.ordersLoading.value;
      final last = c.lastOrder;

      final tiles = <(String, String)>[
        ('Orders', loading ? '...' : '${c.orders.length}'),
        ('Total spent', loading ? '...' : Money.rs(c.totalSpent)),
        ('Average order', loading ? '...' : Money.rs(c.averageOrder)),
        (
          'Last order',
          loading
              ? '...'
              : last == null
              ? 'None yet'
              : DateFormat('d MMM yyyy').format(last.orderDate),
        ),
      ];

      return LayoutBuilder(
        builder: (context, box) {
          const gap = 12.0;
          final width = (box.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: width,
                  child: _MiniKpi(label: tile.$1, value: tile.$2),
                ),
            ],
          );
        },
      );
    });
  }
}

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// Order history table
// ----------------------------------------------------------------------------

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.c});

  final UserDetailController c;

  static const _shown = 8;
  static const _flex = [12, 16, 8, 12, 10, 10];
  static const _headers = [
    'ORDER',
    'DATE',
    'ITEMS',
    'PAYMENT',
    'TOTAL',
    'STATUS',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Obx(() {
      final loading = c.ordersLoading.value;
      final orders = c.orders;
      final recent = orders.take(_shown).toList();

      return Container(
        width: double.infinity,
        decoration: _panel(context),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order history',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading
                        ? 'Loading orders...'
                        : orders.length > _shown
                        ? 'Latest $_shown of ${orders.length} orders'
                        : '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: AppLoader(label: 'Loading orders...'),
              )
            else if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.package,
                        size: 34,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No orders yet',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Orders this customer places will show up here.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth < 720) {
                    return Column(
                      children: [
                        for (final order in recent)
                          _CompactOrderCard(order: order),
                      ],
                    );
                  }
                  final width = math.max(box.maxWidth, 760.0);
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          Container(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.45,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 12,
                            ),
                            child: _row([
                              for (final h in _headers)
                                Text(
                                  h,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                            ]),
                          ),
                          for (final order in recent)
                            _OrderRow(order: order, row: _row),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    });
  }

  static Widget _row(List<Widget> cells) => Row(
    children: [
      for (var i = 0; i < cells.length; i++) ...[
        Expanded(flex: _flex[i], child: cells[i]),
        if (i != cells.length - 1) const SizedBox(width: 12),
      ],
    ],
  );
}

class _CompactOrderCard extends StatelessWidget {
  const _CompactOrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final payment = _or(order.paymentMethod.trim(), 'Payment not specified');

    Widget detail(IconData icon, String label, {int maxWidth = 250}) =>
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth.toDouble()),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(label: order.status, color: _orderColor(cs, order.status)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              detail(
                PhosphorIconsRegular.calendarBlank,
                DateFormat('d MMM yyyy, h:mm a').format(order.orderDate),
                maxWidth: 250,
              ),
              detail(
                PhosphorIconsRegular.package,
                '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
                maxWidth: 120,
              ),
              detail(PhosphorIconsRegular.creditCard, payment, maxWidth: 230),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Order total',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                Money.rs(order.total),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.row});

  final OrderModel order;
  final Widget Function(List<Widget> cells) row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final payment = order.paymentMethod.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: row([
        Text(
          '#${order.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          DateFormat('d MMM yyyy, h:mm a').format(order.orderDate),
          style: theme.textTheme.bodyMedium,
        ),
        Text('${order.items.length}', style: theme.textTheme.bodyMedium),
        Text(
          _or(payment, '-'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          Money.rs(order.total),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: _Pill(
            label: order.status,
            color: _orderColor(cs, order.status),
          ),
        ),
      ]),
    );
  }
}
