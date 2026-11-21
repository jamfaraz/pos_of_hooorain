import '../models/order_record.dart';

bool countsAsDashboardSale(OrderRecord order) {
  final status = order.status.trim().toLowerCase();
  return !{'cancelled', 'canceled', 'rejected', 'returned'}.contains(status);
}

double knownCostSales(OrderRecord order) {
  if (!countsAsDashboardSale(order)) return 0;
  return order.items
      .where((line) => line.costAtSale > 0 && line.qty > 0)
      .fold(0.0, (total, line) => total + line.unitPrice * line.qty);
}

double knownCostProfit(OrderRecord order) {
  if (!countsAsDashboardSale(order)) return 0;
  return order.items
      .where((line) => line.costAtSale > 0 && line.qty > 0)
      .fold(
        0.0,
        (total, line) => total + (line.unitPrice - line.costAtSale) * line.qty,
      );
}

class DashboardTopSeller {
  const DashboardTopSeller({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.sales,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final int quantity;
  final double sales;
  final String? imageUrl;
}

List<DashboardTopSeller> topSellingItems(
  Iterable<OrderRecord> orders, {
  required DateTime now,
  required int days,
}) {
  final start = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: days - 1));
  final totals = <String, DashboardTopSeller>{};

  for (final order in orders) {
    if (!countsAsDashboardSale(order) || order.orderDate.isBefore(start)) {
      continue;
    }
    for (final line in order.items) {
      if (line.productId.isEmpty || line.qty <= 0) continue;
      final current = totals[line.productId];
      totals[line.productId] = DashboardTopSeller(
        productId: line.productId,
        name: line.productName.isNotEmpty
            ? line.productName
            : current?.name ?? 'Unknown product',
        quantity: (current?.quantity ?? 0) + line.qty,
        sales: (current?.sales ?? 0) + line.unitPrice * line.qty,
        imageUrl: line.imageUrl ?? current?.imageUrl,
      );
    }
  }

  return totals.values.toList()..sort((a, b) {
    final byQuantity = b.quantity.compareTo(a.quantity);
    return byQuantity != 0 ? byQuantity : b.sales.compareTo(a.sales);
  });
}
