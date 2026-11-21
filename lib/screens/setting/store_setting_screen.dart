import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../controllers/setting_controller.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';

class StoreSetupScreen extends GetView<StoreSetupController> {
  const StoreSetupScreen({super.key});

  static const _tabs = [
    (PhosphorIconsRegular.storefront, 'Store profile'),
    (PhosphorIconsRegular.mapPinArea, 'Delivery area'),
    (PhosphorIconsRegular.receipt, 'Charges & orders'),
    (PhosphorIconsRegular.headset, 'Support info'),
  ];

  static const double _gap = 18;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.loading.value) {
      return const AppLoader(label: 'Loading store setup...');
    }
    if (controller.error.value != null) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.load,
      );
    }
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Store setup',
                subtitle: 'Your shop details, delivery area and support info.',
                bottomSpacing: 18,
                titleFontSize: 28,
              ),
              _previewCard(context),
              const SizedBox(height: 22),
              _tabBar(context),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(controller.tab.value),
                  child: switch (controller.tab.value) {
                    0 => _profileTab(context),
                    1 => _deliveryTab(context),
                    2 => _chargesTab(context),
                    _ => _supportTab(context),
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  });

  // ------------------------------------------------------------------
  // Live preview hero
  // ------------------------------------------------------------------

  Widget _previewCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = controller;
    final hero1 = Color.lerp(cs.primary, Colors.black, 0.55)!;
    final hero2 = Color.lerp(cs.primary, Colors.black, 0.82)!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hero1, hero2],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.25),
                ),
              ),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                c.name,
                c.address,
                c.phone,
                c.hours,
              ]),
              builder: (context, _) {
                final storeName = c.name.text.trim().isEmpty
                    ? 'Your store'
                    : c.name.text.trim();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        storeName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.address.text.trim().isEmpty
                                ? 'No address added yet'
                                : c.address.text.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (c.phone.text.trim().isNotEmpty)
                                _heroChip(
                                  PhosphorIconsRegular.phone,
                                  c.phone.text.trim(),
                                ),
                              if (c.hours.text.trim().isNotEmpty)
                                _heroChip(
                                  PhosphorIconsRegular.clock,
                                  c.hours.text.trim(),
                                ),
                              Obx(
                                () => _heroChip(
                                  PhosphorIconsRegular.truck,
                                  'Delivers within ${c.radius.value.toStringAsFixed(c.radius.value % 1 == 0 ? 0 : 1)} km',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------
  // Tabs
  // ------------------------------------------------------------------

  Widget _tabBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dirty = [
      controller.profileDirty.value,
      controller.deliveryDirty.value,
      controller.chargesDirty.value,
      controller.supportDirty.value,
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Flexible(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.tab.value = i,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: controller.tab.value == i
                          ? cs.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabs[i].$1,
                          size: 18,
                          color: controller.tab.value == i
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            _tabs[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: controller.tab.value == i
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: controller.tab.value == i
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (dirty[i]) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: cs.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Store profile
  // ------------------------------------------------------------------

  Widget _profileTab(BuildContext context) {
    final c = controller;
    return _section(
      context,
      icon: PhosphorIconsRegular.storefront,
      title: 'Store profile',
      subtitle: 'Shown on receipts and in the customer app.',
      child: Form(
        key: c.profileForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pair(
              PrimaryTextField(
                controller: c.name,
                headerText: 'Store name',
                hintText: 'e.g. Hoorain',
                required: true,
                maxWidth: double.infinity,
                prefixIcon: const Icon(
                  PhosphorIconsRegular.storefront,
                  size: 19,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Store name is required'
                    : null,
              ),
              PrimaryTextField(
                controller: c.taxNumber,
                headerText: 'Tax number',
                hintText: 'NTN 1234567-8',
                optional: true,
                maxWidth: double.infinity,
                prefixIcon: const Icon(
                  PhosphorIconsRegular.identificationCard,
                  size: 19,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(height: _gap),
            PrimaryTextField(
              controller: c.address,
              headerText: 'Address',
              hintText: 'Shop, street, area, city',
              required: true,
              maxWidth: double.infinity,
              maxLines: 2,
              prefixIcon: const Icon(PhosphorIconsRegular.mapPin, size: 19),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: _gap),
            _pair(
              PrimaryTextField(
                controller: c.phone,
                headerText: 'Phone',
                hintText: '+92 42 3578 1200',
                required: true,
                maxWidth: double.infinity,
                fieldType: TextInputType.phone,
                prefixIcon: const Icon(PhosphorIconsRegular.phone, size: 19),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                validator: (v) => v == null || v.trim().length < 7
                    ? 'Enter a valid phone number'
                    : null,
              ),
              PrimaryTextField(
                controller: c.hours,
                headerText: 'Opening hours',
                hintText: 'Mon to Sat, 9 am to 8 pm',
                maxWidth: double.infinity,
                optional: true,
                prefixIcon: const Icon(PhosphorIconsRegular.clock, size: 19),
              ),
            ),
          ],
        ),
      ),
      actions: _actions(
        context,
        dirty: c.profileDirty,
        saving: c.savingProfile,
        onSave: c.saveProfile,
        onDiscard: c.discardProfile,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Delivery area
  // ------------------------------------------------------------------

  Widget _deliveryTab(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = controller;
    return _section(
      context,
      icon: PhosphorIconsRegular.mapPinArea,
      title: 'Delivery area',
      subtitle:
          'Customers outside this distance from your store cannot place delivery orders.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() {
            final v = c.radius.value;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          height: 1,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'km radius',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: v.clamp(
                      StoreSetupController.minRadius,
                      StoreSetupController.maxRadius,
                    ),
                    min: StoreSetupController.minRadius,
                    max: StoreSetupController.maxRadius,
                    divisions:
                        (StoreSetupController.maxRadius -
                                StoreSetupController.minRadius)
                            .toInt(),
                    label: '${v.toStringAsFixed(0)} km',
                    onChanged: c.setRadiusFromSlider,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 km', style: theme.textTheme.bodySmall),
                      Text('100 km', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in const [5, 10, 20, 35, 50])
                        _presetChip(context, preset.toDouble(), v),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: _gap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: PrimaryTextField(
              controller: c.radiusText,
              headerText: 'Exact radius (km)',
              hintText: 'e.g. 20',
              required: true,
              maxWidth: double.infinity,
              fieldType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: const Icon(PhosphorIconsRegular.target, size: 19),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              helperText: 'Between 1 and 100 km',
            ),
          ),
          const SizedBox(height: _gap),
          _note(
            context,
            'This updates settings/service_config. The customer app reads the same value, so the change applies right after you save.',
          ),
        ],
      ),
      actions: _actions(
        context,
        dirty: c.deliveryDirty,
        saving: c.savingDelivery,
        onSave: c.saveDelivery,
        onDiscard: c.discardDelivery,
      ),
    );
  }

  Widget _presetChip(BuildContext context, double preset, double current) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selected = current == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => controller.setRadiusFromSlider(preset),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? cs.primary : theme.dividerColor),
        ),
        child: Text(
          '${preset.toInt()} km',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Support info
  // ------------------------------------------------------------------

  // ------------------------------------------------------------------
  // Charges & orders
  // ------------------------------------------------------------------

  Widget _amountField(
    TextEditingController c, {
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
  }) => PrimaryTextField(
    controller: c,
    headerText: label,
    hintText: hint,
    helperText: helper,
    required: true,
    maxWidth: double.infinity,
    fieldType: const TextInputType.numberWithOptions(decimal: true),
    prefixIcon: Icon(icon, size: 19),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
    validator: (v) {
      final n = double.tryParse((v ?? '').trim());
      if (n == null) return 'Enter an amount (0 if none)';
      if (n < 0) return 'Cannot be negative';
      return null;
    },
  );

  Widget _chargesTab(BuildContext context) {
    final c = controller;
    return _section(
      context,
      icon: PhosphorIconsRegular.receipt,
      title: 'Charges & minimum order',
      subtitle:
          'What customers pay on top of their items, and the smallest order you accept.',
      child: Form(
        key: c.chargesForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountField(
              c.minimumOrder,
              label: 'Minimum order (Rs)',
              hint: '0',
              icon: PhosphorIconsRegular.shoppingCart,
              helper:
                  'Orders below this amount cannot be placed. Use 0 for no minimum.',
            ),
            const SizedBox(height: _gap),
            _pair(
              _amountField(
                c.deliveryCharges,
                label: 'Delivery charges (Rs)',
                hint: '50',
                icon: PhosphorIconsRegular.truck,
              ),
              _amountField(
                c.freeDelivery,
                label: 'Free delivery above (Rs)',
                hint: '2500',
                icon: PhosphorIconsRegular.gift,
                helper: 'Use 0 to always charge delivery.',
              ),
            ),
            const SizedBox(height: _gap),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _amountField(
                c.serviceCharges,
                label: 'Service charges (Rs)',
                hint: '10',
                icon: PhosphorIconsRegular.coins,
              ),
            ),
            const SizedBox(height: 22),
            _chargesPreview(context),
          ],
        ),
      ),
      actions: _actions(
        context,
        dirty: c.chargesDirty,
        saving: c.savingCharges,
        onSave: c.saveCharges,
        onDiscard: c.discardCharges,
      ),
    );
  }

  /// Plain-language summary that updates as the admin types.
  Widget _chargesPreview(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = controller;
    double n(TextEditingController t) => double.tryParse(t.text.trim()) ?? 0;

    return ListenableBuilder(
      listenable: Listenable.merge([
        c.minimumOrder,
        c.deliveryCharges,
        c.freeDelivery,
        c.serviceCharges,
      ]),
      builder: (context, _) {
        final min = n(c.minimumOrder);
        final delivery = n(c.deliveryCharges);
        final free = n(c.freeDelivery);
        final service = n(c.serviceCharges);

        final lines = <(IconData, String)>[
          (
            PhosphorIconsRegular.shoppingCart,
            min > 0
                ? 'Customers must order at least ${Money.rs(min)}.'
                : 'There is no minimum order.',
          ),
          (
            PhosphorIconsRegular.truck,
            delivery <= 0
                ? 'Delivery is free.'
                : free > 0
                ? 'Delivery costs ${Money.rs(delivery)}, and is free for orders of ${Money.rs(free)} or more.'
                : 'Delivery always costs ${Money.rs(delivery)}.',
          ),
          (
            PhosphorIconsRegular.coins,
            service > 0
                ? 'A service charge of ${Money.rs(service)} is added to every order.'
                : 'No service charge is added.',
          ),
        ];

        final warn = min > 0 && free > 0 && free < min;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW CUSTOMERS SEE IT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(line.$1, size: 17, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line.$2,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (warn)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PhosphorIconsRegular.warning,
                        size: 17,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Free delivery starts below your minimum order, so every order will already get free delivery.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _supportTab(BuildContext context) {
    final c = controller;
    return _section(
      context,
      icon: PhosphorIconsRegular.headset,
      title: 'Support info',
      subtitle: 'How customers can reach you for help with an order.',
      child: Form(
        key: c.supportForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pair(
              PrimaryTextField(
                controller: c.supportPhone,
                headerText: 'Support phone',
                hintText: '03XX XXXXXXX',
                maxWidth: double.infinity,
                optional: true,
                fieldType: TextInputType.phone,
                prefixIcon: const Icon(PhosphorIconsRegular.phone, size: 19),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
              ),
              PrimaryTextField(
                controller: c.supportWhatsapp,
                headerText: 'WhatsApp number',
                hintText: '923XXXXXXXXX',
                maxWidth: double.infinity,
                optional: true,
                fieldType: TextInputType.phone,
                prefixIcon: const Icon(
                  PhosphorIconsRegular.whatsappLogo,
                  size: 19,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                ],
              ),
            ),
            const SizedBox(height: _gap),
            _pair(
              PrimaryTextField(
                controller: c.supportEmail,
                headerText: 'Support email',
                hintText: 'help@hoorain.com',
                maxWidth: double.infinity,
                optional: true,
                fieldType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  PhosphorIconsRegular.envelopeSimple,
                  size: 19,
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                      ? null
                      : 'Enter a valid email';
                },
              ),
              PrimaryTextField(
                controller: c.supportHours,
                headerText: 'Support hours',
                hintText: 'Every day, 10 am to 6 pm',
                maxWidth: double.infinity,
                optional: true,
                prefixIcon: const Icon(PhosphorIconsRegular.clock, size: 19),
              ),
            ),
          ],
        ),
      ),
      actions: _actions(
        context,
        dirty: c.supportDirty,
        saving: c.savingSupport,
        onSave: c.saveSupport,
        onDiscard: c.discardSupport,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Shared building blocks
  // ------------------------------------------------------------------

  /// Two fields side by side on wide screens, stacked on narrow ones.
  Widget _pair(Widget a, Widget b) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 560) {
        return Column(
          children: [
            a,
            const SizedBox(height: _gap),
            b,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ],
      );
    },
  );

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    required Widget actions,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: child,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: actions,
          ),
        ],
      ),
    );
  }

  /// Footer: unsaved-changes hint on the left, Reset + Save on the right.
  Widget _actions(
    BuildContext context, {
    required RxBool dirty,
    required RxBool saving,
    required Future<void> Function() onSave,
    required VoidCallback onDiscard,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Obx(() {
      final isDirty = dirty.value;
      final isSaving = saving.value;
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDirty
                    ? PhosphorIconsFill.circle
                    : PhosphorIconsRegular.checkCircle,
                size: isDirty ? 9 : 17,
                color: isDirty ? cs.secondary : cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isDirty ? 'You have unsaved changes' : 'All changes saved',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDirty ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Reset',
                style: AppButtonStyle.ghost,
                small: true,
                icon: const Icon(
                  PhosphorIconsRegular.arrowCounterClockwise,
                  size: 16,
                ),
                onPressed: isDirty && !isSaving ? onDiscard : null,
              ),
              const SizedBox(width: 10),
              AppButton(
                label: isSaving ? 'Saving…' : 'Save changes',
                small: true,
                icon: const Icon(PhosphorIconsRegular.floppyDisk, size: 18),
                onPressed: isDirty && !isSaving ? onSave : null,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _note(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIconsRegular.info,
            size: 17,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
