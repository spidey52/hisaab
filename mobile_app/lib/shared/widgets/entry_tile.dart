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

    final gave = entry.action == EntryAction.gave;
    final color = gave ? AppColors.red : AppColors.green;
    final soft = gave ? AppColors.redSoft : AppColors.greenSoft;
    final direction = gave ? 'You gave' : 'You got';
    final cancelled = entry.status == EntryStatus.cancelled;
    final syncLabel = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => 'Pending sync',
      LocalSyncStatus.needsAttention => 'Sync needs attention',
      LocalSyncStatus.synced => null,
    };
    final note = entry.narration.trim();

    return Semantics(
      button: onTap != null,
      label:
          '$direction ${formatMoney(entry.amountPaise, absolute: true)} '
          '${entry.partyName}${syncLabel == null ? '' : ', $syncLabel'}',
      child: Opacity(
        opacity: cancelled ? 0.72 : 1,
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
                              fontWeight: FontWeight.w800,
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
                              ?.copyWith(color: AppColors.muted),
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
                              'Entry ${entry.sequence}',
                              style: _metaStyle(context),
                            ),
                          if (showStatus && entry.editedAt != null)
                            const _StatusLabel(label: 'Edited'),
                          if (showStatus && cancelled)
                            const _StatusLabel(
                              label: 'Cancelled',
                              color: AppColors.red,
                            ),
                          if (showStatus && syncLabel != null)
                            _StatusLabel(
                              label: syncLabel,
                              color:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? AppColors.red
                                  : AppColors.amber,
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
                                color: AppColors.muted,
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.muted,
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
    final cancelled = entry.status == EntryStatus.cancelled;
    final syncLabel = switch (entry.localSyncStatus) {
      LocalSyncStatus.pending => 'Pending sync',
      LocalSyncStatus.needsAttention => 'Sync needs attention',
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
        opacity: cancelled ? 0.72 : 1,
        child: _TappableTile(
          onTap: onTap,
          child: Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DirectionMark(
                  icon: Icons.flag_outlined,
                  foreground: AppColors.amber,
                  background: Color(0xFFFFF3E7),
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
                              fontWeight: FontWeight.w800,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        direction,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
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
                              'Entry ${entry.sequence}',
                              style: _metaStyle(context),
                            ),
                          if (cancelled)
                            const _StatusLabel(
                              label: 'Cancelled',
                              color: AppColors.red,
                            ),
                          if (syncLabel != null)
                            _StatusLabel(
                              label: syncLabel,
                              color:
                                  entry.localSyncStatus ==
                                      LocalSyncStatus.needsAttention
                                  ? AppColors.red
                                  : AppColors.amber,
                            ),
                        ],
                      ),
                      if (runningBalancePaise != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          balanceSentenceText(runningBalancePaise!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.muted,
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
                    color: AppColors.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.muted,
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
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
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

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, this.color = AppColors.muted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

TextStyle? _metaStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted);
