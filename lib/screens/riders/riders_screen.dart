import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../controllers/riders_controller.dart';
import '../../models/rider_invite_record.dart';
import '../../models/rider_record.dart';
import '../../utils/money.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_table.dart';
import '../../widgets/common_dialog.dart';
import '../../widgets/confirm_tap_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_textfield.dart';
import '../../widgets/retry_widget.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/side_drawer.dart';
import '../../widgets/status_chip.dart';

class RidersScreen extends GetView<RidersController> {
  const RidersScreen({super.key});

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
    final pendingInvites = controller.invites
        .where((invite) => invite.status == 'pending')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Riders',
          subtitle: 'Delivery team, monthly pay, and invitations.',
          actions: [
            AppButton(
              label: 'Invite rider',
              icon: const Icon(PhosphorIconsRegular.plus),
              onPressed: () => _inviteRider(context),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 1000
                ? 4
                : constraints.maxWidth > 620
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 1 ? 3.2 : 2.2,
              children: [
                KpiCard(
                  label: 'Riders',
                  value: '${controller.riders.length}',
                  icon: PhosphorIconsRegular.motorcycle,
                ),
                KpiCard(
                  label: 'On delivery now',
                  value:
                      '${controller.riders.where((rider) => rider.status == 'on_delivery').length}',
                  icon: PhosphorIconsRegular.truck,
                ),
                KpiCard(
                  label: 'Salary payable',
                  value: Money.rs(controller.salaryPayable),
                  caption: 'This month, after advances',
                  icon: PhosphorIconsRegular.wallet,
                ),
                KpiCard(
                  label: 'Advances given',
                  value: Money.rs(controller.totalAdvances),
                  icon: PhosphorIconsRegular.handCoins,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                controller.riders.isEmpty
                    ? const SizedBox(
                        height: 190,
                        child: EmptyState(
                          title: 'No riders yet',
                          message:
                              'Invite a rider to start tracking deliveries and pay.',
                        ),
                      )
                    : SizedBox(
                        height: 58 * controller.riders.length + 52,
                        child: AppTable(
                          minWidth: 1050,
                          columns: const [
                            DataColumn2(
                              label: Text('Rider'),
                              size: ColumnSize.L,
                            ),
                            DataColumn2(label: Text('Status')),
                            DataColumn2(
                              label: Text('Deliveries'),
                              numeric: true,
                            ),
                            DataColumn2(
                              label: Text('Base salary'),
                              numeric: true,
                            ),
                            DataColumn2(
                              label: Text('Per delivery'),
                              numeric: true,
                            ),
                            DataColumn2(label: Text('Advance'), numeric: true),
                            DataColumn2(
                              label: Text('Net payable'),
                              numeric: true,
                            ),
                            DataColumn2(label: Text('Salary')),
                          ],
                          rows: controller.riders
                              .map(
                                (rider) => DataRow(
                                  onSelectChanged: (_) =>
                                      _openRider(context, rider),
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            child: Text(
                                              rider.name.trim().isEmpty
                                                  ? '?'
                                                  : rider.name
                                                        .trim()
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  rider.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(rider.phone),
                                              ],
                                            ),
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
                                    DataCell(
                                      Text(
                                        '${controller.deliveryCount(rider)}',
                                      ),
                                    ),
                                    DataCell(Text(Money.rs(rider.baseSalary))),
                                    DataCell(
                                      Text(Money.rs(rider.perDeliveryBonus)),
                                    ),
                                    DataCell(Text(Money.rs(rider.advance))),
                                    DataCell(
                                      Text(
                                        Money.rs(controller.netPay(rider)),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      StatusChip(
                                        label: controller.isPaid(rider)
                                            ? 'Paid'
                                            : 'Due',
                                        tone: controller.isPaid(rider)
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
                if (pendingInvites.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pending invites',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 58 * pendingInvites.length + 52,
                    child: AppTable(
                      minWidth: 790,
                      columns: const [
                        DataColumn2(label: Text('Name'), size: ColumnSize.L),
                        DataColumn2(label: Text('Phone')),
                        DataColumn2(label: Text('Base salary'), numeric: true),
                        DataColumn2(label: Text('Sent')),
                        DataColumn2(label: Text('Actions'), size: ColumnSize.L),
                      ],
                      rows: pendingInvites
                          .map(
                            (invite) => DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    invite.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(Text(invite.phone)),
                                DataCell(Text(Money.rs(invite.baseSalary))),
                                DataCell(
                                  Text(
                                    invite.sentAt == null
                                        ? '—'
                                        : '${invite.sentAt!.day}/${invite.sentAt!.month}/${invite.sentAt!.year}',
                                  ),
                                ),
                                DataCell(
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _confirmAndResend(context, invite),
                                        child: const Text('Resend'),
                                      ),
                                      TextButton(
                                        onPressed: () => _confirmAndMarkJoined(
                                          context,
                                          invite,
                                        ),
                                        child: const Text('Mark joined'),
                                      ),
                                      ConfirmTapButton(
                                        label: 'Cancel',
                                        confirmLabel: 'Cancel invite',
                                        confirmTitle: 'Cancel rider invite?',
                                        confirmMessage:
                                            'The invite link will no longer be valid.',
                                        onConfirmed: () async {
                                          try {
                                            await controller.cancelInvite(
                                              invite,
                                            );
                                          } catch (exception) {
                                            Get.snackbar(
                                              'Could not cancel invite',
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
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  });

  String _statusLabel(String status) => switch (status) {
    'on_delivery' => 'On delivery',
    'off_duty' => 'Off duty',
    _ => 'Available',
  };

  Future<void> _inviteRider(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final salary = TextEditingController(text: '30000');
    final bonus = TextEditingController(text: '25');
    final code = const Uuid().v4().substring(0, 8);
    final link = 'https://hoorain.pk/r/$code';
    RiderInviteRecord? invite;
    StateSetter? updateDrawer;
    final drawer = SideDrawer(
      title: 'Invite a rider',
      subtitle: 'The rider opens a one-time sign-up link.',
      body: StatefulBuilder(
        builder: (context, setDrawerState) {
          updateDrawer = setDrawerState;
          return Column(
            children: [
              TextField(
                controller: name,
                onChanged: (_) => setDrawerState(() {}),
                decoration: const InputDecoration(labelText: 'Rider name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: salary,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Base salary (Rs)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: bonus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bonus / delivery (Rs)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message preview',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hi ${name.text.isEmpty ? 'there' : name.text}, Hoorain invites you to join as a delivery rider. Sign up here: $link',
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        link,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (invite != null)
                const Text(
                  'Invite saved. The link can be sent again from Pending invites.',
                ),
            ],
          );
        },
      ),
      footer: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          AppButton(
            label: 'Cancel',
            style: AppButtonStyle.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          AppButton(
            label: 'Copy link',
            style: AppButtonStyle.ghost,
            onPressed: () async {
              try {
                invite = await _saveInvite(
                  name,
                  phone,
                  salary,
                  bonus,
                  code,
                  invite,
                );
                updateDrawer?.call(() {});
                await Clipboard.setData(ClipboardData(text: link));
                Get.snackbar('Invite saved · link copied', link);
              } catch (exception) {
                Get.snackbar('Could not create invite', exception.toString());
              }
            },
          ),
          AppButton(
            label: 'Send on WhatsApp',
            icon: const Icon(PhosphorIconsRegular.whatsappLogo),
            onPressed: () async {
              try {
                invite = await _saveInvite(
                  name,
                  phone,
                  salary,
                  bonus,
                  code,
                  invite,
                );
                updateDrawer?.call(() {});
                final message = Uri.encodeComponent(
                  'Hoorain invites you to join as a rider: $link',
                );
                final digits = phone.text.replaceAll(RegExp(r'\D'), '');
                final normalized = digits.startsWith('0')
                    ? '92${digits.substring(1)}'
                    : digits;
                final uri = Uri.parse(
                  'https://wa.me/$normalized?text=$message',
                );
                if (!await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                )) {
                  Get.snackbar(
                    'WhatsApp could not open',
                    'The invite was saved. Copy and share the link manually.',
                  );
                }
              } catch (exception) {
                Get.snackbar('Could not send invite', exception.toString());
              }
            },
          ),
        ],
      ),
    );
    await SideDrawer.show<void>(drawer);
    name.dispose();
    phone.dispose();
    salary.dispose();
    bonus.dispose();
  }

  Future<RiderInviteRecord> _saveInvite(
    TextEditingController name,
    TextEditingController phone,
    TextEditingController salary,
    TextEditingController bonus,
    String code,
    RiderInviteRecord? existing,
  ) async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      throw StateError('Enter the rider name and mobile number.');
    }
    final baseSalary = double.tryParse(salary.text) ?? 0;
    final deliveryBonus = double.tryParse(bonus.text) ?? 0;
    if (baseSalary < 0 || deliveryBonus < 0) {
      throw StateError('Salary terms cannot be negative.');
    }
    if (existing != null) return existing;
    return controller.createInvite(
      name: name.text.trim(),
      phone: phone.text.trim(),
      baseSalary: baseSalary,
      bonus: deliveryBonus,
      code: code,
    );
  }

  Future<void> _resend(RiderInviteRecord invite) async {
    try {
      await controller.resendInvite(invite);
      final digits = invite.phone.replaceAll(RegExp(r'\D'), '');
      final normalized = digits.startsWith('0')
          ? '92${digits.substring(1)}'
          : digits;
      final uri = Uri.parse(
        'https://wa.me/$normalized?text=${Uri.encodeComponent('Hoorain rider sign-up: https://hoorain.pk/r/${invite.code}')}',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Get.snackbar(
          'WhatsApp could not open',
          'The invite timestamp was refreshed, but the message must be shared manually.',
        );
      }
    } catch (exception) {
      Get.snackbar('Could not resend invite', exception.toString());
    }
  }

  Future<void> _markJoined(RiderInviteRecord invite) async {
    try {
      await controller.markInviteJoined(invite);
      Get.snackbar(
        'Rider added',
        '${invite.name} was added to the rider list.',
      );
    } catch (exception) {
      Get.snackbar('Could not add rider', exception.toString());
    }
  }

  Future<void> _confirmAndResend(
    BuildContext context,
    RiderInviteRecord invite,
  ) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Resend rider invite?',
      message: 'A new invitation message will be prepared for ${invite.name}.',
      icon: PhosphorIconsRegular.paperPlaneTilt,
      iconColor: Theme.of(context).colorScheme.primary,
      positiveButtonText: 'Resend',
    );
    if (confirmed == true) await _resend(invite);
  }

  Future<void> _confirmAndMarkJoined(
    BuildContext context,
    RiderInviteRecord invite,
  ) async {
    final confirmed = await CommonDialog.confirm(
      context: context,
      title: 'Mark rider as joined?',
      message:
          'This will add ${invite.name} to the rider list and close the invitation.',
      icon: PhosphorIconsRegular.userPlus,
      iconColor: Theme.of(context).colorScheme.primary,
      positiveButtonText: 'Mark joined',
    );
    if (confirmed == true) await _markJoined(invite);
  }

  Future<void> _openRider(BuildContext context, RiderRecord rider) async {
    final salaryHistory = await controller.salaryHistory(rider);
    if (!context.mounted) return;
    final base = TextEditingController(text: '${rider.baseSalary}');
    final bonus = TextEditingController(text: '${rider.perDeliveryBonus}');
    final fuel = TextEditingController(text: '${rider.fuelAllowance}');
    final advance = TextEditingController();
    var status = rider.status;
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
            const SizedBox(height: 18),
            Text(
              'This month · ${Money.rs(controller.netPay(rider))} net',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            _payLine('Base salary', Money.rs(rider.baseSalary)),
            _payLine(
              '${controller.deliveryCount(rider)} deliveries × ${Money.rs(rider.perDeliveryBonus)}',
              Money.rs(
                controller.deliveryCount(rider) * rider.perDeliveryBonus,
              ),
            ),
            _payLine('Fuel allowance', Money.rs(rider.fuelAllowance)),
            _payLine('Advance deduction', '− ${Money.rs(rider.advance)}'),
            const Divider(),
            TextField(
              controller: base,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Base salary (Rs)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bonus,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Per-delivery bonus (Rs)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fuel,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Fuel allowance (Rs)',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: advance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Give advance (Rs)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final amount = double.tryParse(advance.text) ?? 0;
                    if (amount <= 0) {
                      Get.snackbar(
                        'Enter an advance',
                        'The advance amount must be greater than zero.',
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
                      Get.snackbar(
                        'Advance recorded',
                        'The rider balance has been updated.',
                      );
                    } catch (exception) {
                      Get.snackbar(
                        'Could not add advance',
                        exception.toString(),
                      );
                    }
                  },
                  child: const Text('Add advance'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Salary history',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
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
                'This rider will be removed from the active rider list.',
            onConfirmed: () async {
              try {
                await controller.deleteRider(rider);
                if (context.mounted) Navigator.of(context).pop();
              } catch (exception) {
                Get.snackbar('Could not remove rider', exception.toString());
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
                  Get.snackbar(
                    'Salary paid',
                    'Payment and Salaries expense recorded.',
                  );
                } catch (exception) {
                  Get.snackbar('Could not pay salary', exception.toString());
                }
              },
            ),
          AppButton(
            label: 'Save',
            onPressed: () async {
              final confirmed = await CommonDialog.confirm(
                context: context,
                title: 'Save rider changes?',
                message:
                    'Update ${rider.name}’s status and salary terms with these values?',
                icon: PhosphorIconsRegular.floppyDisk,
                iconColor: Theme.of(context).colorScheme.primary,
                positiveButtonText: 'Save changes',
              );
              if (confirmed != true) return;
              try {
                await controller.saveRider(
                  rider.copyWith(
                    status: status,
                    baseSalary: double.tryParse(base.text) ?? 0,
                    perDeliveryBonus: double.tryParse(bonus.text) ?? 0,
                    fuelAllowance: double.tryParse(fuel.text) ?? 0,
                  ),
                );
                if (context.mounted) Navigator.of(context).pop();
              } catch (exception) {
                Get.snackbar('Could not save rider', exception.toString());
              }
            },
          ),
        ],
      ),
    );
    await SideDrawer.show<void>(drawer);
    base.dispose();
    bonus.dispose();
    fuel.dispose();
    advance.dispose();
  }

  Widget _payLine(String label, String amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
