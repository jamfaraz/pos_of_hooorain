import 'package:flutter/material.dart';

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var index = 0; index < tabs.length; index++)
          ChoiceChip(
            label: Text(tabs[index]),
            selected: index == selectedIndex,
            onSelected: (_) => onChanged(index),
            showCheckmark: false,
            selectedColor: scheme.primaryContainer,
            labelStyle: TextStyle(
              color: index == selectedIndex
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: index == selectedIndex
                  ? scheme.primaryContainer
                  : Theme.of(context).dividerColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }
}
