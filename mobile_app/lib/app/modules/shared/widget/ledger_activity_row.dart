import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';

/// Shared list-row chrome for Home / Entries screenshots.
class LedgerActivityRow extends StatelessWidget {
  const LedgerActivityRow({
    super.key,
    required this.title,
    required this.badgeLabel,
    required this.badgeForeground,
    required this.badgeBackground,
    required this.timeLabel,
    required this.amountText,
    required this.amountColor,
    required this.avatarLetter,
    required this.avatarForeground,
    required this.avatarBackground,
    this.onTap,
    this.dimmed = false,
  });

  final String title;
  final String badgeLabel;
  final Color badgeForeground;
  final Color badgeBackground;
  final String? timeLabel;
  final String amountText;
  final Color amountColor;
  final String avatarLetter;
  final Color avatarForeground;
  final Color avatarBackground;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final child = ColoredBox(
      color: colors.surface,
      child: Opacity(
        opacity: dimmed ? 0.65 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarBackground,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  avatarLetter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: avatarForeground,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBackground,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            badgeLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: badgeForeground,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (timeLabel != null && timeLabel!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              timeLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colors.muted,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                  height: 1.15,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: colors.surface,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// Screenshot money style: `+ ₹5,000` / `- ₹12,400`.
String formatSignedScreenshotMoney(int paise, {required bool negative}) {
  return '${negative ? '-' : '+'} ${formatMoney(paise.abs(), absolute: true)}';
}

String avatarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}

/// Name-hashed pastel pair for Home party avatars (matches screenshot variety).
({Color background, Color foreground}) avatarColorsForName(
  String name,
  HisaabColors colors,
) {
  const palettes = <(int, int)>[
    (0xFFDCFCE7, 0xFF15803D), // mint
    (0xFFFEE2E2, 0xFFDC2626), // rose
    (0xFFCCFBF1, 0xFF0F766E), // teal
    (0xFFE0E7FF, 0xFF4338CA), // indigo
    (0xFFFCE7F3, 0xFFBE185D), // pink
    (0xFFFEF3C7, 0xFFB45309), // amber
  ];
  final hash = name.trim().toLowerCase().codeUnits.fold<int>(
    0,
    (value, unit) => value + unit,
  );
  final pair = palettes[hash % palettes.length];
  return (background: Color(pair.$1), foreground: Color(pair.$2));
}

String formatActivityTime(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);
  // entryDate is date-only (midnight). Never show "12:00 AM" for those.
  final isDateOnly =
      local.hour == 0 &&
      local.minute == 0 &&
      local.second == 0 &&
      local.millisecond == 0;

  if (isDateOnly) {
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy', Intl.getCurrentLocale()).format(local);
  }

  final elapsed = now.difference(local);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) {
    final mins = elapsed.inMinutes;
    return mins == 1 ? '1 min ago' : '$mins mins ago';
  }
  if (date == today) {
    if (elapsed.inHours < 12) {
      final hours = elapsed.inHours;
      return hours == 1 ? '1 hr ago' : '$hours hrs ago';
    }
    return DateFormat('h:mm a', Intl.getCurrentLocale()).format(local);
  }
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat(
    'd MMM yyyy, h:mm a',
    Intl.getCurrentLocale(),
  ).format(local);
}

/// Treats missing / epoch placeholders from model fallbacks as absent.
DateTime? usableDateTime(DateTime? value) {
  if (value == null) return null;
  if (value.millisecondsSinceEpoch <= 0 || value.year < 1971) return null;
  return value;
}

DateTime? activityTimeOfEntry(LedgerEntry entry) {
  final created = usableDateTime(entry.createdAt);
  if (created != null) return created;
  final updated = usableDateTime(entry.updatedAt);
  if (updated != null) return updated;
  final date = usableDateTime(entry.entryDate);
  if (date == null) return null;
  // entryDate is calendar-only; normalize so we never show "12:00 AM" / "5:30 AM".
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime? activityTimeOfParty({required Party party, LedgerEntry? lastEntry}) {
  if (lastEntry != null) {
    final fromEntry = activityTimeOfEntry(lastEntry);
    if (fromEntry != null) return fromEntry;
  }
  return usableDateTime(party.updatedAt) ?? usableDateTime(party.createdAt);
}

String? formatActivityTimeOrNull(DateTime? value) {
  final usable = usableDateTime(value);
  return usable == null ? null : formatActivityTime(usable);
}
