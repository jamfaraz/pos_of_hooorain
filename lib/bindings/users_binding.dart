import 'package:get/get.dart';

import '../controllers/user_controller.dart';

class UsersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UsersController>(() => UsersController());
  }
}
