import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';

/// Dumb bottom navigation for Home | Entries | More.
class HisaabBottomNavBar extends StatelessWidget {
  const HisaabBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  selected: selectedIndex == 0,
                  icon: Icons.grid_view_rounded,
                  label: 'Home'.tr,
                  onTap: () => onChanged(0),
                ),
              ),
              Expanded(
                child: _NavItem(
                  selected: selectedIndex == 1,
                  icon: Icons.swap_vert_circle_outlined,
                  selectedIcon: Icons.swap_vert_circle,
                  label: 'Entries'.tr,
                  onTap: () => onChanged(1),
                ),
              ),
              Expanded(
                child: _NavItem(
                  selected: selectedIndex == 2,
                  icon: Icons.menu_rounded,
                  label: 'More'.tr,
                  onTap: () => onChanged(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selectedIcon,
  });

  final bool selected;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.brand : colors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? (selectedIcon ?? icon) : icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
