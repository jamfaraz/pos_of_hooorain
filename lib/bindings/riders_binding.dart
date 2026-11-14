import 'package:get/get.dart';

import '../controllers/riders_controller.dart';
import '../services/control_room_service.dart';

class RidersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<RidersController>(() => RidersController(Get.find()));
  }
}
