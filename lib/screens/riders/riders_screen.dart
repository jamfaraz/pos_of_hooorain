import 'dart:math';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/riders_controller.dart';
import '../../models/rider_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_table.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/side_drawer.dart';
import '../../widgets/status_chip.dart';
import 'package:hoorain_pos/utils/toas_message.dart';

class RidersScreen extends GetView<RidersController> {
  const RidersScreen({super.key});

  static const _vehicleTypes = [
    'Motorcycle',
    'Bicycle',
    'Car',
    'Van',
    'On foot',
  ];

  List<DropdownMenuItem<String>> get _vehicleItems => [
    for (final v in _vehicleTypes) DropdownMenuItem(value: v, child: Text(v)),
  ];

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.loading.value) {
      return const Column(
        children: [
          AppLoader(label: 'Loading rider metrics...'),
          SizedBox(height: 18),
          AppLoader(label: 'Loading riders...'),
        ],
      );
    }
    if (controller.error.value != null && controller.riders.isEmpty) {
      return ErrorRetryWidget(
        errorMessage: controller.error.value!,
        onRetry: controller.reload,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final riders = controller.riders;
    final onDelivery = riders.where((r) => r.status == 'on_delivery').length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Riders',
            subtitle: 'Delivery team, rider accounts and monthly pay.',
            actions: [
              AppButton(
                label: 'Add rider',
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: () => _addRider(context),
              ),
            ],
          ),
          _statGrid([
            _StatCard(
              label: 'Total riders',
              value: '${riders.length}',
              icon: PhosphorIconsRegular.motorcycle,
              accent: cs.primary,
            ),
            _StatCard(
              label: 'On delivery now',
              value: '$onDelivery',
              icon: PhosphorIconsRegular.truck,
              accent: cs.tertiary,
            ),
            _StatCard(
              label: 'Salary payable',
              value: Money.rs(controller.salaryPayable),
              caption: 'This month, after advances',
              icon: PhosphorIconsRegular.wallet,
              accent: cs.secondary,
            ),
            _StatCard(
              label: 'Advances given',
              value: Money.rs(controller.totalAdvances),
              caption: 'Deducted from salary',
              icon: PhosphorIconsRegular.handCoins,
              accent: cs.error,
            ),
          ]),
          const SizedBox(height: 20),
          riders.isEmpty
              ? const SizedBox(
                  height: 190,
                  child: EmptyState(
                    title: 'No riders yet',
                    message:
                        'Add a rider to create their login for the rider app.',
                  ),
                )
              : _tableCard(context, riders),
          const SizedBox(height: 24),
        ],
      ),
    );
  });

  /// Compact responsive grid: fixed natural height, no aspect-ratio stretching.
  Widget _statGrid(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      final cols = constraints.maxWidth > 1000
          ? 4
          : constraints.maxWidth > 620
          ? 2
          : 1;
      const gap = 14.0;
      final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in cards) SizedBox(width: width, child: c)],
      );
    },
  );

  Widget _tableCard(BuildContext context, List<RiderRecord> riders) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final small = theme.textTheme.bodySmall;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Text(
                  'All riders',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${riders.length}',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text('Click a row to open the profile', style: small),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
          SizedBox(
            height: 60.0 * riders.length + 56,
            child: AppTable(
              minWidth: 1150,
              columns: const [
                DataColumn2(label: Text('Rider'), size: ColumnSize.L),
                DataColumn2(label: Text('Vehicle')),
                DataColumn2(label: Text('Status')),
                DataColumn2(label: Text('Deliveries'), numeric: true),
                DataColumn2(label: Text('Base salary'), numeric: true),
                DataColumn2(label: Text('Advance'), numeric: true),
                DataColumn2(label: Text('Net payable'), numeric: true),
                DataColumn2(label: Text('Salary')),
                DataColumn2(label: Text('App login')),
              ],
              // DataRow2 + onTap: whole row is clickable with NO checkbox column.
              rows: riders
                  .map(
                    (rider) => DataRow2(
                      onTap: () => _openRider(context, rider),
                      cells: [
                        DataCell(_riderCell(context, rider)),
                        DataCell(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rider.vehicleType,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.25,
                                ),
                              ),
                              if (rider.vehicleNumber.isNotEmpty)
                                Text(
                                  rider.vehicleNumber,
                                  style: small?.copyWith(height: 1.25),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          StatusChip(
                            label: _statusLabel(rider.status),
                            tone: rider.status == 'available'
                                ? StatusTone.good
                                : rider.status == 'on_delivery'
                                ? StatusTone.info
                                : StatusTone.warn,
                          ),
                        ),
                        DataCell(Text('${controller.deliveryCount(rider)}')),
                        DataCell(Text(Money.rs(rider.baseSalary))),
                        DataCell(Text(Money.rs(rider.advance))),
                        DataCell(
                          Text(
                            Money.rs(controller.netPay(rider)),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        DataCell(
                          StatusChip(
                            label: controller.isPaid(rider) ? 'Paid' : 'Due',
                            tone: controller.isPaid(rider)
                                ? StatusTone.good
                                : StatusTone.warn,
                          ),
                        ),
                        DataCell(
                          StatusChip(
                            label: rider.active ? 'Active' : 'Disabled',
                            tone: rider.active
                                ? StatusTone.good
                                : StatusTone.warn,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact avatar + name/phone. Sized to fit a standard table row (no overflow).
  Widget _riderCell(BuildContext context, RiderRecord rider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final initial = rider.name.trim().isEmpty
        ? '?'
        : rider.name.trim().substring(0, 1).toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rider.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  height: 1.25,
                ),
              ),
              Text(
                rider.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
    'on_delivery' => 'On delivery',
    'off_duty' => 'Off duty',
    _ => 'Available',
  };

  // ───────────────────────── Helpers ─────────────────────────

  String _generatePassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _cleanError(Object e) => e.toString().replaceFirst('Bad state: ', '');

  Future<bool> _openWhatsApp(String phone, String text) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('0')
        ? '92${digits.substring(1)}'
        : digits;
    return launchUrl(
      Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Widget _section(BuildContext context, String title, [String? hint]) =>
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(hint, style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      );

  /// Single place that builds every text input on this screen.
  Widget _tf(
    TextEditingController c,
    String label, {
    String hint = '',
    TextInputType? type,
    int maxLines = 1,
    bool required = false,
    bool optional = false,
    List<TextInputFormatter>? formatters,
    TextCapitalization capitalization = TextCapitalization.none,
  }) => PrimaryTextField(
    controller: c,
    headerText: label,
    hintText: hint,
    fieldType: type ?? TextInputType.text,
    maxLines: maxLines,
    required: required,
    optional: optional,
    inputFormatters: formatters,
    textCapitalization: capitalization,
    maxWidth: double.infinity, // fill the drawer width
  );

  /// Money / number fields: digits and one dot only.
  Widget _amountField(
    TextEditingController c,
    String label, {
    String hint = '0',
  }) => _tf(
    c,
    label,
    hint: hint,
    type: const TextInputType.numberWithOptions(decimal: true),
    formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
  );

  static const _gap = SizedBox(height: 14);

  Widget _payLine(String label, String amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  // ───────────────────────── Add rider ─────────────────────────

  Future<void> _addRider(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController(text: _generatePassword());
    final cnic = TextEditingController();
    final address = TextEditingController();
    final emergencyName = TextEditingController();
    final emergencyPhone = TextEditingController();
    final vehicleNumber = TextEditingController();
    final salary = TextEditingController(text: '30000');
    final fuel = TextEditingController(text: '0');
    final vehicleType = ValueNotifier<String>(_vehicleTypes.first);
    final creating = ValueNotifier<bool>(false);
    final created = ValueNotifier<_RiderLogin?>(null);

    String? validate() {
      if (name.text.trim().isEmpty) return 'Enter the rider name.';
      if (phone.text.trim().isEmpty) return 'Enter the rider mobile number.';
      final mail = email.text.trim();
      if (!mail.contains('@') || !mail.contains('.')) {
        return 'Enter a valid login email.';
      }
      if (password.text.length < 6) {
        return 'Password must be at least 6 characters.';
      }
      if ((double.tryParse(salary.text) ?? 0) < 0 ||
          (double.tryParse(fuel.text) ?? 0) < 0) {
        return 'Pay amounts cannot be negative.';
      }
      return null;
    }

    Future<void> submit() async {
      if (creating.value) return;
      final problem = validate();
      if (problem != null) {
        MessageToast.showWarning(msg: problem, title: 'Check the form');
        return;
      }
      creating.value = true;
      try {
        final draft = RiderRecord(
          name: name.text.trim(),
          phone: phone.text.trim(),
          email: email.text.trim().toLowerCase(),
          cnic: cnic.text.trim(),
          address: address.text.trim(),
          vehicleType: vehicleType.value,
          vehicleNumber: vehicleNumber.text.trim().toUpperCase(),
          emergencyName: emergencyName.text.trim(),
          emergencyPhone: emergencyPhone.text.trim(),
          baseSalary: double.tryParse(salary.text) ?? 0,
          fuelAllowance: double.tryParse(fuel.text) ?? 0,
        );
        await controller.createRider(draft: draft, password: password.text);
        created.value = _RiderLogin(
          name: draft.name,
          phone: draft.phone,
          email: draft.email,
          password: password.text,
        );
      } catch (exception) {
        MessageToast.showError(
          msg: _cleanError(exception),
          title: 'Could not create rider',
        );
      } finally {
        creating.value = false;
      }
    }

    final drawer = SideDrawer(
      title: 'Add rider',
      subtitle: 'Creates the rider’s login for the rider app.',
      body: ValueListenableBuilder<_RiderLogin?>(
        valueListenable: created,
        builder: (context, login, _) {
          if (login != null) return _credentialsCard(context, login);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                context,
                'Login details',
                'The rider signs in to the rider app with this email and password.',
              ),
              _tf(
                email,
                'Rider email (login)',
                hint: 'rider@example.com',
                type: TextInputType.emailAddress,
                required: true,
              ),
              _gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _tf(
                      password,
                      'Password',
                      hint: 'Min 6 characters',
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => password.text = _generatePassword(),
                    child: const Text('Generate'),
                  ),
                ],
              ),
              _section(context, 'Personal details'),
              _tf(
                name,
                'Rider name',
                hint: 'Full name',
                required: true,
                capitalization: TextCapitalization.words,
              ),
              _gap,
              _tf(
                phone,
                'Mobile number',
                hint: '03XX XXXXXXX',
                type: TextInputType.phone,
                required: true,
              ),
              _gap,
              _tf(
                cnic,
                'CNIC number',
                hint: '00000-0000000-0',
                type: TextInputType.number,
                optional: true,
              ),
              _gap,
              _tf(
                address,
                'Home address',
                hint: 'House, street, city',
                maxLines: 2,
                optional: true,
                capitalization: TextCapitalization.sentences,
              ),
              _gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _tf(
                      emergencyName,
                      'Emergency contact',
                      hint: 'Name',
                      optional: true,
                      capitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tf(
                      emergencyPhone,
                      'Emergency phone',
                      hint: '03XX XXXXXXX',
                      type: TextInputType.phone,
                      optional: true,
                    ),
                  ),
                ],
              ),
              _section(context, 'Vehicle'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: vehicleType,
                      builder: (context, value, _) => CommonDropdown<String>(
                        label: 'Vehicle type',
                        value: value,
                        bottomSpacing: 0,
                        maxWidth: double.infinity,
                        items: _vehicleItems,
                        onChanged: (v) {
                          if (v != null) vehicleType.value = v;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tf(
                      vehicleNumber,
                      'Vehicle number',
                      hint: 'e.g. LEA-1234',
                      optional: true,
                      capitalization: TextCapitalization.characters,
                    ),
                  ),
                ],
              ),
              _section(context, 'Pay terms'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _amountField(salary, 'Base salary (Rs)')),
                  const SizedBox(width: 10),
                  Expanded(child: _amountField(fuel, 'Fuel allowance (Rs)')),
                ],
              ),
            ],
          );
        },
      ),
      footer: ValueListenableBuilder<_RiderLogin?>(
        valueListenable: created,
        builder: (context, login, _) {
          if (login == null) {
            return Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                AppButton(
                  label: 'Cancel',
                  style: AppButtonStyle.ghost,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                AppButton(
                  label: 'Create rider account',
                  icon: const Icon(PhosphorIconsRegular.userPlus),
                  onPressed: submit,
                ),
              ],
            );
          }
          return Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              AppButton(
                label: 'Copy login details',
                style: AppButtonStyle.ghost,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: login.message));
                  MessageToast.showInfo(
                    msg: 'Login details copied.',
                    title: 'Copied',
                  );
                },
              ),
              AppButton(
                label: 'Send on WhatsApp',
                icon: const Icon(PhosphorIconsRegular.whatsappLogo),
                style: AppButtonStyle.ghost,
                onPressed: () async {
                  final ok = await _openWhatsApp(login.phone, login.message);
                  if (!ok) {
                    MessageToast.showError(
                      msg: 'Copy the login details and share them manually.',
                      title: 'WhatsApp could not open',
                    );
                  }
                },
              ),
              AppButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      ),
    );
    await SideDrawer.show<void>(drawer);
    for (final c in [
      name,
      phone,
      email,
      password,
      cnic,
      address,
      emergencyName,
      emergencyPhone,
      vehicleNumber,
      salary,
      fuel,
    ]) {
      c.dispose();
    }
    vehicleType.dispose();
    creating.dispose();
    created.dispose();
  }

  Widget _credentialsCard(BuildContext context, _RiderLogin login) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsFill.checkCircle,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rider account created',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('${login.name} can now sign in to the rider app with:'),
            const SizedBox(height: 12),
            _credLine(theme, 'Email', login.email),
            _credLine(theme, 'Password', login.password),
            const SizedBox(height: 12),
            Text(
              'Share these now. The password is not shown again. The rider can change it later from the app, or you can send a password reset email from the rider’s profile.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _credLine(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  // ───────────────────────── Rider profile ─────────────────────────

  Future<void> _openRider(BuildContext context, RiderRecord rider) async {
    final salaryHistory = await controller.salaryHistory(rider);
    if (!context.mounted) return;
    final name = TextEditingController(text: rider.name);
    final phone = TextEditingController(text: rider.phone);
    final cnic = TextEditingController(text: rider.cnic);
    final address = TextEditingController(text: rider.address);
    final emergencyName = TextEditingController(text: rider.emergencyName);
    final emergencyPhone = TextEditingController(text: rider.emergencyPhone);
    final vehicleNumber = TextEditingController(text: rider.vehicleNumber);
    final base = TextEditingController(text: '${rider.baseSalary}');
    final fuel = TextEditingController(text: '${rider.fuelAllowance}');
    final advance = TextEditingController();
    var status = rider.status;
    var active = rider.active;
    var vehicleType = _vehicleTypes.contains(rider.vehicleType)
        ? rider.vehicleType
        : _vehicleTypes.first;

    final drawer = SideDrawer(
      title: rider.name,
      subtitle:
          '${rider.phone}${rider.joinedAt == null ? '' : ' · Joined ${rider.joinedAt!.toLocal().toString().split(' ').first}'}',
      body: StatefulBuilder(
        builder: (context, setDrawerState) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CommonDropdown<String>(
              label: 'Rider status',
              value: status,
              bottomSpacing: 0,
              maxWidth: double.infinity,
              items: const [
                DropdownMenuItem(value: 'available', child: Text('Available')),
                DropdownMenuItem(
                  value: 'on_delivery',
                  child: Text('On delivery'),
                ),
                DropdownMenuItem(value: 'off_duty', child: Text('Off duty')),
              ],
              onChanged: (value) {
                if (value != null) setDrawerState(() => status = value);
              },
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Can sign in to the rider app'),
              subtitle: const Text('Turn off to block this rider immediately.'),
              value: active,
              onChanged: (value) => setDrawerState(() => active = value),
            ),
            _section(
              context,
              'This month · ${Money.rs(controller.netPay(rider))} net',
            ),
            _payLine('Base salary', Money.rs(rider.baseSalary)),
            _payLine('Fuel allowance', Money.rs(rider.fuelAllowance)),
            _payLine('Advance deduction', '− ${Money.rs(rider.advance)}'),
            const Divider(),
            _section(context, 'Profile'),
            _payLine('Login email', rider.email.isEmpty ? '—' : rider.email),
            _gap,
            _tf(
              name,
              'Rider name',
              hint: 'Full name',
              required: true,
              capitalization: TextCapitalization.words,
            ),
            _gap,
            _tf(
              phone,
              'Mobile number',
              hint: '03XX XXXXXXX',
              type: TextInputType.phone,
              required: true,
            ),
            _gap,
            _tf(
              cnic,
              'CNIC number',
              hint: '00000-0000000-0',
              type: TextInputType.number,
              optional: true,
            ),
            _gap,
            _tf(
              address,
              'Home address',
              hint: 'House, street, city',
              maxLines: 2,
              optional: true,
              capitalization: TextCapitalization.sentences,
            ),
            _gap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _tf(
                    emergencyName,
                    'Emergency contact',
                    hint: 'Name',
                    optional: true,
                    capitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf(
                    emergencyPhone,
                    'Emergency phone',
                    hint: '03XX XXXXXXX',
                    type: TextInputType.phone,
                    optional: true,
                  ),
                ),
              ],
            ),
            _section(context, 'Vehicle'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CommonDropdown<String>(
                    label: 'Vehicle type',
                    value: vehicleType,
                    bottomSpacing: 0,
                    maxWidth: double.infinity,
                    items: _vehicleItems,
                    onChanged: (v) {
                      if (v != null) setDrawerState(() => vehicleType = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf(
                    vehicleNumber,
                    'Vehicle number',
                    hint: 'e.g. LEA-1234',
                    optional: true,
                    capitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            _section(context, 'Pay terms'),
            _amountField(base, 'Base salary (Rs)'),
            _gap,
            _amountField(fuel, 'Fuel allowance (Rs)'),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _amountField(advance, 'Give advance (Rs)')),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(advance.text) ?? 0;
                    if (amount <= 0) {
                      MessageToast.showWarning(
                        msg: 'The advance amount must be greater than zero.',
                        title: 'Enter an advance',
                      );
                      return;
                    }
                    final confirmed = await CommonDialog.confirm(
                      context: context,
                      title: 'Give rider an advance?',
                      message:
                          'Record an advance of ${Money.rs(amount)} for ${rider.name}?',
                      icon: PhosphorIconsRegular.handCoins,
                      iconColor: Theme.of(context).colorScheme.primary,
                      positiveButtonText: 'Give advance',
                    );
                    if (confirmed != true) return;
                    try {
                      await controller.giveAdvance(rider, amount);
                      advance.clear();
                      MessageToast.showSuccess(
                        msg: 'The rider balance has been updated.',
                        title: 'Advance recorded',
                      );
                    } catch (exception) {
                      MessageToast.showError(
                        msg: exception.toString(),
                        title: 'Could not add advance',
                      );
                    }
                  },
                  child: const Text('Add advance'),
                ),
              ],
            ),
            _section(context, 'Account'),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(PhosphorIconsRegular.envelopeSimple, size: 18),
                label: const Text('Send password reset email'),
                onPressed: rider.email.isEmpty
                    ? null
                    : () async {
                        final confirmed = await CommonDialog.confirm(
                          context: context,
                          title: 'Send password reset?',
                          message:
                              'A reset link will be emailed to ${rider.email}.',
                          icon: PhosphorIconsRegular.envelopeSimple,
                          iconColor: Theme.of(context).colorScheme.primary,
                          positiveButtonText: 'Send email',
                        );
                        if (confirmed != true) return;
                        try {
                          await controller.sendPasswordReset(rider);
                          MessageToast.showSuccess(
                            msg: 'Password reset link sent to ${rider.email}.',
                            title: 'Email sent',
                          );
                        } catch (exception) {
                          MessageToast.showError(
                            msg: _cleanError(exception),
                            title: 'Could not send email',
                          );
                        }
                      },
              ),
            ),
            _section(context, 'Salary history'),
            if (salaryHistory.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('No salary payments recorded.'),
              )
            else
              for (final payment in salaryHistory)
                _payLine(
                  '${payment['month'] ?? 'Salary'}',
                  Money.rs((payment['amount'] as num?) ?? 0),
                ),
          ],
        ),
      ),
      footer: Row(
        children: [
          ConfirmTapButton(
            label: 'Remove',
            confirmLabel: 'Remove rider',
            confirmTitle: 'Remove rider?',
            confirmMessage:
                'This rider will be removed and can no longer use the rider app.',
            onConfirmed: () async {
              try {
                await controller.deleteRider(rider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (exception) {
                MessageToast.showError(
                  msg: exception.toString(),
                  title: 'Could not remove rider',
                );
              }
            },
          ),
          const Spacer(),
          if (!controller.isPaid(rider))
            AppButton(
              label: 'Mark salary paid',
              style: AppButtonStyle.ghost,
              onPressed: () async {
                final confirmed = await CommonDialog.confirm(
                  context: context,
                  title: 'Mark salary as paid?',
                  message:
                      'Record this month’s salary payment for ${rider.name} and clear their advance balance?',
                  icon: PhosphorIconsRegular.money,
                  iconColor: Theme.of(context).colorScheme.primary,
                  positiveButtonText: 'Mark paid',
                );
                if (confirmed != true) return;
                try {
                  await controller.paySalary(rider);
                  if (context.mounted) Navigator.of(context).pop();
                  MessageToast.showSuccess(
                    msg: 'Payment and Salaries expense recorded.',
                    title: 'Salary paid',
                  );
                } catch (exception) {
                  MessageToast.showError(
                    msg: exception.toString(),
                    title: 'Could not pay salary',
                  );
                }
              },
            ),
          AppButton(
            label: 'Save',
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                MessageToast.showWarning(
                  msg: 'Enter the rider name.',
                  title: 'Name required',
                );
                return;
              }
              final confirmed = await CommonDialog.confirm(
                context: context,
                title: 'Save rider changes?',
                message:
                    'Update ${rider.name}’s profile, status and salary terms with these values?',
                icon: PhosphorIconsRegular.floppyDisk,
                iconColor: Theme.of(context).colorScheme.primary,
                positiveButtonText: 'Save changes',
              );
              if (confirmed != true) return;
              try {
                await controller.saveRider(
                  rider.copyWith(
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    cnic: cnic.text.trim(),
                    address: address.text.trim(),
                    emergencyName: emergencyName.text.trim(),
                    emergencyPhone: emergencyPhone.text.trim(),
                    vehicleType: vehicleType,
                    vehicleNumber: vehicleNumber.text.trim().toUpperCase(),
                    status: status,
                    active: active,
                    baseSalary: double.tryParse(base.text) ?? 0,
                    fuelAllowance: double.tryParse(fuel.text) ?? 0,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              } catch (exception) {
                MessageToast.showError(
                  msg: exception.toString(),
                  title: 'Could not save rider',
                );
              }
            },
          ),
        ],
      ),
    );
    await SideDrawer.show<void>(drawer);
    for (final c in [
      name,
      phone,
      cnic,
      address,
      emergencyName,
      emergencyPhone,
      vehicleNumber,
      base,
      fuel,
      advance,
    ]) {
      c.dispose();
    }
  }
}

class _RiderLogin {
  const _RiderLogin({
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  final String name;
  final String phone;
  final String email;
  final String password;

  String get message =>
      'Hoorain rider login\nName: $name\nEmail: $email\nPassword: $password\n\nOpen the Hoorain Rider app and sign in with these details.';
}

/// Compact, premium KPI card (≈ 84px tall instead of stretching with the grid).
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
