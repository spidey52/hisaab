import 'local_database.dart';

/// Privacy-safe, device-local operational diagnostics.
///
/// Callers may record categories, durations, result states, and aggregate
/// counts only. Business values, names, phone numbers, notes, URLs, tokens, and
/// request/response bodies must never be passed to this class.
class LocalDiagnostics {
  LocalDiagnostics(this._database);

  final AppDatabase _database;

  Future<void> record({
    String? accountId,
    String? companyId,
    required DiagnosticEvent event,
    required DiagnosticStatus status,
    Duration? duration,
    int? itemCount,
  }) {
    return _database.recordDiagnostic(
      accountId: accountId,
      companyId: companyId,
      event: event.name,
      status: status.name,
      durationMilliseconds: duration?.inMilliseconds,
      itemCount: itemCount,
    );
  }

  Future<List<LocalDiagnosticEntry>> recent({int limit = 100}) async {
    final rows = await _database.recentDiagnostics(limit: limit);
    return rows
        .map(
          (row) => LocalDiagnosticEntry(
            event: row.event,
            status: row.status,
            durationMilliseconds: row.durationMilliseconds,
            itemCount: row.itemCount,
            occurredAt: row.occurredAt,
          ),
        )
        .toList(growable: false);
  }
}

enum DiagnosticEvent {
  bootstrap,
  cacheRead,
  outboxEnqueue,
  syncRun,
  syncOperation,
  statementFetch,
  mutationFailure,
}

enum DiagnosticStatus {
  succeeded,
  cacheHit,
  cacheMiss,
  offline,
  retryScheduled,
  needsAttention,
  authenticationRequired,
  failed,
}

class LocalDiagnosticEntry {
  const LocalDiagnosticEntry({
    required this.event,
    required this.status,
    required this.durationMilliseconds,
    required this.itemCount,
    required this.occurredAt,
  });

  final String event;
  final String status;
  final int? durationMilliseconds;
  final int? itemCount;
  final DateTime occurredAt;
}
