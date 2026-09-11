import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_utils.dart';
import '../../../../data/repositories/ledger_repository.dart';
import '../../shared/widget/business_header.dart';
import '../controllers/more_controller.dart';

class MoreView extends GetView<MoreController> {
  const MoreView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => BusinessHeader(businessName: controller.businessName)),
          Expanded(
            child: Obx(() {
              final lastBackup = controller.lastSyncedLabel;
              final phone = controller.userPhone.trim();
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _ProfileCard(
                          name: controller.userName,
                          phone: phone.isEmpty
                              ? null
                              : formatPhoneForDisplay(phone),
                          businessName: controller.businessName,
                          connectionMode: controller.connectionMode,
                          onTap: controller.openSettings,
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel(label: 'PREFERENCES'),
                        const SizedBox(height: 8),
                        _MoreCard(
                          children: [
                            _MoreTile(
                              icon: Icons.settings_outlined,
                              title: 'Settings'.tr,
                              subtitle: 'Manage your app preferences',
                              onTap: controller.openSettings,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _SectionLabel(label: 'DATA'),
                        const SizedBox(height: 8),
                        _MoreCard(
                          children: [
                            _MoreTile(
                              icon: Icons.cloud_done_outlined,
                              title: 'Backup & Restore',
                              subtitle: 'Your data is safely backed up',
                              extra: lastBackup,
                              onTap: () => _pickExport(context),
                              trailing: controller.exporting.value
                                  ? const _TileSpinner()
                                  : null,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 62,
                              color: colors.line,
                            ),
                            _MoreTile(
                              icon: Icons.ios_share_rounded,
                              title: 'Export Data',
                              subtitle: 'Save or share your records',
                              onTap: () => _pickExport(context),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 62,
                              color: colors.line,
                            ),
                            _MoreTile(
                              icon: Icons.sync_rounded,
                              title: 'Refresh data'.tr,
                              subtitle: controller.ledger.isOffline.value
                                  ? 'Try connecting to the server again'
                                  : 'Download the latest ledger',
                              onTap: controller.ledger.loading.value
                                  ? null
                                  : controller.refreshData,
                              trailing: controller.ledger.loading.value
                                  ? const _TileSpinner()
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _SectionLabel(label: 'SUPPORT'),
                        const SizedBox(height: 8),
                        _MoreCard(
                          children: [
                            _MoreTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help & Support',
                              subtitle: 'Get help using Hisaab',
                              onTap: controller.openHelp,
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 62,
                              color: colors.line,
                            ),
                            _MoreTile(
                              icon: Icons.info_outline_rounded,
                              title: 'About Hisaab',
                              subtitle: 'Version ${controller.appVersion}',
                              onTap: () => controller.showAbout(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const _PrivacyBanner(),
                        const SizedBox(height: 18),
                        _SignOutButton(
                          busy: controller.auth.busy.value,
                          onPressed: () => controller.confirmLogout(context),
                        ),
                      ]),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExport(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final format = await showModalBottomSheet<LedgerExportFormat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ExportSheet(),
    );
    if (format == null) return;
    await controller.exportData(format, origin);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.businessName,
    required this.connectionMode,
    required this.onTap,
    this.phone,
  });

  final String name;
  final String? phone;
  final String businessName;
  final String connectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.greenSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.greenDark,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: displayStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone ?? businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.settledSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          connectionMode,
                          style: TextStyle(
                            color: colors.brand,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.colors.brand,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.05,
      ),
    );
  }
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.extra,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? extra;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colors.greenDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: colors.ink,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    if (extra != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        extra!,
                        style: TextStyle(
                          color: colors.greenDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileSpinner extends StatelessWidget {
  const _TileSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: context.colors.brand,
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: Color.alphaBlend(
              colors.green.withValues(alpha: 0.18),
              colors.line,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: colors.greenDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your data is safe with us',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: colors.ink,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We never share your information with anyone.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline_rounded, color: colors.brand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.red,
        side: BorderSide(
          color: Color.alphaBlend(
            colors.red.withValues(alpha: 0.35),
            colors.line,
          ),
        ),
        backgroundColor: colors.redSoft.withValues(alpha: 0.35),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.red,
              ),
            )
          : const Icon(Icons.logout_rounded, size: 20),
      label: Text(
        'Sign out'.tr,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ExportSheet extends StatelessWidget {
  const _ExportSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Export data',
                style: displayStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose a format to save or share',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _MoreCard(
                children: [
                  _MoreTile(
                    icon: Icons.data_object_rounded,
                    title: 'JSON backup'.tr,
                    subtitle: 'Full ledger backup file',
                    onTap: () =>
                        Navigator.pop(context, LedgerExportFormat.json),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 62,
                    color: colors.line,
                  ),
                  _MoreTile(
                    icon: Icons.table_chart_outlined,
                    title: 'CSV entries'.tr,
                    subtitle: 'Spreadsheet-friendly entry list',
                    onTap: () => Navigator.pop(context, LedgerExportFormat.csv),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
