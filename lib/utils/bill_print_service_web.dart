import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

Future<bool> printReceiptPdf({
  required Uint8List bytes,
  required PdfPageFormat format,
}) => Printing.layoutPdf(
  name: 'Hoorain bill',
  format: format,
  dynamicLayout: false,
  onLayout: (_) async => bytes,
);
