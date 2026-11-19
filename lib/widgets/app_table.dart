import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import 'empty_state.dart';

class AppTable extends StatelessWidget {
  const AppTable({
    required this.columns,
    required this.rows,
    this.minWidth = 720,
    this.emptyTitle = 'Nothing here yet',
    this.emptyState,
    this.headingRowHeight = 48,
    this.dataRowHeight = 58,
    this.horizontalMargin = 16,
    this.columnSpacing = 16,
    super.key,
  });

  final List<DataColumn2> columns;
  final List<DataRow> rows;
  final double minWidth;
  final String emptyTitle;
  final Widget? emptyState;
  final double headingRowHeight;
  final double dataRowHeight;
  final double horizontalMargin;
  final double columnSpacing;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return emptyState ?? EmptyState(title: emptyTitle);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : headingRowHeight + dataRowHeight * rows.length;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < minWidth
                ? minWidth
                : constraints.maxWidth,
            height: tableHeight,
            child: DataTable2(
              columns: columns,
              rows: rows,
              minWidth: minWidth,
              fixedTopRows: 1,
              headingRowHeight: headingRowHeight,
              dataRowHeight: dataRowHeight,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              headingRowColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        );
      },
    );
  }
}
