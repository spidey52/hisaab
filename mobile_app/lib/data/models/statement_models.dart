import 'models.dart';

class PartyStatementPage {
  const PartyStatementPage({
    required this.party,
    required this.period,
    required this.openingBalancePaise,
    required this.periodChangePaise,
    required this.closingBalancePaise,
    required this.postedCount,
    required this.cancelledCount,
    required this.totalCount,
    required this.order,
    required this.entries,
    required this.nextCursor,
    required this.hasMore,
    this.statementRevision,
  });

  factory PartyStatementPage.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return PartyStatementPage(
      party: Party.fromJson(_map(json['party'])),
      period: StatementPeriod.fromJson(_map(json['period'])),
      openingBalancePaise: _int(json['openingBalancePaise']),
      periodChangePaise: _int(json['periodChangePaise']),
      closingBalancePaise: _int(json['closingBalancePaise']),
      postedCount: _int(json['postedCount']),
      cancelledCount: _int(json['cancelledCount']),
      totalCount: _int(json['totalCount']),
      order: json['order']?.toString() ?? 'newest_first',
      entries: rawEntries is List
          ? rawEntries
                .whereType<Map>()
                .map(
                  (value) =>
                      StatementEntry.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList(growable: false)
          : const [],
      nextCursor: json['nextCursor']?.toString(),
      hasMore: json['hasMore'] == true,
      statementRevision: json['statementRevision']?.toString(),
    );
  }

  final Party party;
  final StatementPeriod period;
  final int openingBalancePaise;
  final int periodChangePaise;
  final int closingBalancePaise;
  final int postedCount;
  final int cancelledCount;
  final int totalCount;
  final String order;
  final List<StatementEntry> entries;
  final String? nextCursor;
  final bool hasMore;
  final String? statementRevision;
}

class StatementPeriod {
  const StatementPeriod({this.from, this.to});

  factory StatementPeriod.fromJson(Map<String, dynamic> json) =>
      StatementPeriod(from: _date(json['from']), to: _date(json['to']));

  final DateTime? from;
  final DateTime? to;
}

class StatementEntry {
  const StatementEntry({
    required this.entry,
    required this.runningBalancePaise,
  });

  factory StatementEntry.fromJson(Map<String, dynamic> json) => StatementEntry(
    entry: LedgerEntry.fromJson(json),
    runningBalancePaise: _int(json['runningBalancePaise']),
  );

  final LedgerEntry entry;
  final int runningBalancePaise;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(Object? value) {
  final raw = value?.toString();
  return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
}
