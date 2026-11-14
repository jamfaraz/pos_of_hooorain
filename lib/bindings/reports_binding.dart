import 'package:get/get.dart';

import '../controllers/reports_controller.dart';
import '../services/control_room_service.dart';
import '../services/report_export_service.dart';

class ReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ControlRoomService>(() => ControlRoomService());
    Get.lazyPut<ReportExportService>(() => ReportExportService());
    Get.lazyPut<ReportsController>(
      () => ReportsController(Get.find(), Get.find()),
    );
  }
}
