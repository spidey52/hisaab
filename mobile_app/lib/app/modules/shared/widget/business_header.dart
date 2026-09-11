import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../app.dart';

/// Green store header shared by Home, Entries, and More.
///
/// Keep this outside scroll views (fixed like an AppBar) so the business
/// chrome and optional summary stay pinned while list content scrolls.
class BusinessHeader extends StatelessWidget {
  const BusinessHeader({
    super.key,
    required this.businessName,
    this.bottom,
    this.onBusinessTap,
  });

  final String businessName;
  final Widget? bottom;
  final VoidCallback? onBusinessTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        width: double.infinity,
        color: colors.brand,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: InkWell(
                  onTap: onBusinessTap ?? () => Get.toNamed(AppRoutes.settings),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.onBrand.withValues(alpha: 0.55),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: colors.onBrand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: displayStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colors.onBrand,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Icon(Icons.settings_rounded, color: colors.onBrand),
                    ],
                  ),
                ),
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}
