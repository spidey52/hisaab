import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/models.dart';

class PartyTile extends StatelessWidget {
  const PartyTile({
    super.key,
    required this.party,
    this.onTap,
    this.onCall,
    this.showTransactionCount = false,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 12,
    ),
  });

  final Party party;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final bool showTransactionCount;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final kind = party.balanceKind;
    final color = switch (kind) {
      BalanceKind.receive => AppColors.greenDark,
      BalanceKind.pay => AppColors.red,
      BalanceKind.settled => AppColors.muted,
    };
    final soft = switch (kind) {
      BalanceKind.receive => AppColors.greenSoft,
      BalanceKind.pay => AppColors.redSoft,
      BalanceKind.settled => const Color(0xFFF0F3F1),
    };
    final balanceLabel = (switch (kind) {
      BalanceKind.receive => 'You will receive',
      BalanceKind.pay => 'You will pay',
      BalanceKind.settled => 'Settled',
    }).tr;
    final secondary = party.phone.trim().isNotEmpty
        ? formatPhoneForDisplay(party.phone)
        : party.shortName.trim();
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.35;
    final identity = _PartyIdentity(
      party: party,
      color: color,
      soft: soft,
      secondary: secondary,
      showTransactionCount: showTransactionCount,
    );
    final balance = _PartyBalance(
      party: party,
      kind: kind,
      color: color,
      label: balanceLabel,
    );
    final call = onCall == null
        ? null
        : IconButton(
            tooltip: '${'Call'.tr} ${party.name}',
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined),
            color: AppColors.greenDark,
          );

    final child = Padding(
      padding: contentPadding,
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    ?call,
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 59),
                  child: Row(
                    children: [
                      Expanded(child: balance),
                      if (onTap != null)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                        ),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                ?call,
                const SizedBox(width: 4),
                Flexible(child: balance),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: AppColors.muted,
                  ),
              ],
            ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: onCall != null,
      button: onTap != null,
      label:
          '${party.name}, $balanceLabel'
          '${kind == BalanceKind.settled ? '' : ', ${formatMoney(party.balancePaise, absolute: true)}'}',
      child: Opacity(
        opacity: party.isArchived ? 0.68 : 1,
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
}

class _PartyIdentity extends StatelessWidget {
  const _PartyIdentity({
    required this.party,
    required this.color,
    required this.soft,
    required this.secondary,
    required this.showTransactionCount,
  });

  final Party party;
  final Color color;
  final Color soft;
  final String secondary;
  final bool showTransactionCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: soft,
          child: Text(
            initials(party.name),
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    party.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (party.isArchived) const _ArchivedLabel(),
                ],
              ),
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
              if (showTransactionCount && party.transactionCount > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '${party.transactionCount} '
                  '${party.transactionCount == 1 ? 'entry' : 'entries'}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
    required this.party,
    required this.kind,
    required this.color,
    required this.label,
  });

  final Party party;
  final BalanceKind kind;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (kind != BalanceKind.settled)
          Text(
            formatMoney(party.balancePaise, absolute: true),
            maxLines: 2,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        Text(
          label,
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ArchivedLabel extends StatelessWidget {
  const _ArchivedLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Archived',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
