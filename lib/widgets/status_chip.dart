import 'package:flutter/material.dart';

enum StatusTone { good, warn, bad, info, primary }

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    this.tone = StatusTone.primary,
    super.key,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (background, foreground) = switch (tone) {
      StatusTone.good => isDark
          ? (const Color(0xFF10301A), const Color(0xFF34D399))
          : (const Color(0xFFE1F4E5), const Color(0xFF006300)),
      StatusTone.warn => isDark
          ? (const Color(0xFF33270B), const Color(0xFFFBBF24))
          : (const Color(0xFFFFF1D1), const Color(0xFF8A5300)),
      StatusTone.bad => isDark
          ? (const Color(0xFF3A1A1A), const Color(0xFFFF6B6B))
          : (const Color(0xFFFBE8E8), const Color(0xFFD03B3B)),
      StatusTone.info => isDark
          ? (const Color(0xFF15243F), const Color(0xFF7AA7FF))
          : (const Color(0xFFE7EEFD), const Color(0xFF2563EB)),
      StatusTone.primary => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
