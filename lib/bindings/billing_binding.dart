import 'package:get/get.dart';

import '../controllers/billing_controller.dart';
import '../services/control_room_service.dart';

class BillingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<BillingController>(() => BillingController(Get.find()));
  }
}
