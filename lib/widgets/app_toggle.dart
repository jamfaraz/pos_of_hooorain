import 'package:flutter/material.dart';

class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    this.label,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final toggle = Switch.adaptive(value: value, onChanged: onChanged);
    if (label == null) return toggle;
    return Semantics(
      label: label,
      toggled: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          toggle,
        ],
      ),
    );
  }
}
