import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/order_record.dart';
import 'money.dart';

class ReceiptPdf {
  const ReceiptPdf({required this.bytes, required this.format});

  final Uint8List bytes;
  final PdfPageFormat format;
}

Future<ReceiptPdf> buildReceiptPdf({
  required String billNumber,
  required String customer,
  required String phone,
  required DateTime date,
  required List<OrderLineRecord> items,
  required double subtotal,
  required double discount,
  required double delivery,
  required double total,
  required String paymentMethod,
}) async {
  const rollWidthMm = 58.0;
  const horizontalMarginMm = 4.0;
  final nameLines = items.fold<int>(
    0,
    (sum, line) => sum + math.max(1, (line.name.length / 12).ceil()),
  );
  final customerLines = math.max(1, (customer.length / 25).ceil());
  final phoneLines = phone.isEmpty
      ? 0
      : math.max(1, (phone.length / 25).ceil());
  final heightMm = math.max(
    100.0,
    72 +
        customerLines * 4 +
        phoneLines * 4 +
        items.length * 5 +
        nameLines * 3.5,
  );
  final format = PdfPageFormat(
    rollWidthMm * PdfPageFormat.mm,
    heightMm * PdfPageFormat.mm,
    marginAll: horizontalMarginMm * PdfPageFormat.mm,
  );
  final document = pw.Document();
  final muted = PdfColors.grey700;
  final border = PdfColors.grey500;
  final dateLabel = DateFormat('dd MMM yyyy, hh:mm a').format(date);
  final bodyStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.black);

  pw.Widget rule() => pw.Container(
    margin: const pw.EdgeInsets.symmetric(vertical: 5),
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: border, width: 0.6)),
    ),
  );

  pw.Widget infoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 46, child: pw.Text('$label:', style: bodyStyle)),
        pw.Expanded(child: pw.Text(value, style: bodyStyle)),
      ],
    ),
  );

  pw.Widget totalRow(String label, String value, {bool emphasized = false}) {
    final style = pw.TextStyle(
      fontSize: emphasized ? 11 : 8.5,
      fontWeight: emphasized ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: PdfColors.black,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  document.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.all(horizontalMarginMm * PdfPageFormat.mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'HOORAIN',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'COUNTER BILL',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
          rule(),
          infoRow('Bill No.', billNumber),
          infoRow('Date', dateLabel),
          infoRow('Customer', customer),
          if (phone.isNotEmpty) infoRow('Phone', phone),
          rule(),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FixedColumnWidth(18),
              2: pw.FixedColumnWidth(40),
              3: pw.FixedColumnWidth(44),
            },
            children: [
              pw.TableRow(
                children: [
                  _tableCell('ITEM', bold: true),
                  _tableCell('QTY', align: pw.TextAlign.center, bold: true),
                  _tableCell('PRICE', align: pw.TextAlign.right, bold: true),
                  _tableCell('TOTAL', align: pw.TextAlign.right, bold: true),
                ],
              ),
              for (final line in items)
                pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.middle,
                  children: [
                    _tableCell(line.name),
                    _tableCell('${line.qty}', align: pw.TextAlign.center),
                    _tableCell(
                      Money.rs(line.unitPrice),
                      align: pw.TextAlign.right,
                      small: true,
                    ),
                    _tableCell(
                      Money.rs(line.qty * line.unitPrice),
                      align: pw.TextAlign.right,
                      small: true,
                    ),
                  ],
                ),
            ],
          ),
          rule(),
          totalRow('Subtotal', Money.rs(subtotal)),
          totalRow('Service charges', 'Rs 0'),
          totalRow('Discount', '- ${Money.rs(discount)}'),
          totalRow('Delivery', Money.rs(delivery)),
          rule(),
          totalRow('TOTAL', Money.rs(total), emphasized: true),
          totalRow('Payment', paymentMethod),
          pw.SizedBox(height: 8),
          pw.Text(
            'Thank you for shopping with us.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
    ),
  );

  return ReceiptPdf(bytes: await document.save(), format: format);
}

pw.Widget _tableCell(
  String text, {
  pw.TextAlign align = pw.TextAlign.left,
  bool bold = false,
  bool small = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 1),
  child: pw.Text(
    text,
    textAlign: align,
    style: pw.TextStyle(
      fontSize: small ? 7 : 8,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);
