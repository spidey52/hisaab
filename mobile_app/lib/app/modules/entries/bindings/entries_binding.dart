import 'package:get/get.dart';

import '../controllers/entries_controller.dart';

class EntriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<EntriesController>(EntriesController.new);
  }
}
