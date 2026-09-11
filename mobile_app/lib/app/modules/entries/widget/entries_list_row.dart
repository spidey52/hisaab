import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../shared/widget/ledger_activity_row.dart';

/// Entry row matching the Entries screenshot (RECEIVED / PAID).
class EntriesListRow extends StatelessWidget {
  const EntriesListRow({
    super.key,
    required this.entry,
    this.onTap,
    this.titleOverride,
    this.useDirectionAvatar = false,
  });

  final LedgerEntry entry;
  final VoidCallback? onTap;

  /// When set (e.g. party detail), shown instead of the party name.
  final String? titleOverride;

  /// Use + / − in the avatar instead of a name initial.
  final bool useDirectionAvatar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gave = entry.action == EntryAction.gave;
    final received = entry.action == EntryAction.received;
    final cancelled = entry.status == EntryStatus.cancelled;

    final avatarBackground = gave
        ? colors.redSoft
        : received
        ? colors.greenSoft
        : colors.amberSoft;
    final avatarForeground = gave
        ? colors.red
        : received
        ? colors.green
        : colors.amber;

    final (badgeLabel, badgeFg, badgeBg) = entry.isOpeningBalance
        ? ('OPENING', colors.amber, colors.amberSoft)
        : gave
        ? ('PAID', colors.muted, colors.settledSoft)
        : ('RECEIVED', colors.green, colors.greenSoft);

    final amountText = entry.isOpeningBalance
        ? formatMoney(entry.amountPaise, absolute: true)
        : formatSignedScreenshotMoney(entry.amountPaise, negative: gave);
    final amountColor = gave
        ? colors.red
        : received
        ? colors.green
        : colors.amber;

    final title =
        titleOverride ??
        (entry.partyName.trim().isEmpty ? 'Entry' : entry.partyName);
    final letter = useDirectionAvatar
        ? (entry.isOpeningBalance ? 'O' : (gave ? '−' : '+'))
        : avatarInitial(title);

    return LedgerActivityRow(
      title: title,
      badgeLabel: badgeLabel,
      badgeForeground: badgeFg,
      badgeBackground: badgeBg,
      timeLabel: formatActivityTimeOrNull(activityTimeOfEntry(entry)),
      amountText: amountText,
      amountColor: amountColor,
      avatarLetter: letter,
      avatarForeground: avatarForeground,
      avatarBackground: avatarBackground,
      onTap: onTap,
      dimmed: cancelled,
    );
  }
}
