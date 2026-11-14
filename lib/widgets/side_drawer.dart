import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SideDrawer extends StatelessWidget {
  const SideDrawer({
    required this.title,
    required this.body,
    this.footer,
    this.subtitle,
    this.width = 640,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;
  final double width;

  static Future<T?> show<T>(SideDrawer drawer) {
    return showDialog<T>(
      context: Get.context!,
      barrierDismissible: true,
      builder: (_) => drawer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = math.min(width, MediaQuery.sizeOf(context).width - 32);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): _CloseDrawerIntent(),
      },
      child: Actions(
        actions: {
          _CloseDrawerIntent: CallbackAction<_CloseDrawerIntent>(
            onInvoke: (_) {
              Navigator.of(context).maybePop();
              return null;
            },
          ),
        },
        child: Dialog(
          alignment: Alignment.centerRight,
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 18,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: drawerWidth,
              maxHeight: MediaQuery.sizeOf(context).height - 32,
            ),
            child: SizedBox(
              width: drawerWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(PhosphorIconsRegular.x),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: body,
                    ),
                  ),
                  if (footer != null) ...[
                    const Divider(height: 1),
                    Padding(padding: const EdgeInsets.all(20), child: footer),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseDrawerIntent extends Intent {
  const _CloseDrawerIntent();
}
