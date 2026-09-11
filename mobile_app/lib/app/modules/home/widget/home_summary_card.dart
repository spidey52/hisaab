import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';

/// White summary card inset into the green Home header.
class HomeSummaryCard extends StatelessWidget {
  const HomeSummaryCard({
    super.key,
    required this.receivePaise,
    required this.payPaise,
    required this.receivePeople,
    required this.payPeople,
    this.onReceiveTap,
    this.onPayTap,
  });

  final int receivePaise;
  final int payPaise;
  final int receivePeople;
  final int payPeople;
  final VoidCallback? onReceiveTap;
  final VoidCallback? onPayTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryHalf(
              label: "You'll Receive",
              amountPaise: receivePaise,
              amountColor: colors.green,
              caption: receivePeople == 1
                  ? 'From 1 person'
                  : 'From $receivePeople people',
              onTap: onReceiveTap,
            ),
          ),
          Container(width: 1, height: 56, color: colors.line),
          Expanded(
            child: _SummaryHalf(
              label: "You'll Pay",
              amountPaise: payPaise,
              amountColor: colors.red,
              caption: payPeople == 1 ? 'To 1 person' : 'To $payPeople people',
              onTap: onPayTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryHalf extends StatelessWidget {
  const _SummaryHalf({
    required this.label,
    required this.amountPaise,
    required this.amountColor,
    required this.caption,
    this.onTap,
  });

  final String label;
  final int amountPaise;
  final Color amountColor;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amountPaise, absolute: true),
              style: displayStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: amountColor,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}
