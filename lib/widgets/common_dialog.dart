import 'package:flutter/material.dart';

class CommonDialog extends StatelessWidget {
  const CommonDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.negativeButtonText,
    required this.positiveButtonText,
    required this.onPositiveButtonPressed,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final String negativeButtonText;
  final String positiveButtonText;
  final VoidCallback onPositiveButtonPressed;

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String negativeButtonText = 'Cancel',
    String positiveButtonText = 'Confirm',
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => CommonDialog(
      title: title,
      message: message,
      icon: icon,
      iconColor: iconColor,
      negativeButtonText: negativeButtonText,
      positiveButtonText: positiveButtonText,
      onPositiveButtonPressed: () => Navigator.of(dialogContext).pop(true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 25),
      ),
      iconPadding: const EdgeInsets.only(top: 24),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  foregroundColor: colors.onSurface,
                  side: BorderSide(color: colors.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(negativeButtonText),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: onPositiveButtonPressed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: iconColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(positiveButtonText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
