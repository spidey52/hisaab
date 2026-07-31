import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/formatters.dart';
import '../core/utils/phone_utils.dart';
import '../data/models/models.dart';
import '../shared/widgets/balance_widgets.dart';

class StatementShareEntry {
  const StatementShareEntry({
    required this.entry,
    this.runningBalancePaise,
    this.provisional = false,
  });

  final LedgerEntry entry;
  final int? runningBalancePaise;
  final bool provisional;
}

class StatementShareData {
  StatementShareData({
    required this.ledgerName,
    required this.partyName,
    required this.from,
    required this.to,
    required this.openingBalancePaise,
    required this.closingBalancePaise,
    required List<StatementShareEntry> entries,
    int? totalEntryCount,
    this.authoritative = true,
  }) : entries = List.unmodifiable(entries),
       totalEntryCount = totalEntryCount ?? entries.length;

  final String ledgerName;
  final String partyName;
  final DateTime from;
  final DateTime to;
  final int openingBalancePaise;
  final int closingBalancePaise;
  final List<StatementShareEntry> entries;
  final int totalEntryCount;
  final bool authoritative;
}

abstract class PartyCommunicationService {
  Future<void> openDialer(String phone);

  Future<void> openWhatsApp(String phone, String message);

  /// Returns a user-facing notice when a fallback was required.
  Future<String?> openSmsComposer(String phone, String message);

  Future<void> shareText(String text, {String? subject, Rect? shareOrigin});

  Future<void> shareStatementPdf(
    StatementShareData data, {
    bool includeNotes = false,
    Rect? shareOrigin,
  });

  Future<void> copyText(String text);
}

class DevicePartyCommunicationService implements PartyCommunicationService {
  const DevicePartyCommunicationService();

  @override
  Future<void> openDialer(String phone) async {
    final uri = buildDialerUri(phone);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const CommunicationException('No phone app is available.');
    }
  }

  @override
  Future<void> openWhatsApp(String phone, String message) async {
    final uri = buildWhatsAppUri(phone, message);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const CommunicationException(
        'WhatsApp is not available. Try SMS or Share.',
      );
    }
  }

  @override
  Future<String?> openSmsComposer(String phone, String message) async {
    final composer = buildSmsUri(phone, message);
    if (composer == null) {
      throw const CommunicationException('Add a valid mobile number first.');
    }
    if (await launchUrl(composer, mode: LaunchMode.externalApplication)) {
      return null;
    }
    await Clipboard.setData(ClipboardData(text: message));
    final fallback = buildSmsUri(phone);
    if (fallback == null ||
        !await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
      throw const CommunicationException('No SMS app is available.');
    }
    return 'The statement summary was copied. Paste it into the SMS composer.';
  }

  @override
  Future<void> shareText(
    String text, {
    String? subject,
    Rect? shareOrigin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  @override
  Future<void> shareStatementPdf(
    StatementShareData data, {
    bool includeNotes = false,
    Rect? shareOrigin,
  }) async {
    final bytes = await buildStatementPdf(data, includeNotes: includeNotes);
    final stamp = dateOnly(data.to);
    final safeParty = data.partyName
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '')
        .toLowerCase();
    final fileName =
        'hisaab-${safeParty.isEmpty ? 'statement' : safeParty}-$stamp.pdf';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
        ],
        fileNameOverrides: [fileName],
        text: buildStatementMessage(data, includeNotes: false, maxEntries: 0),
        subject: '${data.partyName} · Hisaab statement',
        sharePositionOrigin: shareOrigin,
      ),
    );
  }

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

class CommunicationException implements Exception {
  const CommunicationException(this.message);

  final String message;

  @override
  String toString() => message;
}

Uri? buildDialerUri(String phone) {
  final normalized = normalizePhoneE164(phone);
  return normalized.isEmpty ? null : Uri(scheme: 'tel', path: normalized);
}

Uri? buildWhatsAppUri(String phone, String message) {
  final digits = phoneDigitsForExternalApp(phone);
  if (digits.isEmpty) return null;
  return Uri.https('wa.me', '/$digits', {'text': message});
}

Uri? buildSmsUri(String phone, [String? message]) {
  final normalized = normalizePhoneE164(phone);
  if (normalized.isEmpty) return null;
  return Uri(
    scheme: 'sms',
    path: normalized,
    query: message == null || message.isEmpty
        ? null
        : _encodeQueryParameters({'body': message}),
  );
}

String _encodeQueryParameters(Map<String, String> parameters) => parameters
    .entries
    .map(
      (entry) =>
          '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
    )
    .join('&');

String buildStatementMessage(
  StatementShareData data, {
  bool includeNotes = false,
  int maxEntries = 6,
}) {
  final buffer = StringBuffer()
    ..writeln('${data.ledgerName} · Hisaab statement')
    ..writeln(data.partyName)
    ..writeln('${formatShortDate(data.from)} – ${formatShortDate(data.to)}')
    ..writeln('Opening: ${balanceSentenceText(data.openingBalancePaise)}');

  if (!data.authoritative) {
    buffer.writeln('Provisional copy — pending entries may still sync.');
  }
  final visible = maxEntries <= 0
      ? const <StatementShareEntry>[]
      : data.entries.take(maxEntries);
  for (final item in visible) {
    final entry = item.entry;
    final direction = entry.action == EntryAction.openingBalance
        ? 'Opening balance'
        : entry.action == EntryAction.gave
        ? 'You gave'
        : 'You got';
    buffer.write(
      '${formatShortDate(entry.entryDate)} · $direction '
      '${formatMoney(entry.amountPaise, absolute: true)}',
    );
    if (entry.status == EntryStatus.cancelled) buffer.write(' · Cancelled');
    if (item.provisional) buffer.write(' · Pending sync');
    if (includeNotes && entry.narration.trim().isNotEmpty) {
      buffer.write(' · ${entry.narration.trim()}');
    }
    buffer.writeln();
  }
  if (maxEntries > 0 && data.totalEntryCount > maxEntries) {
    buffer.writeln('+${data.totalEntryCount - maxEntries} more entries');
  }
  buffer
    ..writeln('Closing: ${balanceSentenceText(data.closingBalancePaise)}')
    ..write('Shared from Hisaab');
  return buffer.toString();
}

