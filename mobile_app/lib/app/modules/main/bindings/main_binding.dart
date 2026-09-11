import 'package:get/get.dart';

import '../../entries/controllers/entries_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../more/controllers/more_controller.dart';
import '../controllers/main_controller.dart';

class MainBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<MainController>()) {
      Get.put<MainController>(MainController(), permanent: true);
    }
    Get.lazyPut<HomeController>(HomeController.new, fenix: true);
    Get.lazyPut<EntriesController>(EntriesController.new, fenix: true);
    Get.lazyPut<MoreController>(MoreController.new, fenix: true);
  }
}
