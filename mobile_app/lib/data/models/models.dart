enum EntryAction { gave, received, openingBalance }

enum EntryStatus { posted, cancelled }

enum BalanceKind { receive, pay, settled }

enum LocalSyncStatus { synced, pending, needsAttention }

class AppUser {
  const AppUser({
    required this.id,
    required this.phoneE164,
    required this.fullName,
    required this.language,
    required this.accessibilityMode,
    this.contactDiscoverable = false,
    this.version,
    this.updatedAt,
  });

  final String id;
  final String phoneE164;
  final String fullName;
  final String language;
  final bool accessibilityMode;
  final bool contactDiscoverable;
  final int? version;
  final DateTime? updatedAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id']?.toString() ?? '',
    phoneE164: json['phoneE164']?.toString() ?? '',
    fullName: json['fullName']?.toString() ?? '',
    language: json['language']?.toString() ?? 'en',
    accessibilityMode: json['accessibilityMode'] == true,
    contactDiscoverable: json['contactDiscoverable'] == true,
    version: _asNullableInt(json['version']),
    updatedAt: _asDate(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneE164': phoneE164,
    'fullName': fullName,
    'language': language,
    'accessibilityMode': accessibilityMode,
    'contactDiscoverable': contactDiscoverable,
    'version': ?version,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  AppUser copyWith({
    String? id,
    String? phoneE164,
    String? fullName,
    String? language,
    bool? accessibilityMode,
    bool? contactDiscoverable,
    int? version,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      phoneE164: phoneE164 ?? this.phoneE164,
      fullName: fullName ?? this.fullName,
      language: language ?? this.language,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      contactDiscoverable: contactDiscoverable ?? this.contactDiscoverable,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.currency,
    required this.timezone,
    this.version,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String currency;
  final String timezone;
  final int? version;
  final DateTime? updatedAt;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'My Hisaab',
    currency: json['currency']?.toString() ?? 'INR',
    timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    version: _asNullableInt(json['version']),
    updatedAt: _asDate(json['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currency': currency,
    'timezone': timezone,
    'version': ?version,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  Company copyWith({
    String? id,
    String? name,
    String? currency,
    String? timezone,
    int? version,
    DateTime? updatedAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PartyGroup {
  const PartyGroup({required this.id, required this.name, this.version});

  final String id;
  final String name;
  final int? version;

  factory PartyGroup.fromJson(Map<String, dynamic> json) => PartyGroup(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    version: _asNullableInt(json['version']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': ?version,
  };
}

class Party {
  const Party({
    required this.id,
    required this.reference,
    required this.name,
    required this.shortName,
    required this.phone,
    this.phoneE164,
    required this.notes,
    required this.groupId,
    required this.groupName,
    required this.balancePaise,
    required this.transactionCount,
    required this.archivedAt,
    required this.createdAt,
    this.version,
    this.updatedAt,
    this.localSyncStatus = LocalSyncStatus.synced,
    this.clientOperationId,
  });

  final String id;
  final String reference;
  final String name;
  final String shortName;
  final String phone;
  final String? phoneE164;
  final String notes;
  final String? groupId;
  final String? groupName;
  final int balancePaise;
  final int transactionCount;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final int? version;
  final DateTime? updatedAt;
  final LocalSyncStatus localSyncStatus;
  final String? clientOperationId;

  bool get isArchived => archivedAt != null;
  BalanceKind get balanceKind => balancePaise > 0
      ? BalanceKind.receive
      : balancePaise < 0
      ? BalanceKind.pay
      : BalanceKind.settled;

  factory Party.fromJson(Map<String, dynamic> json) => Party(
    id: json['id']?.toString() ?? '',
    reference: json['reference']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    shortName:
        _field(json, 'shortName', 'short_name')?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    phoneE164: _field(json, 'phoneE164', 'phone_e164')?.toString(),
    notes: json['notes']?.toString() ?? '',
    groupId: _field(json, 'groupId', 'group_id')?.toString(),
    groupName: _field(json, 'groupName', 'group_name')?.toString(),
    balancePaise: _asInt(_field(json, 'balancePaise', 'balance_paise')),
    transactionCount: _asInt(
      _field(json, 'transactionCount', 'transaction_count'),
    ),
    archivedAt: _asDate(_field(json, 'archivedAt', 'archived_at')),
    createdAt:
        _asDate(_field(json, 'createdAt', 'created_at')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    version: _asNullableInt(json['version']),
    updatedAt: _asDate(_field(json, 'updatedAt', 'updated_at')),
    localSyncStatus: _syncStatus(json['_localSyncStatus']),
    clientOperationId: json['_clientOperationId']?.toString(),
  );

  Party copyWith({
    String? id,
    String? reference,
    String? name,
    String? shortName,
    String? phone,
    String? phoneE164,
    String? notes,
    String? groupId,
    String? groupName,
    int? balancePaise,
    int? transactionCount,
    DateTime? archivedAt,
    DateTime? createdAt,
    int? version,
    DateTime? updatedAt,
    LocalSyncStatus? localSyncStatus,
    String? clientOperationId,
    bool clearClientOperationId = false,
    bool clearPhoneE164 = false,
    bool clearGroupId = false,
    bool clearArchivedAt = false,
  }) {
    return Party(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      phone: phone ?? this.phone,
      phoneE164: clearPhoneE164 ? null : phoneE164 ?? this.phoneE164,
      notes: notes ?? this.notes,
      groupId: clearGroupId ? null : groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      balancePaise: balancePaise ?? this.balancePaise,
      transactionCount: transactionCount ?? this.transactionCount,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      localSyncStatus: localSyncStatus ?? this.localSyncStatus,
      clientOperationId: clearClientOperationId
          ? null
          : clientOperationId ?? this.clientOperationId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'reference': reference,
    'name': name,
    'shortName': shortName,
    'phone': phone,
    'phoneE164': phoneE164,
    'notes': notes,
    'groupId': groupId,
    'groupName': groupName,
    'balancePaise': balancePaise,
    'transactionCount': transactionCount,
    'archivedAt': archivedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'version': ?version,
    'updatedAt': updatedAt?.toIso8601String(),
    if (localSyncStatus != LocalSyncStatus.synced)
      '_localSyncStatus': localSyncStatus.name,
    '_clientOperationId': ?clientOperationId,
  };
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.sequence,
    required this.action,
    required this.amountPaise,
    required this.balanceEffectPaise,
    required this.narration,
    required this.entryDate,
    required this.paymentAccount,
    required this.status,
    required this.createdByName,
    required this.createdAt,
    required this.editedAt,
    required this.cancelledAt,
    required this.revisionCount,
    this.version,
    this.updatedAt,
    this.localSyncStatus = LocalSyncStatus.synced,
    this.clientOperationId,
  });

  final String id;
  final String partyId;
  final String partyName;
  final int sequence;
  final EntryAction action;
  final int amountPaise;
  final int balanceEffectPaise;
  final String narration;
  final DateTime entryDate;
  final String? paymentAccount;
  final EntryStatus status;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? cancelledAt;
  final int revisionCount;
  final int? version;
  final DateTime? updatedAt;
  final LocalSyncStatus localSyncStatus;
  final String? clientOperationId;

  bool get isGave => action == EntryAction.gave;
  bool get isOpeningBalance => action == EntryAction.openingBalance;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: json['id']?.toString() ?? '',
    partyId: _field(json, 'partyId', 'party_id')?.toString() ?? '',
    partyName: _field(json, 'partyName', 'party_name')?.toString() ?? '',
    sequence: _asInt(json['sequence']),
    action: switch (json['action']) {
      'received' => EntryAction.received,
      'opening_balance' => EntryAction.openingBalance,
      _ => EntryAction.gave,
    },
    amountPaise: _asInt(_field(json, 'amountPaise', 'amount_paise')),
    balanceEffectPaise: _asInt(
      _field(json, 'balanceEffectPaise', 'balance_effect_paise'),
    ),
    narration: json['narration']?.toString() ?? '',
    entryDate:
        _asDate(_field(json, 'entryDate', 'entry_date')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    paymentAccount: _field(
      json,
      'paymentAccount',
      'payment_account',
    )?.toString(),
    status: json['status'] == 'cancelled'
        ? EntryStatus.cancelled
        : EntryStatus.posted,
    createdByName:
        _field(json, 'createdByName', 'created_by_name')?.toString() ?? '',
    createdAt:
        _asDate(_field(json, 'createdAt', 'created_at')) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    editedAt: _asDate(_field(json, 'editedAt', 'edited_at')),
    cancelledAt: _asDate(_field(json, 'cancelledAt', 'cancelled_at')),
    revisionCount: _asInt(_field(json, 'revisionCount', 'revision_count')),
    version: _asNullableInt(json['version']),
    updatedAt: _asDate(_field(json, 'updatedAt', 'updated_at')),
    localSyncStatus: _syncStatus(json['_localSyncStatus']),
    clientOperationId: json['_clientOperationId']?.toString(),
  );

  LedgerEntry copyWith({
    String? id,
    String? partyId,
    String? partyName,
    int? sequence,
    EntryAction? action,
    int? amountPaise,
    int? balanceEffectPaise,
    String? narration,
    DateTime? entryDate,
    String? paymentAccount,
    EntryStatus? status,
    String? createdByName,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? cancelledAt,
    int? revisionCount,
    int? version,
    DateTime? updatedAt,
    LocalSyncStatus? localSyncStatus,
    String? clientOperationId,
    bool clearClientOperationId = false,
    bool clearPaymentAccount = false,
    bool clearEditedAt = false,
    bool clearCancelledAt = false,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      sequence: sequence ?? this.sequence,
      action: action ?? this.action,
      amountPaise: amountPaise ?? this.amountPaise,
      balanceEffectPaise: balanceEffectPaise ?? this.balanceEffectPaise,
      narration: narration ?? this.narration,
      entryDate: entryDate ?? this.entryDate,
      paymentAccount: clearPaymentAccount
          ? null
          : paymentAccount ?? this.paymentAccount,
      status: status ?? this.status,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      editedAt: clearEditedAt ? null : editedAt ?? this.editedAt,
      cancelledAt: clearCancelledAt ? null : cancelledAt ?? this.cancelledAt,
      revisionCount: revisionCount ?? this.revisionCount,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      localSyncStatus: localSyncStatus ?? this.localSyncStatus,
      clientOperationId: clearClientOperationId
          ? null
          : clientOperationId ?? this.clientOperationId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'partyId': partyId,
    'partyName': partyName,
    'sequence': sequence,
    'action': switch (action) {
      EntryAction.gave => 'gave',
      EntryAction.received => 'received',
      EntryAction.openingBalance => 'opening_balance',
    },
    'amountPaise': amountPaise,
    'balanceEffectPaise': balanceEffectPaise,
    'narration': narration,
    'entryDate':
        '${entryDate.year.toString().padLeft(4, '0')}-'
        '${entryDate.month.toString().padLeft(2, '0')}-'
        '${entryDate.day.toString().padLeft(2, '0')}',
    'paymentAccount': paymentAccount,
    'status': status == EntryStatus.cancelled ? 'cancelled' : 'posted',
    'createdByName': createdByName,
    'createdAt': createdAt.toIso8601String(),
    'editedAt': editedAt?.toIso8601String(),
    'cancelledAt': cancelledAt?.toIso8601String(),
    'revisionCount': revisionCount,
    'version': ?version,
    'updatedAt': updatedAt?.toIso8601String(),
    if (localSyncStatus != LocalSyncStatus.synced)
      '_localSyncStatus': localSyncStatus.name,
    '_clientOperationId': ?clientOperationId,
  };
}

class BootstrapData {
  const BootstrapData({
    required this.user,
    required this.company,
    required this.companies,
    required this.groups,
    required this.parties,
    required this.entries,
    required this.serverTime,
    this.syncCursor,
  });

  final AppUser user;
  final Company company;
  final List<Company> companies;
  final List<PartyGroup> groups;
  final List<Party> parties;
  final List<LedgerEntry> entries;
  final DateTime serverTime;
  final String? syncCursor;

  factory BootstrapData.fromJson(Map<String, dynamic> json) => BootstrapData(
    user: AppUser.fromJson(_map(json['user'])),
    company: Company.fromJson(_map(json['company'])),
    companies: _list(
      json['companies'],
    ).map((item) => Company.fromJson(_map(item))).toList(),
    groups: _list(
      json['groups'],
    ).map((item) => PartyGroup.fromJson(_map(item))).toList(),
    parties: _list(
      json['parties'],
    ).map((item) => Party.fromJson(_map(item))).toList(),
    entries: _list(
      json['entries'],
    ).map((item) => LedgerEntry.fromJson(_map(item))).toList(),
    serverTime: _asDate(json['serverTime']) ?? DateTime.now(),
    syncCursor: json['syncCursor']?.toString(),
  );

  BootstrapData copyWith({
    AppUser? user,
    Company? company,
    List<Company>? companies,
    List<PartyGroup>? groups,
    List<Party>? parties,
    List<LedgerEntry>? entries,
    DateTime? serverTime,
    String? syncCursor,
  }) {
    return BootstrapData(
      user: user ?? this.user,
      company: company ?? this.company,
      companies: companies ?? this.companies,
      groups: groups ?? this.groups,
      parties: parties ?? this.parties,
      entries: entries ?? this.entries,
      serverTime: serverTime ?? this.serverTime,
      syncCursor: syncCursor ?? this.syncCursor,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'company': company.toJson(),
    'companies': companies.map((item) => item.toJson()).toList(),
    'groups': groups.map((item) => item.toJson()).toList(),
    'parties': parties.map((item) => item.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
    'serverTime': serverTime.toIso8601String(),
    'syncCursor': ?syncCursor,
  };
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _list(Object? value) =>
    value is List ? List<dynamic>.from(value) : <dynamic>[];

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asDate(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  final direct = DateTime.tryParse(raw);
  if (direct != null) return direct;

  final fromJs = _parseJsDateString(raw);
  if (fromJs != null) return fromJs;

  // Postgres / Node often send "yyyy-MM-dd HH:mm:ss.sss+00" (space, short offset).
  var normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  normalized = normalized.replaceFirstMapped(
    RegExp(r'(T\d{2}:\d{2}:\d{2}(?:\.\d+)?)([+-]\d{2})$'),
    (match) => '${match[1]}${match[2]}:00',
  );
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed;

  // Last resort: strip trailing short zone and treat as UTC.
  final withoutZone = RegExp(
    r'^(\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?)',
  ).firstMatch(raw);
  if (withoutZone != null) {
    final stamp = withoutZone[1]!.replaceFirst(' ', 'T');
    return DateTime.tryParse('${stamp}Z') ?? DateTime.tryParse(stamp);
  }
  return null;
}

/// Parses Node `Date.toString()` values such as:
/// `Thu Sep 10 2026 08:17:53 GMT+0000 (Coordinated Universal Time)`.
DateTime? _parseJsDateString(String raw) {
  final match = RegExp(
    r'^\w{3} (\w{3}) (\d{1,2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT([+-]\d{4})',
  ).firstMatch(raw);
  if (match == null) return null;

  const months = <String, int>{
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final month = months[match[1]];
  if (month == null) return null;

  final day = int.tryParse(match[2]!);
  final year = int.tryParse(match[3]!);
  final hour = int.tryParse(match[4]!);
  final minute = int.tryParse(match[5]!);
  final second = int.tryParse(match[6]!);
  if (day == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }

  final offset = match[7]!;
  final sign = offset.startsWith('-') ? -1 : 1;
  final offsetHours = int.tryParse(offset.substring(1, 3)) ?? 0;
  final offsetMinutes = int.tryParse(offset.substring(3, 5)) ?? 0;

  // Wall time is in the stated GMT offset; convert to UTC.
  return DateTime.utc(year, month, day, hour, minute, second).subtract(
    Duration(hours: sign * offsetHours, minutes: sign * offsetMinutes),
  );
}

Object? _field(Map<String, dynamic> json, String camel, [String? snake]) =>
    json[camel] ?? (snake == null ? null : json[snake]);

LocalSyncStatus _syncStatus(Object? value) => switch (value?.toString()) {
  'pending' => LocalSyncStatus.pending,
  'needsAttention' || 'needs_attention' => LocalSyncStatus.needsAttention,
  _ => LocalSyncStatus.synced,
};