Future<Uint8List> buildStatementPdf(
  StatementShareData data, {
  bool includeNotes = false,
}) async {
  final fonts = await _loadStatementFonts();
  final document = pw.Document(
    title: '${data.partyName} Hisaab statement',
    author: data.ledgerName,
    theme: pw.ThemeData.withFont(
      base: fonts.$1,
      bold: fonts.$1,
      italic: fonts.$1,
      boldItalic: fonts.$1,
      fontFallback: [fonts.$2],
    ),
  );
  final green = PdfColor.fromHex('#08783E');
  final red = PdfColor.fromHex('#C83C35');
  final muted = PdfColor.fromHex('#68736D');
  final line = PdfColor.fromHex('#E1E7E3');
  final rows = data.entries.map((item) {
    final entry = item.entry;
    final gave = entry.action == EntryAction.gave;
    final opening = entry.action == EntryAction.openingBalance;
    final label = opening
        ? 'Opening balance'
        : gave
        ? 'You gave'
        : 'You got';
    final status = [
      if (entry.status == EntryStatus.cancelled) 'Cancelled',
      if (item.provisional) 'Pending sync',
    ].join(' · ');
    return <String>[
      formatShortDate(entry.entryDate),
      label,
      _pdfMoney(entry.amountPaise),
      item.runningBalancePaise == null
          ? ''
          : _pdfRunningBalance(item.runningBalancePaise!),
      status,
      if (includeNotes) entry.narration.trim(),
    ];
  }).toList();

  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(34),
      ),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: line)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'HISAAB',
              style: pw.TextStyle(
                color: green,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Statement',
              style: pw.TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(color: muted, fontSize: 8),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 14),
        pw.Text(
          data.ledgerName,
          style: pw.TextStyle(fontSize: 12, color: muted),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          data.partyName,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${formatShortDate(data.from)} - ${formatShortDate(data.to)}',
          style: pw.TextStyle(fontSize: 11, color: muted),
        ),
        if (!data.authoritative) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColor.fromHex('#FFF3E7'),
            child: pw.Text(
              'PROVISIONAL - pending entries may still sync.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('#9A4A00'),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Row(
          children: [
            _pdfBalanceCard('Opening balance', data.openingBalancePaise, green),
            pw.SizedBox(width: 12),
            _pdfBalanceCard(
              'Closing balance',
              data.closingBalancePaise,
              data.closingBalancePaise < 0 ? red : green,
            ),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Entries',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text(
            'No entries in this period.',
            style: pw.TextStyle(color: muted),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: [
              'Date',
              'Type',
              'Amount',
              'Balance',
              'Status',
              if (includeNotes) 'Note',
            ],
            data: rows,
            border: pw.TableBorder.all(color: line, width: 0.5),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EAF6EF'),
            ),
            headerStyle: pw.TextStyle(
              color: green,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
        pw.SizedBox(height: 18),
        pw.Text(
          _pdfBalanceMeaning(data.closingBalancePaise, data.partyName),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: data.closingBalancePaise < 0 ? red : green,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          includeNotes
              ? 'Notes were included at the sender’s request.'
              : 'Private notes are excluded from this statement.',
          style: pw.TextStyle(color: muted, fontSize: 8.5),
        ),
      ],
    ),
  );
  return document.save();
}

Future<(pw.Font, pw.Font)>? _statementFonts;

Future<(pw.Font, pw.Font)> _loadStatementFonts() =>
    _statementFonts ??= () async {
      final latin = await rootBundle.load('assets/fonts/NotoSans-Variable.ttf');
      final devanagari = await rootBundle.load(
        'assets/fonts/NotoSansDevanagari-Variable.ttf',
      );
      return (pw.Font.ttf(latin), pw.Font.ttf(devanagari));
    }();

pw.Widget _pdfBalanceCard(String label, int paise, PdfColor color) =>
    pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#E1E7E3')),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
            pw.SizedBox(height: 4),
            pw.Text(
              _pdfMoney(paise.abs()),
              style: pw.TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

String _pdfMoney(int paise) {
  final amount = formatMoney(paise, absolute: true).replaceFirst('₹', '');
  return 'INR $amount';
}

String _pdfRunningBalance(int paise) {
  if (paise > 0) return 'Receive ${_pdfMoney(paise)}';
  if (paise < 0) return 'Pay ${_pdfMoney(paise.abs())}';
  return 'Settled';
}

String _pdfBalanceMeaning(int paise, String partyName) {
  if (paise > 0) return '$partyName owes you ${_pdfMoney(paise)}';
  if (paise < 0) return 'You owe $partyName ${_pdfMoney(paise)}';
  return 'The account is settled';
}
