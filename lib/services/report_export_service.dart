import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class ReportExportService {
  Future<String?> export(
    String title,
    Map<String, List<List<String>>> sections,
  ) async {
    final rows = <List<String>>[
      [title],
      ['Generated ${DateTime.now().toLocal()}'],
      [],
      for (final section in sections.entries) ...[
        [section.key],
        ...section.value,
        [],
      ],
    ];
    final content = rows.map((row) => row.map(_escape).join(',')).join('\r\n');
    return FilePicker.saveFile(
      fileName: 'Hoorain-Reports.csv',
      bytes: Uint8List.fromList(utf8.encode(content)),
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
  }

  String _escape(String value) => '"${value.replaceAll('"', '""')}"';
}
