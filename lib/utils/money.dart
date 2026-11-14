import 'package:intl/intl.dart';

abstract final class Money {
  static final NumberFormat _format = NumberFormat('#,##,##0.##', 'en_IN');

  static String rs(num amount) => 'Rs ${_format.format(amount)}';
}
