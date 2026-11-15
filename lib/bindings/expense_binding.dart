import 'package:get/get.dart';

import '../controllers/expense_controller.dart';
import '../services/expense_service.dart';

class ExpenseBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExpenseService>(() => ExpenseService(), fenix: true);
    Get.lazyPut<ExpenseController>(
      () => ExpenseController(Get.find<ExpenseService>()),
    );
  }
}
