import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';
import 'balance_widgets.dart';

/// Compact two-line party row: name on one full-width line, a merged
/// phone-and-entry-count line beneath it, and the balance right-aligned
/// with a short caption. Direction is carried by color, sign, and the
/// caption together — never color alone.
class PartyTile extends StatelessWidget {
  const PartyTile({
    super.key,
    required this.party,
    this.onTap,
    this.showTransactionCount = false,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 12,
    ),
  });

  final Party party;
  final VoidCallback? onTap;
  final bool showTransactionCount;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final kind = party.balanceKind;
    final tones = balanceTones(context, kind);
    final semanticBalance = balanceKindLabel(kind).tr;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.35;
    final identity = _PartyIdentity(
      party: party,
      color: tones.foreground,
      soft: tones.background,
      secondary: _secondaryLine(),
    );
    final balance = _PartyBalance(kind: kind, party: party, tones: tones);

    final child = Padding(
      padding: contentPadding,
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 53),
                  child: Align(alignment: Alignment.centerLeft, child: balance),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 10),
                balance,
              ],
            ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label:
          '${party.name}, $semanticBalance'
          '${kind == BalanceKind.settled ? '' : ' ${formatMoney(party.balancePaise, absolute: true)}'}',
      child: Opacity(
        opacity: party.isArchived ? 0.65 : 1,
        child: onTap == null
            ? child
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
              ),
      ),
    );
  }

  String _secondaryLine() {
    final phone = party.phone.trim().isEmpty
        ? ''
        : _compactPhone(formatPhoneForDisplay(party.phone));
    final identity = phone.isNotEmpty ? phone : party.shortName.trim();
    if (!showTransactionCount || party.transactionCount <= 0) return identity;
    final count =
        '${party.transactionCount} '
        '${party.transactionCount == 1 ? 'entry' : 'entries'}';
    return identity.isEmpty ? count : '$identity · $count';
  }

  /// Local numbers drop the +91 prefix so they fit without truncation;
  /// foreign numbers keep their country code.
  static String _compactPhone(String display) =>
      display.startsWith('+91 ') ? display.substring(4) : display;
}

class _PartyIdentity extends StatelessWidget {
  const _PartyIdentity({
    required this.party,
    required this.color,
    required this.soft,
    required this.secondary,
  });

  final Party party;
  final Color color;
  final Color soft;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            initials(party.name),
            style: displayStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      party.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (party.isArchived) ...[
                    const SizedBox(width: 7),
                    const _ArchivedLabel(),
                  ],
                ],
              ),
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.muted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PartyBalance extends StatelessWidget {
  const _PartyBalance({
    required this.kind,
    required this.party,
    required this.tones,
  });

  final BalanceKind kind;
  final Party party;
  final ({Color foreground, Color background, Color border}) tones;

  @override
  Widget build(BuildContext context) {
    if (kind == BalanceKind.settled) {
      final colors = context.colors;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: colors.settledSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Settled'.tr,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final caption = (kind == BalanceKind.receive ? 'To receive' : 'To pay').tr;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formatMoney(party.balancePaise, absolute: true),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tones.foreground,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            caption,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tones.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedLabel extends StatelessWidget {
  const _ArchivedLabel();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.settledSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Archived',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
