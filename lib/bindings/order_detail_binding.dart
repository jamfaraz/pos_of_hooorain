import 'package:get/get.dart';

import '../controllers/order_actions_controller.dart';
import '../models/order_model.dart';
import '../services/control_room_service.dart';

class OrderDetailBinding extends Bindings {
  @override
  void dependencies() {
    final order = Get.arguments as OrderModel;
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<OrderActionsController>(
      () => OrderActionsController(Get.find(), order),
    );
  }
}
