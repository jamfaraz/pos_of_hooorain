import 'package:get/get.dart';

import '../controllers/item_profit_controller.dart';
import '../services/control_room_service.dart';

class ItemProfitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<ItemProfitController>(() => ItemProfitController(Get.find()));
  }
}
