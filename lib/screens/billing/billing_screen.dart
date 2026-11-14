import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/billing_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';

class BillingScreen extends GetView<BillingController> {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.error.value != null &&
        controller.loading.value &&
        controller.products.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }
    if (controller.loading.value) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: AppLoader(label: 'Loading products...'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Billing',
          subtitle: 'Create a counter bill with sale-time cost snapshots.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'home', label: Text('Home user')),
                  ButtonSegment(value: 'shop', label: Text('Shop owner')),
                ],
                selected: {controller.customerType.value},
                onSelectionChanged: (value) {
                  controller.customerType.value = value.first;
                  for (final line in controller.cart.toList()) {
                    final product = controller.products
                        .where((item) => item.id == line.productId)
                        .firstOrNull;
                    if (product != null) {
                      controller.changeQuantity(line, line.qty);
                    }
                  }
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CommonDropdown<String>(
                      label: 'Product',
                      hint: 'Select product',
                      bottomSpacing: 0,
                      value: controller.selectedProductId.value,
                      items: controller.products
                          .map(
                            (product) => DropdownMenuItem(
                              value: product.id,
                              child: Text(
                                '${product.name} · ${Money.rs(product.homePrice)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          controller.selectedProductId.value = value,
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Add item',
                    icon: const Icon(PhosphorIconsRegular.plus),
                    onPressed: controller.addSelectedProduct,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (controller.cart.isEmpty)
          const EmptyState(title: 'Add products to start a bill')
        else
          AppCard(
            child: Column(
              children: [
                for (final line in controller.cart)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.name),
                    subtitle: Text('${Money.rs(line.unitPrice)} each'),
                    leading: IconButton(
                      tooltip: 'Remove one',
                      onPressed: () =>
                          controller.changeQuantity(line, line.qty - 1),
                      icon: const Icon(PhosphorIconsRegular.minus),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${line.qty}'),
                        IconButton(
                          tooltip: 'Add one',
                          onPressed: () =>
                              controller.changeQuantity(line, line.qty + 1),
                          icon: const Icon(PhosphorIconsRegular.plus),
                        ),
                        Text(Money.rs(line.qty * line.unitPrice)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            KpiCard(label: 'Subtotal', value: Money.rs(controller.subtotal)),
            KpiCard(label: 'Bill total', value: Money.rs(controller.total)),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: controller.discountController,
                  decoration: const InputDecoration(labelText: 'Discount (Rs)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => controller.cart.refresh(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: controller.deliveryController,
                  decoration: const InputDecoration(labelText: 'Delivery (Rs)'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => controller.cart.refresh(),
                ),
              ),
            ],
          ),
        ),
        if (controller.error.value != null) ...[
          const SizedBox(height: 12),
          Text(
            controller.error.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: controller.saving.value ? 'Saving bill…' : 'Complete bill',
            icon: const Icon(PhosphorIconsRegular.check),
            onPressed: controller.saving.value || controller.cart.isEmpty
                ? null
                : _checkout,
          ),
        ),
      ],
    );
  });

  Future<void> _checkout() async {
    try {
      final id = await controller.checkout();
      if (id != null) {
        Get.snackbar('Bill created', 'Bill #$id was saved.');
      }
    } catch (exception) {
      Get.snackbar('Could not complete bill', exception.toString());
    }
  }
}
