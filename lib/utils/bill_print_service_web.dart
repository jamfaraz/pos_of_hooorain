import 'dart:async';
import 'dart:js_interop';

@JS('window.open')
external _PrintWindow? _openPrintWindow(String url, String target);

@JS()
extension type _PrintWindow(JSObject _) implements JSObject {
  external _PrintDocument get document;
  external void focus();
  external void print();
}

@JS()
extension type _PrintDocument(JSObject _) implements JSObject {
  external void open();
  external void write(String content);
  external void close();
}

Future<bool> printReceiptHtml(String receiptHtml) async {
  final window = _openPrintWindow('about:blank', '_blank');
  if (window == null) return false;

  window.document
    ..open()
    ..write(receiptHtml)
    ..close();
  window.focus();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  window.print();
  return true;
}
