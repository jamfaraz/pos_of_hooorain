import 'package:flutter/material.dart';

class AppLoader extends StatelessWidget {
  const AppLoader({this.label = 'Loading...', this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = SizedBox(
      width: compact ? 18 : 24,
      height: compact ? 18 : 24,
      child: CircularProgressIndicator(
        strokeWidth: compact ? 2 : 2.5,
        color: theme.colorScheme.primary,
      ),
    );
    if (compact) return indicator;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
