import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import 'balance_widgets.dart';

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.runningBalancePaise,
    this.showPartyName = true,
    this.showStatus = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 13,
    ),
  });

  final LedgerEntry entry;
  final VoidCallback? onTap;
  final int? runningBalancePaise;
  final bool showPartyName;
  final bool showStatus;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    if (entry.isOpeningBalance) {
      return _OpeningBalanceTile(
        entry: entry,
        onTap: onTap,
        runningBalancePaise: runningBalancePaise,
        contentPadding: contentPadding,
      );
    }

    final colors = context.colors;
    final gave = entry.action == EntryAction.gave;
    final color = gave ? colors.red : colors.greenDark;
    final soft = gave ? colors.redSoft : colors.greenSoft;
    final direction = gave ? 'You gave' : 'You got';
    final cancelled = entry.status == EntryStatus.cancelled;
    final syncLabel = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => 'Pending sync',
      LocalSyncStatus.needsAttention => 'Needs attention',
      LocalSyncStatus.synced => null,
    };
    final note = entry.narration.trim();

    return Semantics(
      button: onTap != null,
      label:
          '$direction ${formatMoney(entry.amountPaise, absolute: true)} '
          '${entry.partyName}${syncLabel == null ? '' : ', $syncLabel'}',
      child: Opacity(
        opacity: cancelled ? 0.65 : 1,
        child: _TappableTile(
          onTap: onTap,
          child: Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DirectionMark(
                  text: gave ? '−' : '+',
                  foreground: color,
                  background: soft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showPartyName ? entry.partyName : direction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      if (note.isNotEmpty && showPartyName) ...[
                        const SizedBox(height: 3),
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.muted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatShortDate(entry.entryDate),
                            style: _metaStyle(context),
                          ),
                          if (entry.sequence > 0)
                            Text(
                              '· No. ${entry.sequence}',
                              style: _metaStyle(context),
                            ),
                          if (showStatus && entry.editedAt != null)
                            _StatusPill(
                              label: 'Edited',
                              foreground: colors.muted,
                              background: colors.settledSoft,
                            ),
                          if (showStatus && cancelled)
                            _StatusPill(
                              label: 'Cancelled',
                              foreground: colors.red,
                              background: colors.redSoft,
                            ),
                          if (showStatus && syncLabel != null)
                            _StatusPill(
                              label: syncLabel,
                              foreground:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? colors.red
                                  : colors.amber,
                              background:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? colors.redSoft
                                  : colors.amberSoft,
                            ),
                        ],
                      ),
                      if (runningBalancePaise != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          balanceSentenceText(runningBalancePaise!),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 118),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatSignedEntryMoney(entry.amountPaise, gave: gave),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        direction,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningBalanceTile extends StatelessWidget {
  const _OpeningBalanceTile({
    required this.entry,
    required this.onTap,
    required this.runningBalancePaise,
    required this.contentPadding,
  });

  final LedgerEntry entry;
  final VoidCallback? onTap;
  final int? runningBalancePaise;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cancelled = entry.status == EntryStatus.cancelled;
    final syncLabel = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => 'Pending sync',
      LocalSyncStatus.needsAttention => 'Needs attention',
      LocalSyncStatus.synced => null,
    };
    final direction = entry.balanceEffectPaise > 0
        ? 'They owed you'
        : entry.balanceEffectPaise < 0
        ? 'You owed them'
        : 'No starting balance';

    return Semantics(
      button: onTap != null,
      label:
          'Opening balance, $direction, ${formatMoney(entry.amountPaise, absolute: true)}',
      child: Opacity(
        opacity: cancelled ? 0.65 : 1,
        child: _TappableTile(
          onTap: onTap,
          child: Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DirectionMark(
                  icon: Icons.flag_outlined,
                  foreground: colors.amber,
                  background: colors.amberSoft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opening balance',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        direction,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          Text(
                            formatShortDate(entry.entryDate),
                            style: _metaStyle(context),
                          ),
                          if (entry.sequence > 0)
                            Text(
                              '· No. ${entry.sequence}',
                              style: _metaStyle(context),
                            ),
                          if (cancelled)
                            _StatusPill(
                              label: 'Cancelled',
                              foreground: colors.red,
                              background: colors.redSoft,
                            ),
                          if (syncLabel != null)
                            _StatusPill(
                              label: syncLabel,
                              foreground:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? colors.red
                                  : colors.amber,
                              background:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? colors.redSoft
                                  : colors.amberSoft,
                            ),
                        ],
                      ),
                      if (runningBalancePaise != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          balanceSentenceText(runningBalancePaise!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatMoney(entry.amountPaise, absolute: true),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.amber,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionMark extends StatelessWidget {
  const _DirectionMark({
    this.text,
    this.icon,
    required this.foreground,
    required this.background,
  });

  final String? text;
  final IconData? icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: icon == null
          ? Text(
              text ?? '',
              style: TextStyle(
                color: foreground,
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            )
          : Icon(icon, color: foreground, size: 22),
    );
  }
}

class _TappableTile extends StatelessWidget {
  const _TappableTile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

TextStyle? _metaStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: context.colors.muted);
