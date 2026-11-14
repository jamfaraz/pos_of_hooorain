import 'package:flutter/material.dart';

import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';

class ControlRoomPlaceholder extends StatelessWidget {
  const ControlRoomPlaceholder({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(title: title, subtitle: description),
        SizedBox(
          height: 320,
          child: EmptyState(
            title: '$title is part of the next phase',
            message: 'Your existing data and screens have not been changed.',
          ),
        ),
      ],
    );
  }
}
