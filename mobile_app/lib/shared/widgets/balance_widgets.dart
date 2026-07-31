import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.amountPaise,
    required this.kind,
    this.label,
    this.caption,
    this.onTap,
    this.compact = false,
  });

  final int amountPaise;
  final BalanceKind kind;
  final String? label;
  final String? caption;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _balanceColors(kind);
    final effectiveLabel = label ?? _balanceLabel(kind);
    final content = Padding(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            effectiveLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 5 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amountPaise, absolute: true),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '$effectiveLabel ${formatMoney(amountPaise, absolute: true)}',
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class BalanceSentence extends StatelessWidget {
  const BalanceSentence({
    super.key,
    required this.balancePaise,
    this.partyName,
    this.textAlign = TextAlign.start,
    this.showIcon = true,
  });

  final int balancePaise;
  final String? partyName;
  final TextAlign textAlign;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final kind = balancePaise > 0
        ? BalanceKind.receive
        : balancePaise < 0
        ? BalanceKind.pay
        : BalanceKind.settled;
    final colors = _balanceColors(kind);
    final sentence = _balanceSentence(balancePaise, partyName);

    return Semantics(
      label: sentence,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showIcon) ...[
              Icon(
                kind == BalanceKind.settled
                    ? Icons.check_circle_outline_rounded
                    : Icons.account_balance_wallet_outlined,
                size: 21,
                color: colors.foreground,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                sentence,
                textAlign: textAlign,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String balanceSentenceText(int balancePaise, {String? partyName}) =>
    _balanceSentence(balancePaise, partyName);

String _balanceSentence(int balancePaise, String? partyName) {
  final hasName = partyName != null && partyName.trim().isNotEmpty;
  if (balancePaise > 0) {
    return hasName
        ? 'You will receive ${formatMoney(balancePaise, absolute: true)} from $partyName.'
        : 'You will receive ${formatMoney(balancePaise, absolute: true)}.';
  }
  if (balancePaise < 0) {
    return hasName
        ? 'You will pay ${formatMoney(balancePaise, absolute: true)} to $partyName.'
        : 'You will pay ${formatMoney(balancePaise, absolute: true)}.';
  }
  return hasName
      ? 'Your balance with $partyName is settled.'
      : 'Your balance is settled.';
}

String _balanceLabel(BalanceKind kind) => switch (kind) {
  BalanceKind.receive => 'You will receive',
  BalanceKind.pay => 'You will pay',
  BalanceKind.settled => 'Settled',
};

({Color foreground, Color background, Color border}) _balanceColors(
  BalanceKind kind,
) => switch (kind) {
  BalanceKind.receive => (
    foreground: AppColors.greenDark,
    background: AppColors.greenSoft,
    border: const Color(0xFFB9DDC7),
  ),
  BalanceKind.pay => (
    foreground: AppColors.red,
    background: AppColors.redSoft,
    border: const Color(0xFFF0C6C2),
  ),
  BalanceKind.settled => (
    foreground: AppColors.muted,
    background: const Color(0xFFF2F4F2),
    border: AppColors.line,
  ),
};
