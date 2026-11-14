import 'package:get/get.dart';

import '../controllers/offers_controller.dart';
import '../services/control_room_service.dart';

class OffersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<OffersController>(() => OffersController(Get.find()));
  }
}
