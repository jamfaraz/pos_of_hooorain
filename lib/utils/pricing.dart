import '../models/offer_record.dart';
import '../models/product_record.dart';

double unitPrice({
  required ProductRecord product,
  required bool shopCustomer,
  required int quantity,
  Iterable<OfferRecord> offers = const [],
  DateTime? now,
}) {
  final isShop = shopCustomer;
  var price = isShop ? product.shopPrice : product.homePrice;
  if (product.bulkEnabled && quantity > 0) {
    for (final tier in product.tiers) {
      final tierQuantity = (tier['qty'] as num?)?.toInt() ?? 0;
      if (tierQuantity > quantity) break;
      final tierPrice = tier[isShop ? 'shopPrice' : 'homePrice'];
      if (tierPrice is num && tierPrice > 0) price = tierPrice.toDouble();
    }
  }

  final audience = isShop ? 'shop' : 'home';
  final instant = now ?? DateTime.now();
  var bestPrice = price;
  for (final offer in offers) {
    if (!offer.live ||
        !offer.productIds.contains(product.id) ||
        (offer.endsAt != null && !offer.endsAt!.isAfter(instant)) ||
        (offer.audience != 'both' && offer.audience != audience)) {
      continue;
    }
    final discounted = offer.type == 'pct'
        ? price * (1 - offer.value / 100)
        : price - offer.value;
    if (discounted >= 0 && discounted < bestPrice) bestPrice = discounted;
  }
  return bestPrice;
}
