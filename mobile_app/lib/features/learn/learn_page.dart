import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  static const _lessons = [
    (
      icon: Icons.swap_vert_circle_outlined,
      title: 'You gave or You got?',
      summary: 'Choose the right button every time.',
      body:
          'Use “You gave” when money or goods went from you to the party. '
          'Use “You got” when money came back to you. Red minus means you gave; '
          'green plus means you got.',
    ),
    (
      icon: Icons.account_balance_wallet_outlined,
      title: 'Understand the balance',
      summary: 'Know who has to pay whom.',
      body:
          '“You will receive” means the party owes you. “You will pay” means '
          'you owe the party. A settled balance means neither side owes money.',
    ),
    (
      icon: Icons.person_add_alt_1_outlined,
      title: 'Add a party',
      summary: 'Save a customer or supplier.',
      body:
          'A party can be a customer, supplier, friend, or anyone you keep '
          'a Hisaab with. Only the name is required. You can choose one person '
          'from your contacts or enter the details manually.',
    ),
    (
      icon: Icons.post_add_outlined,
      title: 'Record an entry',
      summary: 'Save an amount in a few taps.',
      body:
          'Choose You gave or You got, select a party, enter the amount, and '
          'save. A note, date, cash/bank choice, and other details are optional.',
    ),
    (
      icon: Icons.receipt_long_outlined,
      title: 'Read a statement',
      summary: 'See the full history with one party.',
      body:
          'Each statement row shows the date, amount, and whether you gave or '
          'got money. Use the Filter button when you only need a recent period.',
    ),
    (
      icon: Icons.edit_note_outlined,
      title: 'Fix a mistake safely',
      summary: 'Keep a clear history.',
      body:
          'Cancel an incorrect entry and record the correct one. Cancelled '
          'entries stay in the audit history instead of silently disappearing.',
    ),
    (
      icon: Icons.cloud_off_outlined,
      title: 'When the server is offline',
      summary: 'Your last downloaded ledger stays visible.',
      body:
          'You can keep adding entries and parties while offline — they are '
          'saved on your phone and sync automatically when the connection '
          'returns. Editing, cancelling, and settings need a connection.',
    ),
  ];

  static int _readingMinutes(String body) {
    final words = body.trim().split(RegExp(r'\s+')).length;
    return (words / 160).ceil().clamp(1, 99);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.greenSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color.alphaBlend(
                  colors.greenDark.withValues(alpha: 0.16),
                  colors.greenSoft,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.school_rounded, color: colors.greenDark, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hisaab basics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Short lessons in simple language. Tap any topic.',
                        style: TextStyle(color: colors.greenDark, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final lesson in _lessons) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.greenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(lesson.icon, color: colors.greenDark, size: 22),
                ),
                title: Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${lesson.summary} · ${_readingMinutes(lesson.body)} min read',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.muted,
                      height: 1.35,
                    ),
                  ),
                ),
                iconColor: colors.muted,
                collapsedIconColor: colors.muted,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.body,
                    style: TextStyle(color: colors.muted, height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
