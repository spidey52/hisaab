class SyncPullPage {
  const SyncPullPage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  factory SyncPullPage.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    return SyncPullPage(
      changes: rawChanges is List
          ? rawChanges
                .whereType<Map>()
                .map(
                  (value) =>
                      SyncChange.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList(growable: false)
          : const [],
      nextCursor: json['nextCursor']?.toString(),
      hasMore: json['hasMore'] == true,
    );
  }

  final List<SyncChange> changes;
  final String? nextCursor;
  final bool hasMore;
}

class SyncChange {
  const SyncChange({
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.changeType,
    required this.version,
    required this.changedAt,
    required this.payload,
  });

  factory SyncChange.fromJson(Map<String, dynamic> json) => SyncChange(
    cursor: json['cursor']?.toString() ?? '',
    entityType: json['entityType']?.toString() ?? '',
    entityId: json['entityId']?.toString() ?? '',
    changeType: json['changeType'] == 'tombstone'
        ? SyncChangeType.tombstone
        : SyncChangeType.upsert,
    version: _int(json['version']),
    changedAt:
        DateTime.tryParse(json['changedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    payload: json['payload'] is Map
        ? Map<String, dynamic>.from(json['payload'] as Map)
        : const {},
  );

  final String cursor;
  final String entityType;
  final String entityId;
  final SyncChangeType changeType;
  final int version;
  final DateTime changedAt;
  final Map<String, dynamic> payload;
}

enum SyncChangeType { upsert, tombstone }

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
