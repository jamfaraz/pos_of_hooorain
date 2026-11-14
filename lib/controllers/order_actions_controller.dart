import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../models/order_model.dart';
import '../models/rider_record.dart';
import '../services/control_room_service.dart';

class OrderActionsController extends GetxController {
  OrderActionsController(this._service, this.order);

  final ControlRoomService _service;
  final OrderModel order;
  final riders = <RiderRecord>[].obs;
  final assignedRiderId = RxnString();
  final loadingRiders = true.obs;
  final error = RxnString();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridersSub;

  @override
  void onInit() {
    super.onInit();
    assignedRiderId.value = order.riderId;
    reloadRiders();
  }

  void reloadRiders() {
    loadingRiders.value = true;
    error.value = null;
    _ridersSub?.cancel();
    _ridersSub = _service.watchRiders().listen(
      (snapshot) {
        riders.assignAll(
          snapshot.docs.map(
            (doc) => RiderRecord.fromMap(doc.data(), id: doc.id),
          ),
        );
        loadingRiders.value = false;
      },
      onError: (Object exception) {
        error.value = exception.toString();
        loadingRiders.value = false;
      },
    );
  }

  Future<void> assignRider(String? riderId) async {
    try {
      await _service.assignOrderRider(order.id, riderId);
      assignedRiderId.value = riderId;
    } catch (exception) {
      error.value = exception.toString();
      rethrow;
    }
  }

  @override
  void onClose() {
    _ridersSub?.cancel();
    super.onClose();
  }
}
