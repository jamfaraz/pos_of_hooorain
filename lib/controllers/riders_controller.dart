import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/rider_record.dart';
import '../services/control_room_service.dart';
import '../services/rider_service.dart';
import '../utils/rider_pay.dart';

class RidersController extends GetxController {
  RidersController(this._service, {RiderAccountService? accounts})
    : _accounts = accounts ?? RiderAccountService();

  final ControlRoomService _service;
  final RiderAccountService _accounts;
  final riders = <RiderRecord>[].obs;
  final deliveries = <String, int>{}.obs;
  final paidThisMonth = <String, bool>{}.obs;
  final loading = true.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridersSub;

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

  /// Creates the rider's login (Firebase Auth) and the rider document.
  /// The document id is the Auth uid, so the rider app can read
  /// `riders/{uid}` directly. Returns the new uid.
  ///
  /// Note: this deliberately does not touch [error], because a failed
  /// create must not replace the whole page with the error screen.
  Future<String> createRider({
    required RiderRecord draft,
    required String password,
  }) {
    return _accounts.createRiderLogin(
      email: draft.email,
      password: password,
      onCreated: (uid) => _service.saveRider(
        draft.copyWith(id: uid, uid: uid, joinedAt: DateTime.now()),
      ),
    );
  }

  Future<void> sendPasswordReset(RiderRecord rider) async {
    if (rider.email.trim().isEmpty) {
      throw StateError('This rider has no login email on file.');
    }
    await _accounts.sendPasswordReset(rider.email);
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

  /// Removes the rider document. The Auth login is blocked automatically
  /// because the rider app and Firestore rules require an active rider doc.
  Future<void> deleteRider(RiderRecord rider) async {
    if (rider.id == null) throw StateError('Rider has no document ID.');
    await _service.deleteRider(rider.id!);
  }

  @override
  void onClose() {
    _ridersSub?.cancel();
    super.onClose();
  }
}
