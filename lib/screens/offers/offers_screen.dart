import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/offers_controller.dart';
import '../../models/offer_record.dart';
import '../../models/product_record.dart';
import '../../utils/money.dart';
import '../../utils/pricing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/multi_image_uploader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/side_drawer.dart';

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
String _discountLabel(OfferRecord o) =>
    o.type == 'pct' ? '${_fmt(o.value)}% OFF' : '${Money.rs(o.value)} OFF';

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
            subtitle: 'Create premium promotions and preview customer prices.',
            actions: [
              AppButton(
                label: 'New offer',
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
            _stats(context),
            const SizedBox(height: 18),
            _preview(context),
            const SizedBox(height: 22),
            _toolbar(context),
            const SizedBox(height: 16),
            _grid(context),
            if (controller.canLoadMore.value)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: OutlinedButton(
                    onPressed: controller.loadingMore.value
                        ? null
                        : controller.loadMore,
                    child: Text(
                      controller.loadingMore.value
                          ? 'Loading…'
                          : 'Load more offers',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    ),
  );

  // ───────────────────────── Stats ─────────────────────────

  Widget _stats(BuildContext context) {
    final offers = controller.offers;
    final live = offers.where((o) => o.live && !controller.isExpired(o)).length;
    final pinned = offers.where((o) => o.pinned).length;
    final expired = offers.where(controller.isExpired).length;
    final scheme = Theme.of(context).colorScheme;
    final items = [
      _StatCard(
        icon: PhosphorIconsRegular.tag,
        label: 'Total offers',
        value: '${offers.length}',
        color: scheme.primary,
      ),
      _StatCard(
        icon: PhosphorIconsRegular.lightning,
        label: 'Live now',
        value: '$live',
        color: const Color(0xFF16A34A),
      ),
      _StatCard(
        icon: PhosphorIconsRegular.pushPin,
        label: 'Pinned to home',
        value: '$pinned',
        color: const Color(0xFFF59E0B),
      ),
      _StatCard(
        icon: PhosphorIconsRegular.calendarBlank,
        label: 'Expired',
        value: '$expired',
        color: scheme.error,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final i in items) SizedBox(width: w, child: i)],
        );
      },
    );
  }

  // ───────────────────────── Hero preview ─────────────────────────

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.45)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsFill.sparkle,
                          color: scheme.onPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Customer home preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pinned, live offers exactly as this customer type sees them.',
                    style: TextStyle(
                      color: scheme.onPrimary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _audienceToggle('home', 'Home user',
                        PhosphorIconsRegular.house, scheme),
                    _audienceToggle('shop', 'Shop owner',
                        PhosphorIconsRegular.storefront, scheme),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (pinned.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'No pinned, live offers for this audience',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 14,
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
                return _PreviewCard(
                  offer: offer,
                  product: product,
                  oldPrice: oldPrice,
                  newPrice: newPrice,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _audienceToggle(
    String value,
    String label,
    IconData icon,
    ColorScheme scheme,
  ) {
    final selected = controller.previewAudience.value == value;
    return GestureDetector(
      onTap: () => controller.previewAudience.value = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? scheme.primary : scheme.onPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Toolbar + grid ─────────────────────────

  Widget _toolbar(BuildContext context) {
    const filters = {
      'all': 'All',
      'live': 'Live',
      'paused': 'Paused',
      'pinned': 'Pinned',
      'expired': 'Expired',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: _SearchBox(
            hint: 'Search offers or products',
            onChanged: (v) => controller.query.value = v,
          ),
        ),
        for (final e in filters.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: controller.filter.value == e.key,
            onSelected: (_) => controller.filter.value = e.key,
          ),
      ],
    );
  }

  Widget _grid(BuildContext context) {
    final list = controller.visible;
    if (list.isEmpty) {
      return const EmptyState(
        title: 'No matching offers',
        message: 'Try a different search or filter.',
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 700 ? 2 : 1);
        final w = (c.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final offer in list)
              SizedBox(width: w, child: _offerCard(context, offer)),
          ],
        );
      },
    );
  }

  Widget _offerCard(BuildContext context, OfferRecord offer) {
    final scheme = Theme.of(context).colorScheme;
    final expired = controller.isExpired(offer);
    final status = expired
        ? ('Expired', scheme.error)
        : offer.live
        ? ('Live', const Color(0xFF16A34A))
        : ('Paused', const Color(0xFFF59E0B));
    final chosen = controller.products
        .where((p) => offer.productIds.contains(p.id))
        .toList();
    final end = offer.endsAt;
    final daysLeft = end?.difference(DateTime.now()).inDays;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (offer.imageUrl != null)
                  Image.network(
                    offer.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _bannerFallback(scheme),
                  )
                else
                  _bannerFallback(scheme),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _StatusPill(text: status.$1, color: status.$2),
                ),
                if (offer.pinned)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(PhosphorIconsFill.pushPin,
                          size: 15, color: scheme.primary),
                    ),
                  ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Text(
                    _discountLabel(offer),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      height: 30,
                      width: chosen.isEmpty
                          ? 0
                          : 30.0 + (chosen.take(4).length - 1) * 20,
                      child: Stack(
                        children: [
                          for (var i = 0; i < chosen.take(4).length; i++)
                            Positioned(
                              left: i * 20.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _Thumb(
                                    url: chosen[i].images.isNotEmpty
                                        ? chosen[i].images.first
                                        : null,
                                    size: 26,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (chosen.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.productNames(offer),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MiniChip(
                      icon: offer.audience == 'shop'
                          ? PhosphorIconsRegular.storefront
                          : offer.audience == 'home'
                          ? PhosphorIconsRegular.house
                          : PhosphorIconsRegular.usersThree,
                      text: offer.audience == 'both'
                          ? 'Home + Shop'
                          : offer.audience == 'shop'
                          ? 'Shop owners'
                          : 'Home users',
                    ),
                    _MiniChip(
                      icon: PhosphorIconsRegular.calendarBlank,
                      text: end == null
                          ? 'No end date'
                          : expired
                          ? 'Ended ${_date(end)}'
                          : daysLeft != null && daysLeft <= 3
                          ? 'Ends soon · ${_date(end)}'
                          : 'Ends ${_date(end)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
            child: Row(
              children: [
                const Text('Pin', style: TextStyle(fontWeight: FontWeight.w600)),
                Switch(
                  value: offer.pinned,
                  onChanged: (v) =>
                      _confirmOfferToggle(context, offer, v, pinned: true),
                ),
                const SizedBox(width: 4),
                const Text('Live', style: TextStyle(fontWeight: FontWeight.w600)),
                Switch(
                  value: offer.live,
                  onChanged: (v) =>
                      _confirmOfferToggle(context, offer, v, pinned: false),
                ),
                const Spacer(),
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
      ),
    );
  }

  Widget _bannerFallback(ColorScheme scheme) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary,
          Color.lerp(scheme.primary, scheme.tertiary, 0.7)!,
        ],
      ),
    ),
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Icon(
          PhosphorIconsFill.tag,
          size: 70,
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
    ),
  );

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

  // ───────────────────────── Offer editor ─────────────────────────

  Future<void> _editOffer(BuildContext context, [OfferRecord? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final value = TextEditingController(
      text: existing == null || existing.value == 0 ? '' : _fmt(existing.value),
    );
    final search = TextEditingController();
    final selected = <String>{...?existing?.productIds}.obs;
    final type = (existing?.type ?? 'pct').obs;
    final audience = (existing?.audience ?? 'both').obs;
    final pinned = (existing?.pinned ?? false).obs;
    final live = (existing?.live ?? false).obs;
    final push = false.obs;
    final tick = 0.obs; // forces rebuild on text changes
    final endsAt = Rxn<DateTime>(existing?.endsAt);
    final images = <String>[
      if (existing?.imageUrl != null) existing!.imageUrl!,
    ].obs;

    final drawer = SideDrawer(
      title: existing == null ? 'New offer' : 'Edit offer',
      subtitle: 'Pick products first, then set the discount.',
      body: Obx(() {
        tick.value; // subscribe
        final scheme = Theme.of(context).colorScheme;
        final chosen = controller.products
            .where((p) => selected.contains(p.id))
            .toList();
        final amount = double.tryParse(value.text) ?? 0;
        final preview = OfferRecord(
          name: name.text.trim(),
          type: type.value,
          value: amount,
          productIds: selected.toList(),
          audience: audience.value,
          endsAt: endsAt.value,
          pinned: pinned.value,
          live: true,
        );
        double priceOf(ProductRecord p, bool shop, bool withOffer) =>
            withOffer
            ? unitPrice(
                product: p,
                shopCustomer: shop,
                quantity: 1,
                offers: [preview],
              )
            : unitPrice(product: p, shopCustomer: shop, quantity: 1);

        bool applies(bool shop) =>
            audience.value == 'both' || (audience.value == 'shop') == shop;

        final warnings = <String>[];
        for (final product in chosen) {
          for (final shop in [false, true]) {
            if (!applies(shop)) continue;
            final price = priceOf(product, shop, true);
            if (amount > 0 && price < product.cost) {
              warnings.add(
                '${product.name} (${shop ? 'Shop' : 'Home'}): ${Money.rs(price)} is below cost ${Money.rs(product.cost)}.',
              );
            }
          }
        }

        final query = search.text.trim().toLowerCase();
        final matches = controller.products
            .where(
              (p) =>
                  query.isEmpty ||
                  p.name.toLowerCase().contains(query) ||
                  p.sku.toLowerCase().contains(query),
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Step 1: products
            _StepBlock(
              number: 1,
              title: 'Choose products',
              subtitle: selected.isEmpty
                  ? 'Search and tick the products for this offer.'
                  : '${selected.length} selected',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: search,
                    onChanged: (_) => tick.value++,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(PhosphorIconsRegular.magnifyingGlass),
                      hintText: 'Search by product name or SKU',
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(PhosphorIconsRegular.x),
                              onPressed: () {
                                search.clear();
                                tick.value++;
                              },
                            ),
                    ),
                  ),
                  if (chosen.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final p in chosen)
                          InputChip(
                            avatar: ClipOval(
                              child: _Thumb(
                                url: p.images.isNotEmpty ? p.images.first : null,
                                size: 22,
                              ),
                            ),
                            label: Text(p.name),
                            onDeleted: () {
                              selected.remove(p.id);
                              tick.value++;
                            },
                          ),
                      ],
                    ),
                  ],
                  Row(
                    children: [
                      TextButton(
                        onPressed: matches.isEmpty
                            ? null
                            : () {
                                for (final p in matches) {
                                  if (p.id != null) selected.add(p.id!);
                                }
                                tick.value++;
                              },
                        child: Text('Select all (${matches.length})'),
                      ),
                      TextButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                selected.clear();
                                tick.value++;
                              },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 320,
                    child: matches.isEmpty
                        ? const Center(child: Text('No products found'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = matches[i];
                              final isSel = selected.contains(p.id);
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  if (p.id == null) return;
                                  isSel
                                      ? selected.remove(p.id)
                                      : selected.add(p.id!);
                                  tick.value++;
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: isSel
                                        ? scheme.primaryContainer
                                            .withValues(alpha: 0.45)
                                        : scheme.surfaceContainerLow,
                                    border: Border.all(
                                      color: isSel
                                          ? scheme.primary
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _Thumb(
                                        url: p.images.isNotEmpty
                                            ? p.images.first
                                            : null,
                                        size: 46,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${p.sku} · Home ${Money.rs(priceOf(p, false, false))} · Shop ${Money.rs(priceOf(p, true, false))}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSel
                                            ? PhosphorIconsFill.checkCircle
                                            : PhosphorIconsRegular.circle,
                                        color: isSel
                                            ? scheme.primary
                                            : scheme.outline,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            // ── Step 2: discount
            _StepBlock(
              number: 2,
              title: 'Set the discount',
              subtitle: 'Percent off or a fixed Rs amount.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'pct',
                          label: Text('Percent off'),
                          icon: Icon(PhosphorIconsRegular.percent),
                        ),
                        ButtonSegment(
                          value: 'rs',
                          label: Text('Rs off'),
                          icon: Icon(PhosphorIconsRegular.money),
                        ),
                      ],
                      selected: {type.value},
                      onSelectionChanged: (s) {
                        type.value = s.first;
                        value.clear();
                        tick.value++;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => tick.value++,
                    decoration: InputDecoration(
                      labelText: type.value == 'pct'
                          ? 'Percent (1–90)'
                          : 'Amount off (Rs)',
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final q in type.value == 'pct'
                          ? [5, 10, 15, 20, 25, 30]
                          : [50, 100, 200, 500])
                        ActionChip(
                          label: Text(type.value == 'pct' ? '$q%' : 'Rs $q'),
                          onPressed: () {
                            value.text = '$q';
                            tick.value++;
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Step 3: audience + schedule
            _StepBlock(
              number: 3,
              title: 'Audience & schedule',
              subtitle: 'Who sees it and when it ends.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'home',
                          label: Text('Home'),
                          icon: Icon(PhosphorIconsRegular.house),
                        ),
                        ButtonSegment(
                          value: 'shop',
                          label: Text('Shop'),
                          icon: Icon(PhosphorIconsRegular.storefront),
                        ),
                        ButtonSegment(
                          value: 'both',
                          label: Text('Both'),
                          icon: Icon(PhosphorIconsRegular.usersThree),
                        ),
                      ],
                      selected: {audience.value},
                      onSelectionChanged: (s) {
                        audience.value = s.first;
                        tick.value++;
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(PhosphorIconsRegular.calendarBlank),
                        label: Text(
                          endsAt.value == null
                              ? 'No end date'
                              : 'Ends ${_date(endsAt.value!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endsAt.value ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) {
                            endsAt.value = picked;
                            tick.value++;
                          }
                        },
                      ),
                      ActionChip(
                        label: const Text('7 days'),
                        onPressed: () {
                          endsAt.value =
                              DateTime.now().add(const Duration(days: 7));
                          tick.value++;
                        },
                      ),
                      ActionChip(
                        label: const Text('30 days'),
                        onPressed: () {
                          endsAt.value =
                              DateTime.now().add(const Duration(days: 30));
                          tick.value++;
                        },
                      ),
                      if (endsAt.value != null)
                        ActionChip(
                          label: const Text('No end'),
                          onPressed: () {
                            endsAt.value = null;
                            tick.value++;
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Step 4: image + visibility
            _StepBlock(
              number: 4,
              title: 'Banner & visibility',
              subtitle: 'Optional banner, then choose how it appears.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    onChanged: (_) => tick.value++,
                    decoration: InputDecoration(
                      labelText: 'Offer name',
                      hintText: 'e.g. Eid Mega Sale',
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Offer image'),
                  const SizedBox(height: 8),
                  MultiImageUploader(
                    maxImages: 1,
                    value: images,
                    onChanged: (urls) => images.assignAll(urls),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pin to home'),
                    value: pinned.value,
                    onChanged: (v) {
                      pinned.value = v;
                      tick.value++;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live'),
                    value: live.value,
                    onChanged: (v) {
                      live.value = v;
                      tick.value++;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send push notification'),
                    subtitle: const Text(
                      'Requires a trusted server-side FCM sender.',
                    ),
                    value: push.value,
                    onChanged: (v) {
                      push.value = v;
                      tick.value++;
                    },
                  ),
                  if (push.value)
                    const Text(
                      'Push delivery is not enabled in the admin client; save the offer and send a notification from Marketing after configuring a trusted sender.',
                    ),
                ],
              ),
            ),

            // ── Live price preview
            if (chosen.isNotEmpty && amount > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: scheme.surfaceContainerLow,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live price preview',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final p in chosen.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            _Thumb(
                              url: p.images.isNotEmpty ? p.images.first : null,
                              size: 38,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  for (final shop in [false, true])
                                    if (applies(shop))
                                      Text(
                                        '${shop ? 'Shop' : 'Home'}: ${Money.rs(priceOf(p, shop, false))} → ${Money.rs(priceOf(p, shop, true))}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (chosen.length > 3)
                      Text(
                        '+${chosen.length - 3} more products',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    if (warnings.isNotEmpty) ...[
                      const Divider(),
                      Row(
                        children: [
                          Icon(PhosphorIconsFill.warning,
                              size: 16, color: scheme.error),
                          const SizedBox(width: 6),
                          Text(
                            'Below-cost warning',
                            style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      for (final w in warnings)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            w,
                            style: TextStyle(color: scheme.error, fontSize: 12),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
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
              if (selected.isEmpty) {
                Get.snackbar(
                  'Select products',
                  'An offer must include at least one product.',
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
              if (name.text.trim().isEmpty) {
                Get.snackbar(
                  'Offer name required',
                  'Enter a name for this offer.',
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

// ───────────────────────── Small widgets ─────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.offer,
    required this.product,
    required this.oldPrice,
    required this.newPrice,
  });

  final OfferRecord offer;
  final ProductRecord product;
  final double oldPrice;
  final double newPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: product.images.isNotEmpty
                    ? Image.network(
                        product.images.first,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _Thumb(url: null, size: 100, fullWidth: true),
                      )
                    : _Thumb(url: null, size: 100, fullWidth: true),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _discountLabel(offer),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            offer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.rs(newPrice),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.rs(oldPrice),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.size, this.fullWidth = false});
  final String? url;
  final double size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: fullWidth ? double.infinity : size,
      height: size,
      color: scheme.surfaceContainerHigh,
      child: Icon(
        PhosphorIconsRegular.package,
        size: size * 0.45,
        color: scheme.onSurfaceVariant,
      ),
    );
    if (url == null) {
      return fullWidth
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: placeholder,
            );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _StepBlock extends StatelessWidget {
  const _StepBlock({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _c,
      onChanged: (v) {
        widget.onChanged(v);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(PhosphorIconsRegular.x),
                onPressed: () {
                  _c.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}