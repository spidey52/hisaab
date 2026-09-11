import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/sync_strip.dart';
import '../../entries/views/entries_view.dart';
import '../../home/views/home_view.dart';
import '../../more/views/more_view.dart';
import '../controllers/main_controller.dart';
import '../widget/bottom_nav_bar.dart';

/// Authenticated shell: Home | Entries | More.
class MainView extends GetView<MainController> {
  const MainView({super.key});

  static const List<Widget> _pages = [HomeView(), EntriesView(), MoreView()];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: controller.selectedIndex.value,
                children: _pages,
              ),
            ),
            const SyncStrip(),
          ],
        ),
        bottomNavigationBar: HisaabBottomNavBar(
          selectedIndex: controller.selectedIndex.value,
          onChanged: controller.changeTab,
        ),
      ),
    );
  }
}
