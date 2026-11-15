import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Theme-aware shimmer block. Use it to build skeletons that match a layout.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({this.width, this.height = 16, this.radius = 10, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1C2A24) : const Color(0xFFE6EDE9),
      highlightColor: dark ? const Color(0xFF26372F) : const Color(0xFFF6F9F8),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// KPI card placeholders.
class ShimmerKpiRow extends StatelessWidget {
  const ShimmerKpiRow({this.count = 4, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final cols = c.maxWidth > 1000
          ? count
          : c.maxWidth > 620
          ? 2
          : 1;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < count; i++)
            ShimmerBox(width: w, height: 104, radius: 16),
        ],
      );
    },
  );
}

/// Table placeholder: a header bar and [rows] rows.
class ShimmerTable extends StatelessWidget {
  const ShimmerTable({this.rows = 7, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const ShimmerBox(height: 44, radius: 12),
      for (var i = 0; i < rows; i++) ...[
        const SizedBox(height: 10),
        const ShimmerBox(height: 52, radius: 12),
      ],
    ],
  );
}
