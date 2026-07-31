import 'package:get/get.dart';

class NavigationController extends GetxController {
  final selectedIndex = 0.obs;

  void select(int index) => selectedIndex.value = index;
}
