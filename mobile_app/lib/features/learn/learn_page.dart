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
          'Hisaab can show your most recently downloaded data while offline. '
          'Reconnect to Tailscale before adding or changing records.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Learn',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school_rounded,
                  color: AppColors.greenDark,
                  size: 30,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hisaab basics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Short lessons in simple language. Tap any topic.',
                        style: TextStyle(
                          color: AppColors.greenDark,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < _lessons.length; index++) ...[
                  ExpansionTile(
                    leading: Icon(_lessons[index].icon, color: AppColors.green),
                    title: Text(
                      _lessons[index].title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(_lessons[index].summary),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lessons[index].body,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                  if (index != _lessons.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
