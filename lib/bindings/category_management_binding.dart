import 'package:get/get.dart';

import '../controllers/category_management_controller.dart';
import '../controllers/product_management_controller.dart';
import '../services/control_room_service.dart';

class CategoryManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<CategoryManagementController>(
      () => CategoryManagementController(Get.find<ControlRoomService>()),
    );
    Get.lazyPut<ProductManagementController>(
      () => ProductManagementController(Get.find<ControlRoomService>()),
    );
  }
}
