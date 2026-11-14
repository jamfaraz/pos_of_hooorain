import 'package:get/get.dart';

import '../controllers/dashboard_controller.dart';
import '../controllers/order_controller.dart';
import '../services/control_room_service.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<DashboardController>(() => DashboardController(Get.find()));
    if (!Get.isRegistered<OrderController>()) {
      Get.put<OrderController>(OrderController(), permanent: true);
    }
  }
}
