import 'package:get/get.dart';

import '../controllers/setting_controller.dart';

class StoreSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StoreSetupController>(() => StoreSetupController());
  }
}
