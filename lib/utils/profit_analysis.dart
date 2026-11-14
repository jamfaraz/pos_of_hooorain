import '../models/order_record.dart';

class ProfitTotals {
  const ProfitTotals({this.units = 0, this.sales = 0, this.cost = 0});

  final int units;
  final double sales;
  final double cost;
  double get profit => sales - cost;
  double get margin => sales == 0 ? 0 : profit / sales * 100;
}

ProfitTotals calculateProfitTotals(Iterable<OrderRecord> orders) {
  var units = 0;
  var sales = 0.0;
  var cost = 0.0;
  for (final order in orders) {
    for (final line in order.items) {
      units += line.qty;
      sales += line.unitPrice * line.qty;
      cost += line.costAtSale * line.qty;
    }
  }
  return ProfitTotals(units: units, sales: sales, cost: cost);
}
