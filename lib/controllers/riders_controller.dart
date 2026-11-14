import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/rider_invite_record.dart';
import '../models/rider_record.dart';
import '../services/control_room_service.dart';
import '../utils/rider_pay.dart';

class RidersController extends GetxController {
  RidersController(this._service);

  final ControlRoomService _service;
  final riders = <RiderRecord>[].obs;
  final invites = <RiderInviteRecord>[].obs;
  final deliveries = <String, int>{}.obs;
  final paidThisMonth = <String, bool>{}.obs;
  final loading = true.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _invitesSub;

  DateTime get monthStart =>
      DateTime(DateTime.now().year, DateTime.now().month);
  String get monthId =>
      '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}';

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  void reload() {
    loading.value = true;
    error.value = null;
    _ridersSub?.cancel();
    _invitesSub?.cancel();
    _ridersSub = _service.watchRiders().listen(
      (snapshot) {
        riders.assignAll(
          snapshot.docs.map(
            (doc) => RiderRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        loading.value = false;
        _loadMonthSummary();
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loading.value = false;
      },
    );
    _invitesSub = _service.watchRiderInvites().listen((snapshot) {
      invites.assignAll(
        snapshot.docs.map(
          (doc) => RiderInviteRecord.fromMap(doc.data(), id: doc.id),
        ),
      );
    }, onError: (Object exception) => error.value = exception.toString());
  }

  Future<void> _loadMonthSummary() async {
    try {
      for (final rider in riders) {
        final id = rider.id;
        if (id == null) continue;
        final count = await _service.getMonthlyDeliveryCount(id, monthStart);
        deliveries[id] = count;
        paidThisMonth[id] = await _service.isSalaryPaid(id, monthId);
      }
    } catch (exception) {
      error.value = exception.toString();
    }
  }

  int deliveryCount(RiderRecord rider) =>
      rider.id == null ? 0 : deliveries[rider.id] ?? 0;
  bool isPaid(RiderRecord rider) =>
      rider.id != null && (paidThisMonth[rider.id] ?? false);

  double netPay(RiderRecord rider) => riderNetPay(
    baseSalary: rider.baseSalary,
    deliveries: deliveryCount(rider),
    perDeliveryBonus: rider.perDeliveryBonus,
    fuelAllowance: rider.fuelAllowance,
    advance: rider.advance,
  );

  double get totalAdvances =>
      riders.fold(0, (total, rider) => total + rider.advance);
  double get salaryPayable => riders.fold(
    0,
    (total, rider) => total + (isPaid(rider) ? 0 : netPay(rider)),
  );

  Future<RiderInviteRecord> createInvite({
    required String name,
    required String phone,
    required double baseSalary,
    required double bonus,
    required String code,
  }) async {
    final invite = RiderInviteRecord(
      name: name,
      phone: phone,
      baseSalary: baseSalary,
      perDeliveryBonus: bonus,
      code: code,
      sentAt: DateTime.now(),
    );
    try {
      final id = await _service.createRiderInvite(invite);
      return RiderInviteRecord(
        id: id,
        name: invite.name,
        phone: invite.phone,
        baseSalary: invite.baseSalary,
        perDeliveryBonus: invite.perDeliveryBonus,
        code: invite.code,
        sentAt: invite.sentAt,
      );
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<void> markInviteJoined(RiderInviteRecord invite) async {
    try {
      await _service.markInviteJoined(invite);
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  Future<void> cancelInvite(RiderInviteRecord invite) async {
    if (invite.id == null) throw StateError('Invite has no document ID.');
    await _service.cancelRiderInvite(invite.id!);
  }

  Future<void> resendInvite(RiderInviteRecord invite) async {
    if (invite.id == null) throw StateError('Invite has no document ID.');
    await _service.resendRiderInvite(invite.id!);
  }

  Future<List<Map<String, dynamic>>> salaryHistory(RiderRecord rider) async {
    if (rider.id == null) return const [];
    return _service.getSalaryHistory(rider.id!);
  }

  Future<void> saveRider(RiderRecord rider) async {
    await _service.saveRider(rider);
  }

  Future<void> giveAdvance(RiderRecord rider, double amount) async {
    if (rider.id == null) throw StateError('Rider has no document ID.');
    await _service.giveRiderAdvance(rider.id!, amount);
  }

  Future<void> paySalary(RiderRecord rider) async {
    final id = rider.id;
    if (id == null) throw StateError('Rider has no document ID.');
    if (isPaid(rider)) {
      throw StateError('Salary for this month is already paid.');
    }
    await _service.payRiderSalary(
      rider: rider,
      monthId: monthId,
      amount: netPay(rider),
    );
    paidThisMonth[id] = true;
  }

  Future<void> deleteRider(RiderRecord rider) async {
    if (rider.id == null) throw StateError('Rider has no document ID.');
    await _service.deleteRider(rider.id!);
  }

  @override
  void onClose() {
    _ridersSub?.cancel();
    _invitesSub?.cancel();
    super.onClose();
  }
}
