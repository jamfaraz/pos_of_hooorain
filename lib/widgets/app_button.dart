import 'package:flutter/material.dart';

enum AppButtonStyle { primary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.small = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final Widget? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = EdgeInsets.symmetric(
      horizontal: small ? 12 : 16,
      vertical: small ? 9 : 13,
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(label),
      ],
    );

    return switch (style) {
      AppButtonStyle.primary => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(padding: padding),
        child: child,
      ),
      AppButtonStyle.ghost => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          side: BorderSide(color: theme.dividerColor),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
      AppButtonStyle.danger => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    };
  }
}
