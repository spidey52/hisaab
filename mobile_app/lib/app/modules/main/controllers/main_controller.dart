import 'package:get/get.dart';

/// Owns only the authenticated shell's bottom-navigation tab state.
class MainController extends GetxController {
  final selectedIndex = 0.obs;

  void changeTab(int index) {
    if (index < 0 || index > 2) return;
    selectedIndex.value = index;
  }

  /// Alias kept for call sites that previously used [NavigationController.select].
  void select(int index) => changeTab(index);
}
