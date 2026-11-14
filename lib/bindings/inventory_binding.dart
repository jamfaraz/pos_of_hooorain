import 'package:get/get.dart';

import '../controllers/inventory_controller.dart';
import '../services/control_room_service.dart';

class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<InventoryController>(() => InventoryController(Get.find()));
  }
}
