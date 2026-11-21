import 'package:get/get.dart';

import '../controllers/inventory_controller.dart';
import '../controllers/product_management_controller.dart';
import '../services/control_room_service.dart';
import '../services/inventory_service.dart';

class InventoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryService>(() => InventoryService());
    Get.lazyPut<InventoryController>(() => InventoryController(Get.find()));
    Get.lazyPut<ControlRoomService>(() => ControlRoomService(), fenix: true);
    Get.lazyPut<ProductManagementController>(
      () => ProductManagementController(Get.find<ControlRoomService>()),
      fenix: true,
    );
  }
}
