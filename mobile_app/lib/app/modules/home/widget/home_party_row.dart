import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../shared/widget/ledger_activity_row.dart';

/// Party row matching the Home screenshot.
class HomePartyRow extends StatelessWidget {
  const HomePartyRow({
    super.key,
    required this.party,
    this.lastEntry,
    this.onTap,
  });

  final Party party;
  final LedgerEntry? lastEntry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final kind = party.balanceKind;
    final isPay = kind == BalanceKind.pay;
    final isReceive = kind == BalanceKind.receive;
    final avatar = avatarColorsForName(party.name, colors);

    final (badgeLabel, badgeFg, badgeBg) = switch (kind) {
      BalanceKind.receive => ('RECEIVED', colors.green, colors.greenSoft),
      BalanceKind.pay => ('GAVE', colors.muted, colors.settledSoft),
      BalanceKind.settled => ('SETTLED', colors.muted, colors.settledSoft),
    };

    final amountColor = isPay
        ? colors.red
        : isReceive
        ? colors.green
        : colors.muted;
    final amountText = kind == BalanceKind.settled
        ? formatMoney(0, absolute: true)
        : formatSignedScreenshotMoney(party.balancePaise, negative: isPay);

    final when = activityTimeOfParty(party: party, lastEntry: lastEntry);

    return LedgerActivityRow(
      title: party.name,
      badgeLabel: badgeLabel,
      badgeForeground: badgeFg,
      badgeBackground: badgeBg,
      timeLabel: formatActivityTimeOrNull(when),
      amountText: amountText,
      amountColor: amountColor,
      avatarLetter: avatarInitial(party.name),
      avatarForeground: avatar.foreground,
      avatarBackground: avatar.background,
      onTap: onTap,
      dimmed: party.isArchived,
    );
  }
}
