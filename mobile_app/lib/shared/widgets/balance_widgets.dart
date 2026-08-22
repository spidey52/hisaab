import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';

/// Passbook-style hero card for the Home tab: the whole khata at a glance.
class KhataHeroCard extends StatelessWidget {
  const KhataHeroCard({
    super.key,
    required this.receivePaise,
    required this.payPaise,
    this.onReceiveTap,
    this.onPayTap,
  });

  final int receivePaise;
  final int payPaise;
  final VoidCallback? onReceiveTap;
  final VoidCallback? onPayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final net = receivePaise - payPaise;
    final netLabel = net > 0
        ? 'Net, you will receive'
        : net < 0
        ? 'Net, you will pay'
        : 'All settled';

    return Semantics(
      container: true,
      label:
          '$netLabel ${formatMoney(net, absolute: true)}. '
          'You will receive ${formatMoney(receivePaise, absolute: true)}, '
          'you will pay ${formatMoney(payPaise, absolute: true)}.',
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.heroTop, colors.heroBottom],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Quiet oversized rupee glyph, like the embossing on a passbook.
            Positioned(
              right: -14,
              top: -26,
              child: ExcludeSemantics(
                child: Text(
                  '₹',
                  style: displayStyle(
                    fontSize: 130,
                    fontWeight: FontWeight.w700,
                    color: colors.onBrand.withValues(alpha: 0.06),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    netLabel.toUpperCase(),
                    style: TextStyle(
                      color: colors.onBrandFaint,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatMoney(net, absolute: true),
                      style: displayStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: colors.onBrand,
                        letterSpacing: -1.2,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroSplit(
                          label: 'To receive',
                          amountPaise: receivePaise,
                          dotColor: const Color(0xFF7FD6A6),
                          onTap: onReceiveTap,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: colors.onBrand.withValues(alpha: 0.14),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _HeroSplit(
                          label: 'To pay',
                          amountPaise: payPaise,
                          dotColor: const Color(0xFFF2A98E),
                          onTap: onPayTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSplit extends StatelessWidget {
  const _HeroSplit({
    required this.label,
    required this.amountPaise,
    required this.dotColor,
    this.onTap,
  });

  final String label;
  final int amountPaise;
  final Color dotColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.onBrandFaint,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(amountPaise, absolute: true),
            style: displayStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.onBrand,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }
}

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
    final tones = balanceTones(context, kind);
    final colors = context.colors;
    final effectiveLabel = label ?? balanceKindLabel(kind);
    final content = Padding(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            effectiveLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tones.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amountPaise, absolute: true),
              style: displayStyle(
                fontSize: compact ? 21 : 25,
                fontWeight: FontWeight.w700,
                color: tones.foreground,
                letterSpacing: -0.6,
              ),
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.muted),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '$effectiveLabel ${formatMoney(amountPaise, absolute: true)}',
      child: Material(
        color: tones.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tones.border),
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
    final tones = balanceTones(context, kind);
    final sentence = _balanceSentence(balancePaise, partyName);

    return Semantics(
      label: sentence,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tones.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tones.border),
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
                color: tones.foreground,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                sentence,
                textAlign: textAlign,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tones.foreground,
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

String balanceKindLabel(BalanceKind kind) => switch (kind) {
  BalanceKind.receive => 'You will receive',
  BalanceKind.pay => 'You will pay',
  BalanceKind.settled => 'Settled',
};

/// Foreground/background/border tones for a balance direction, resolved
/// against the active theme.
({Color foreground, Color background, Color border}) balanceTones(
  BuildContext context,
  BalanceKind kind,
) {
  final colors = context.colors;
  return switch (kind) {
    BalanceKind.receive => (
      foreground: colors.greenDark,
      background: colors.greenSoft,
      border: Color.alphaBlend(
        colors.greenDark.withValues(alpha: 0.16),
        colors.greenSoft,
      ),
    ),
    BalanceKind.pay => (
      foreground: colors.red,
      background: colors.redSoft,
      border: Color.alphaBlend(
        colors.red.withValues(alpha: 0.16),
        colors.redSoft,
      ),
    ),
    BalanceKind.settled => (
      foreground: colors.muted,
      background: colors.settledSoft,
      border: colors.line,
    ),
  };
}
