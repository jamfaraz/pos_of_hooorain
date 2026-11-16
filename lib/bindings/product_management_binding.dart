import 'package:get/get.dart';

import '../controllers/product_management_controller.dart';
import '../services/control_room_service.dart';

class ProductManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService(), fenix: true);
    Get.lazyPut<ProductManagementController>(
      () => ProductManagementController(Get.find<ControlRoomService>()),
      fenix: true,
    );
  }
}
