import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/offers_controller.dart';
import '../../models/offer_record.dart';
import '../../utils/money.dart';
import '../../utils/pricing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_table.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/multi_image_uploader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/side_drawer.dart';

class OffersScreen extends GetView<OffersController> {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) => Obx(
    () => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Offers',
            subtitle: 'Build product offers and preview customer prices.',
            actions: [
              AppButton(
                label: 'Add offer',
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => _editOffer(context),
              ),
            ],
          ),
          if (controller.loading.value)
            const AppLoader(label: 'Loading offers...')
          else if (controller.error.value != null && controller.offers.isEmpty)
            ErrorRetryWidget(
              errorMessage: controller.error.value!,
              onRetry: controller.reload,
            )
          else if (controller.offers.isEmpty)
            const EmptyState(
              title: 'No offers yet',
              message: 'Create an offer to start promoting products.',
            )
          else ...[
            _preview(context),
            const SizedBox(height: 18),
            SizedBox(
              height: 48.0 + 58.0 * controller.offers.length,
              child: AppTable(
                minWidth: 1050,
                columns: const [
                  DataColumn2(label: Text('Offer'), size: ColumnSize.L),
                  DataColumn2(label: Text('Discount')),
                  DataColumn2(label: Text('Products'), size: ColumnSize.L),
                  DataColumn2(label: Text('Audience')),
                  DataColumn2(label: Text('Ends')),
                  DataColumn2(label: Text('Pinned')),
                  DataColumn2(label: Text('Live')),
                  DataColumn2(label: Text('Actions'), size: ColumnSize.M),
                ],
                rows: controller.offers
                    .map((offer) => _offerRow(context, offer))
                    .toList(),
              ),
            ),
            if (controller.canLoadMore.value)
              TextButton(
                onPressed: controller.loadingMore.value
                    ? null
                    : controller.loadMore,
                child: Text(
                  controller.loadingMore.value
                      ? 'Loading…'
                      : 'Load more offers',
                ),
              ),
          ],
        ],
      ),
    ),
  );

  DataRow _offerRow(BuildContext context, OfferRecord offer) {
    final end = offer.endsAt;
    return DataRow(
      cells: [
        DataCell(
          Text(offer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        DataCell(
          Chip(
            label: Text(
              offer.type == 'pct'
                  ? '${offer.value}% off'
                  : '${Money.rs(offer.value)} off',
            ),
          ),
        ),
        DataCell(Text(controller.productNames(offer))),
        DataCell(Chip(label: Text(offer.audience.toUpperCase()))),
        DataCell(
          Text(
            end == null ? 'No end date' : '${end.day}/${end.month}/${end.year}',
          ),
        ),
        DataCell(
          Switch(
            value: offer.pinned,
            onChanged: (value) =>
                _confirmOfferToggle(context, offer, value, pinned: true),
          ),
        ),
        DataCell(
          Switch(
            value: offer.live,
            onChanged: (value) =>
                _confirmOfferToggle(context, offer, value, pinned: false),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Edit offer',
                onPressed: () => _editOffer(Get.context!, offer),
                icon: const Icon(PhosphorIconsRegular.pencilSimple),
              ),
              ConfirmTapButton(
                label: 'Delete',
                confirmLabel: 'Delete',
                confirmTitle: 'Delete offer?',
                confirmMessage:
                    'Customers will no longer see this offer. This action cannot be undone.',
                onConfirmed: () async {
                  if (offer.id == null) return;
                  try {
                    await controller.delete(offer.id!);
                  } catch (exception) {
                    Get.snackbar(
                      'Could not delete offer',
                      exception.toString(),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmOfferToggle(
    BuildContext context,
    OfferRecord offer,
    bool value, {
    required bool pinned,
  }) async {
    final action = pinned
        ? value
              ? 'Pin offer'
              : 'Unpin offer'
        : value
        ? 'Make live'
        : 'Pause offer';
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: pinned
          ? value
                ? 'Pin offer to home?'
                : 'Remove offer pin?'
          : value
          ? 'Make offer live?'
          : 'Pause this offer?',
      message: pinned
          ? '"${offer.name}" will ${value ? 'appear' : 'no longer appear'} in the pinned home offers.'
          : '"${offer.name}" will ${value ? 'be visible' : 'stop showing'} to customers.',
      icon: PhosphorIconsRegular.megaphone,
      iconColor: Theme.of(context).colorScheme.primary,
      positiveButtonText: action,
    );
    if (confirmed != true) return;
    try {
      await controller.save(
        pinned ? offer.copyWith(pinned: value) : offer.copyWith(live: value),
      );
    } catch (exception) {
      Get.snackbar('Could not update offer', exception.toString());
    }
  }

  Widget _preview(BuildContext context) {
    final isShop = controller.previewAudience.value == 'shop';
    final pinned = controller.offers
        .where(
          (offer) =>
              offer.pinned &&
              offer.live &&
              (offer.endsAt == null || offer.endsAt!.isAfter(DateTime.now())) &&
              (offer.audience == 'both' ||
                  offer.audience == (isShop ? 'shop' : 'home')),
        )
        .take(3);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Home-screen preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        'Pinned, live offers for the selected customer type.',
                      ),
                    ],
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'home', label: Text('Home user')),
                    ButtonSegment(value: 'shop', label: Text('Shop owner')),
                  ],
                  selected: {controller.previewAudience.value},
                  onSelectionChanged: (value) =>
                      controller.previewAudience.value = value.first,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (pinned.isEmpty)
              const EmptyState(title: 'No pinned offers for this audience')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: pinned.map((offer) {
                  final product = controller.products.firstWhereOrNull(
                    (item) => offer.productIds.contains(item.id),
                  );
                  if (product == null) return const SizedBox.shrink();
                  final oldPrice = unitPrice(
                    product: product,
                    shopCustomer: isShop,
                    quantity: 1,
                  );
                  final newPrice = unitPrice(
                    product: product,
                    shopCustomer: isShop,
                    quantity: 1,
                    offers: [offer],
                  );
                  return SizedBox(
                    width: 220,
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.images.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  product.images.first,
                                  height: 90,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              const SizedBox(
                                height: 90,
                                child: Center(
                                  child: Icon(PhosphorIconsRegular.tag),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              offer.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  Money.rs(newPrice),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  Money.rs(oldPrice),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editOffer(BuildContext context, [OfferRecord? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final value = TextEditingController(
      text: existing?.value == 0 ? '' : '${existing?.value}',
    );
    final search = TextEditingController();
    final selected = <String>{...?existing?.productIds}.obs;
    final type = (existing?.type ?? 'pct').obs;
    final audience = (existing?.audience ?? 'both').obs;
    final pinned = (existing?.pinned ?? false).obs;
    final live = (existing?.live ?? false).obs;
    final push = false.obs;
    final endsAt = Rxn<DateTime>(existing?.endsAt);
    final images = <String>[
      if (existing?.imageUrl != null) existing!.imageUrl!,
    ].obs;
    final drawer = SideDrawer(
      title: existing == null ? 'Add offer' : 'Edit offer',
      subtitle: 'Offer prices are recalculated for each audience.',
      body: Obx(() {
        final chosen = controller.products.where(
          (product) => selected.contains(product.id),
        );
        final preview = OfferRecord(
          name: name.text.trim(),
          type: type.value,
          value: double.tryParse(value.text) ?? 0,
          productIds: selected.toList(),
          audience: audience.value,
          endsAt: endsAt.value,
          pinned: pinned.value,
          live: true,
        );
        final warnings = <String>[];
        for (final product in chosen) {
          for (final shopCustomer in [false, true]) {
            if (audience.value != 'both' &&
                (audience.value == 'shop') != shopCustomer) {
              continue;
            }
            final price = unitPrice(
              product: product,
              shopCustomer: shopCustomer,
              quantity: 1,
              offers: [preview],
            );
            if (price < product.cost) {
              warnings.add(
                '${product.name} (${shopCustomer ? 'Shop' : 'Home'}): ${Money.rs(price)} is below cost ${Money.rs(product.cost)}.',
              );
            }
          }
        }
        final query = search.text.trim().toLowerCase();
        final matches = controller.products.where(
          (product) =>
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryTextField(
              controller: name,
              headerText: 'Offer name',
              hintText: 'Enter offer name',
            ),
            const SizedBox(height: 14),
            const Text('Offer image'),
            const SizedBox(height: 8),
            MultiImageUploader(
              maxImages: 1,
              value: images,
              onChanged: (urls) => images.assignAll(urls),
            ),
            const SizedBox(height: 14),
            Obx(
              () => CommonDropdown<String>(
                label: 'Discount type',
                value: type.value,
                bottomSpacing: 0,
                items: const [
                  DropdownMenuItem(value: 'pct', child: Text('Percent off')),
                  DropdownMenuItem(value: 'rs', child: Text('Rs off')),
                ],
                onChanged: (value) {
                  if (value != null) type.value = value;
                },
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: type.value == 'pct'
                    ? 'Percent (1–90)'
                    : 'Amount off (Rs)',
              ),
              onChanged: (_) => selected.refresh(),
            ),
            const SizedBox(height: 14),
            Obx(
              () => CommonDropdown<String>(
                label: 'Audience',
                value: audience.value,
                bottomSpacing: 0,
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Home users')),
                  DropdownMenuItem(value: 'shop', child: Text('Shop owners')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (value) {
                  if (value != null) audience.value = value;
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    endsAt.value == null
                        ? 'No end date'
                        : 'Ends ${endsAt.value!.toLocal().toString().split(' ').first}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          endsAt.value ??
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 5),
                      ),
                    );
                    if (picked != null) endsAt.value = picked;
                  },
                  child: const Text('Choose end date'),
                ),
                if (endsAt.value != null)
                  IconButton(
                    onPressed: () => endsAt.value = null,
                    icon: const Icon(PhosphorIconsRegular.x),
                  ),
              ],
            ),
            const Divider(),
            TextField(
              controller: search,
              decoration: const InputDecoration(
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                labelText: 'Search products',
              ),
              onChanged: (_) => selected.refresh(),
            ),
            const SizedBox(height: 8),
            for (final product in matches)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: selected.contains(product.id),
                title: Text(product.name),
                subtitle: Text(
                  '${product.sku} · Cost ${Money.rs(product.cost)}',
                ),
                onChanged: (checked) {
                  if (product.id == null) return;
                  if (checked == true) {
                    selected.add(product.id!);
                  } else {
                    selected.remove(product.id);
                  }
                },
              ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Below-cost warning',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    warning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pin to home'),
                value: pinned.value,
                onChanged: (value) => pinned.value = value,
              ),
            ),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Live'),
                value: live.value,
                onChanged: (value) => live.value = value,
              ),
            ),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Send push notification'),
                subtitle: const Text(
                  'Requires a trusted server-side FCM sender.',
                ),
                value: push.value,
                onChanged: (value) => push.value = value,
              ),
            ),
            if (push.value)
              const Text(
                'Push delivery is not enabled in the admin client; save the offer and send a notification from Marketing after configuring a trusted sender.',
              ),
          ],
        );
      }),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppButton(
            label: 'Cancel',
            style: AppButtonStyle.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Save offer',
            onPressed: () async {
              final amount = double.tryParse(value.text.trim()) ?? 0;
              if (name.text.trim().isEmpty) {
                Get.snackbar(
                  'Offer name required',
                  'Enter a name for this offer.',
                );
                return;
              }
              if (type.value == 'pct'
                  ? amount < 1 || amount > 90
                  : amount <= 0) {
                Get.snackbar(
                  'Invalid discount',
                  type.value == 'pct'
                      ? 'Percent must be from 1 to 90.'
                      : 'Enter a positive Rs amount.',
                );
                return;
              }
              if (selected.isEmpty) {
                Get.snackbar(
                  'Select products',
                  'An offer must include at least one product.',
                );
                return;
              }
              try {
                await controller.save(
                  OfferRecord(
                    id: existing?.id,
                    name: name.text.trim(),
                    type: type.value,
                    value: amount,
                    productIds: selected.toList(),
                    audience: audience.value,
                    endsAt: endsAt.value,
                    pinned: pinned.value,
                    live: live.value,
                    imageUrl: images.isEmpty ? null : images.first,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
                if (push.value) {
                  Get.snackbar(
                    'Offer saved',
                    'Push delivery is not connected here. Use Marketing notifications after configuring a server sender.',
                  );
                }
              } catch (exception) {
                Get.snackbar('Could not save offer', exception.toString());
              }
            },
          ),
        ],
      ),
    );
    await SideDrawer.show<void>(drawer);
    name.dispose();
    value.dispose();
    search.dispose();
  }
}
