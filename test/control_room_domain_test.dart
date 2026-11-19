import 'package:flutter_test/flutter_test.dart';
import 'package:hoorain_pos/models/offer_record.dart';
import 'package:hoorain_pos/models/product_record.dart';
import 'package:hoorain_pos/models/order_record.dart';
import 'package:hoorain_pos/utils/pricing.dart';
import 'package:hoorain_pos/utils/profit_analysis.dart';
import 'package:hoorain_pos/utils/rider_pay.dart';

void main() {
  group('product compatibility', () {
    test('maps legacy price, image, stock, flags and bulk pricing', () {
      final product = ProductRecord.fromMap({
        'name': 'Rice',
        'price': 120,
        'imageUrl': 'cover.jpg',
        'totalQuantity': 8,
        'isFeatured': true,
        'isHide': true,
        'bulkPricing': {'10': 110},
      }, id: 'rice');

      expect(product.homePrice, 120);
      expect(product.shopPrice, 120);
      expect(product.images, ['cover.jpg']);
      expect(product.stock, 8);
      expect(product.featured, isTrue);
      expect(product.active, isFalse);
      expect(product.showForHomeUsers, isTrue);
      expect(product.showForShopOwners, isTrue);
      expect(product.tiers.single['qty'], 10);
      expect(product.tiers.single['homePrice'], 110);
    });

    test(
      'customer panel visibility defaults on and persists independently',
      () {
        final legacy = ProductRecord.fromMap({'name': 'Rice'});
        final product = legacy.copyWith(
          showForHomeUsers: false,
          showForShopOwners: true,
        );
        final restored = ProductRecord.fromMap(product.toMap());

        expect(restored.showForHomeUsers, isFalse);
        expect(restored.showForShopOwners, isTrue);
        expect(restored.isAvailableForCustomerType('home'), isFalse);
        expect(restored.isAvailableForCustomerType('shop'), isTrue);
      },
    );
  });

  group('unitPrice', () {
    final product = ProductRecord(
      id: 'rice',
      name: 'Rice',
      homePrice: 120,
      shopPrice: 115,
      cost: 90,
      bulkEnabled: true,
      tiers: [
        {'qty': 5, 'homePrice': 110, 'shopPrice': 105},
        {'qty': 10, 'homePrice': 100, 'shopPrice': 95},
      ],
    );

    test(
      'applies audience-specific bulk tier before the best eligible offer',
      () {
        final offer = OfferRecord(
          name: 'Weekend',
          type: 'pct',
          value: 10,
          productIds: const ['rice'],
          audience: 'shop',
          live: true,
          endsAt: DateTime(2030),
        );

        expect(
          unitPrice(
            product: product,
            shopCustomer: false,
            quantity: 6,
            now: DateTime(2026),
          ),
          110,
        );
        expect(
          unitPrice(
            product: product,
            shopCustomer: true,
            quantity: 10,
            offers: [offer],
            now: DateTime(2026),
          ),
          85.5,
        );
      },
    );

    test('ignores expired or ineligible offers', () {
      final expired = OfferRecord(
        name: 'Expired',
        type: 'rs',
        value: 25,
        productIds: const ['rice'],
        audience: 'home',
        live: true,
        endsAt: DateTime(2025),
      );
      expect(
        unitPrice(
          product: product,
          shopCustomer: false,
          quantity: 1,
          offers: [expired],
          now: DateTime(2026),
        ),
        120,
      );
    });
  });

  test('riderNetPay includes bonus and allowances and subtracts advance', () {
    expect(
      riderNetPay(
        baseSalary: 30000,
        deliveries: 20,
        perDeliveryBonus: 25,
        fuelAllowance: 5000,
        advance: 2000,
      ),
      33500,
    );
  });

  test('profit uses each sale line costAtSale, not current product cost', () {
    final totals = calculateProfitTotals([
      OrderRecord(
        number: 'B-1',
        items: const [
          OrderLineRecord(
            productId: 'rice',
            name: 'Rice',
            qty: 2,
            unitPrice: 120,
            costAtSale: 80,
          ),
        ],
      ),
    ]);

    expect(totals.units, 2);
    expect(totals.sales, 240);
    expect(totals.cost, 160);
    expect(totals.profit, 80);
  });
}
