import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'common_dialog.dart';

class ConfirmTapButton extends StatelessWidget {
  const ConfirmTapButton({
    required this.label,
    required this.onConfirmed,
    this.confirmLabel = 'Confirm',
    this.confirmTitle,
    this.confirmMessage,
    this.danger = true,
    this.icon,
    this.filled = false,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String confirmLabel;
  final String? confirmTitle;
  final String? confirmMessage;
  final VoidCallback onConfirmed;
  final bool danger;
  final IconData? icon;
  final bool filled;
  final bool enabled;

  Future<void> _confirm(BuildContext context) async {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: confirmTitle ?? 'Confirm ${label.toLowerCase()}',
      message:
          confirmMessage ??
          'Are you sure you want to continue? This action may not be reversible.',
      icon: icon ?? PhosphorIconsRegular.warningCircle,
      iconColor: color,
      positiveButtonText: confirmLabel,
    );
    if (confirmed == true) onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final color = danger ? Theme.of(context).colorScheme.error : null;
    return OutlinedButton(
      onPressed: enabled ? () => _confirm(context) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: filled && danger
            ? color?.withValues(alpha: 0.09)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(
          color: filled && danger
              ? (color ?? Theme.of(context).colorScheme.error).withValues(
                  alpha: 0.14,
                )
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
  }
}
