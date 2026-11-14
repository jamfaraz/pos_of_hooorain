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
    super.key,
  });

  final List<DataColumn2> columns;
  final List<DataRow> rows;
  final double minWidth;
  final String emptyTitle;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return emptyState ?? EmptyState(title: emptyTitle);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < minWidth
                ? minWidth
                : constraints.maxWidth,
            child: DataTable2(
              columns: columns,
              rows: rows,
              minWidth: minWidth,
              fixedTopRows: 1,
              headingRowHeight: 48,
              dataRowHeight: 58,
              horizontalMargin: 16,
              columnSpacing: 16,
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
