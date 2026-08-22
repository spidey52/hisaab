import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/sync_strip.dart';
import '../entries/entries_page.dart';
import '../home/home_page.dart';
import '../parties/parties_page.dart';
import '../settings/settings_page.dart';
import 'navigation_controller.dart';

class AppShell extends GetView<NavigationController> {
  const AppShell({super.key});

  static const List<Widget> _pages = [
    HomePage(),
    PartiesPage(),
    EntriesPage(),
    MorePage(),
  ];

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.select,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories_rounded),
              label: 'Home'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: 'Parties'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: 'Entries'.tr,
            ),
            NavigationDestination(
              icon: const Icon(Icons.more_horiz_rounded),
              label: 'More'.tr,
            ),
          ],
        ),
      ),
    );
  }
}
