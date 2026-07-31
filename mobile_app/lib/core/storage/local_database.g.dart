// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalScopesTable extends LocalScopes
    with TableInfo<$LocalScopesTable, LocalScope> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalScopesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncCursorMeta = const VerificationMeta(
    'syncCursor',
  );
  @override
  late final GeneratedColumn<String> syncCursor = GeneratedColumn<String>(
    'sync_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    companyId,
    isActive,
    createdAt,
    updatedAt,
    lastSyncedAt,
    syncCursor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_scopes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalScope> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_cursor')) {
      context.handle(
        _syncCursorMeta,
        syncCursor.isAcceptableOrUnknown(data['sync_cursor']!, _syncCursorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, companyId};
  @override
  LocalScope map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalScope(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      syncCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_cursor'],
      ),
    );
  }

  @override
  $LocalScopesTable createAlias(String alias) {
    return $LocalScopesTable(attachedDatabase, alias);
  }
}

class LocalScope extends DataClass implements Insertable<LocalScope> {
  final String accountId;
  final String companyId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final String? syncCursor;
  const LocalScope({
    required this.accountId,
    required this.companyId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.syncCursor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['company_id'] = Variable<String>(companyId);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    if (!nullToAbsent || syncCursor != null) {
      map['sync_cursor'] = Variable<String>(syncCursor);
    }
    return map;
  }

  LocalScopesCompanion toCompanion(bool nullToAbsent) {
    return LocalScopesCompanion(
      accountId: Value(accountId),
      companyId: Value(companyId),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      syncCursor: syncCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(syncCursor),
    );
  }

  factory LocalScope.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalScope(
      accountId: serializer.fromJson<String>(json['accountId']),
      companyId: serializer.fromJson<String>(json['companyId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      syncCursor: serializer.fromJson<String?>(json['syncCursor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'companyId': serializer.toJson<String>(companyId),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'syncCursor': serializer.toJson<String?>(syncCursor),
    };
  }

  LocalScope copyWith({
    String? accountId,
    String? companyId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    Value<String?> syncCursor = const Value.absent(),
  }) => LocalScope(
    accountId: accountId ?? this.accountId,
    companyId: companyId ?? this.companyId,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    syncCursor: syncCursor.present ? syncCursor.value : this.syncCursor,
  );
  LocalScope copyWithCompanion(LocalScopesCompanion data) {
    return LocalScope(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      syncCursor: data.syncCursor.present
          ? data.syncCursor.value
          : this.syncCursor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalScope(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncCursor: $syncCursor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    companyId,
    isActive,
    createdAt,
    updatedAt,
    lastSyncedAt,
    syncCursor,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalScope &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncCursor == this.syncCursor);
}

class LocalScopesCompanion extends UpdateCompanion<LocalScope> {
  final Value<String> accountId;
  final Value<String> companyId;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastSyncedAt;
  final Value<String?> syncCursor;
  final Value<int> rowid;
  const LocalScopesCompanion({
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalScopesCompanion.insert({
    required String accountId,
    required String companyId,
    this.isActive = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastSyncedAt = const Value.absent(),
    this.syncCursor = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       companyId = Value(companyId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalScope> custom({
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? syncCursor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncCursor != null) 'sync_cursor': syncCursor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalScopesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? companyId,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastSyncedAt,
    Value<String?>? syncCursor,
    Value<int>? rowid,
  }) {
    return LocalScopesCompanion(
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncCursor: syncCursor ?? this.syncCursor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (syncCursor.present) {
      map['sync_cursor'] = Variable<String>(syncCursor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalScopesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncCursor: $syncCursor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BootstrapSnapshotsTable extends BootstrapSnapshots
    with TableInfo<$BootstrapSnapshotsTable, BootstrapSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BootstrapSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    companyId,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bootstrap_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<BootstrapSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, companyId};
  @override
  BootstrapSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BootstrapSnapshot(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BootstrapSnapshotsTable createAlias(String alias) {
    return $BootstrapSnapshotsTable(attachedDatabase, alias);
  }
}

class BootstrapSnapshot extends DataClass
    implements Insertable<BootstrapSnapshot> {
  final String accountId;
  final String companyId;
  final String payloadJson;
  final DateTime updatedAt;
  const BootstrapSnapshot({
    required this.accountId,
    required this.companyId,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['company_id'] = Variable<String>(companyId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BootstrapSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return BootstrapSnapshotsCompanion(
      accountId: Value(accountId),
      companyId: Value(companyId),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory BootstrapSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BootstrapSnapshot(
      accountId: serializer.fromJson<String>(json['accountId']),
      companyId: serializer.fromJson<String>(json['companyId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'companyId': serializer.toJson<String>(companyId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BootstrapSnapshot copyWith({
    String? accountId,
    String? companyId,
    String? payloadJson,
    DateTime? updatedAt,
  }) => BootstrapSnapshot(
    accountId: accountId ?? this.accountId,
    companyId: companyId ?? this.companyId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BootstrapSnapshot copyWithCompanion(BootstrapSnapshotsCompanion data) {
    return BootstrapSnapshot(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapSnapshot(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, companyId, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BootstrapSnapshot &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class BootstrapSnapshotsCompanion extends UpdateCompanion<BootstrapSnapshot> {
  final Value<String> accountId;
  final Value<String> companyId;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BootstrapSnapshotsCompanion({
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BootstrapSnapshotsCompanion.insert({
    required String accountId,
    required String companyId,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       companyId = Value(companyId),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<BootstrapSnapshot> custom({
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BootstrapSnapshotsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? companyId,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BootstrapSnapshotsCompanion(
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapSnapshotsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedEntitiesTable extends CachedEntities
    with TableInfo<$CachedEntitiesTable, CachedEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isTombstoneMeta = const VerificationMeta(
    'isTombstone',
  );
  @override
  late final GeneratedColumn<bool> isTombstone = GeneratedColumn<bool>(
    'is_tombstone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_tombstone" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    companyId,
    entityType,
    entityId,
    version,
    serverUpdatedAt,
    isTombstone,
    payloadJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_tombstone')) {
      context.handle(
        _isTombstoneMeta,
        isTombstone.isAcceptableOrUnknown(
          data['is_tombstone']!,
          _isTombstoneMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    accountId,
    companyId,
    entityType,
    entityId,
  };
  @override
  CachedEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedEntity(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      isTombstone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_tombstone'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedEntitiesTable createAlias(String alias) {
    return $CachedEntitiesTable(attachedDatabase, alias);
  }
}

class CachedEntity extends DataClass implements Insertable<CachedEntity> {
  final String accountId;
  final String companyId;
  final String entityType;
  final String entityId;
  final int? version;
  final DateTime? serverUpdatedAt;
  final bool isTombstone;
  final String payloadJson;
  final DateTime cachedAt;
  const CachedEntity({
    required this.accountId,
    required this.companyId,
    required this.entityType,
    required this.entityId,
    this.version,
    this.serverUpdatedAt,
    required this.isTombstone,
    required this.payloadJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['company_id'] = Variable<String>(companyId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<int>(version);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['is_tombstone'] = Variable<bool>(isTombstone);
    map['payload_json'] = Variable<String>(payloadJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedEntitiesCompanion toCompanion(bool nullToAbsent) {
    return CachedEntitiesCompanion(
      accountId: Value(accountId),
      companyId: Value(companyId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      isTombstone: Value(isTombstone),
      payloadJson: Value(payloadJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedEntity(
      accountId: serializer.fromJson<String>(json['accountId']),
      companyId: serializer.fromJson<String>(json['companyId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      version: serializer.fromJson<int?>(json['version']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      isTombstone: serializer.fromJson<bool>(json['isTombstone']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'companyId': serializer.toJson<String>(companyId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'version': serializer.toJson<int?>(version),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'isTombstone': serializer.toJson<bool>(isTombstone),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedEntity copyWith({
    String? accountId,
    String? companyId,
    String? entityType,
    String? entityId,
    Value<int?> version = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    bool? isTombstone,
    String? payloadJson,
    DateTime? cachedAt,
  }) => CachedEntity(
    accountId: accountId ?? this.accountId,
    companyId: companyId ?? this.companyId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    version: version.present ? version.value : this.version,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    isTombstone: isTombstone ?? this.isTombstone,
    payloadJson: payloadJson ?? this.payloadJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedEntity copyWithCompanion(CachedEntitiesCompanion data) {
    return CachedEntity(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      version: data.version.present ? data.version.value : this.version,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      isTombstone: data.isTombstone.present
          ? data.isTombstone.value
          : this.isTombstone,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedEntity(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isTombstone: $isTombstone, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    companyId,
    entityType,
    entityId,
    version,
    serverUpdatedAt,
    isTombstone,
    payloadJson,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedEntity &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.version == this.version &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.isTombstone == this.isTombstone &&
          other.payloadJson == this.payloadJson &&
          other.cachedAt == this.cachedAt);
}

class CachedEntitiesCompanion extends UpdateCompanion<CachedEntity> {
  final Value<String> accountId;
  final Value<String> companyId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int?> version;
  final Value<DateTime?> serverUpdatedAt;
  final Value<bool> isTombstone;
  final Value<String> payloadJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedEntitiesCompanion({
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.version = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isTombstone = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedEntitiesCompanion.insert({
    required String accountId,
    required String companyId,
    required String entityType,
    required String entityId,
    this.version = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.isTombstone = const Value.absent(),
    required String payloadJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       companyId = Value(companyId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payloadJson = Value(payloadJson),
       cachedAt = Value(cachedAt);
  static Insertable<CachedEntity> custom({
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? version,
    Expression<DateTime>? serverUpdatedAt,
    Expression<bool>? isTombstone,
    Expression<String>? payloadJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (version != null) 'version': version,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (isTombstone != null) 'is_tombstone': isTombstone,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedEntitiesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? companyId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int?>? version,
    Value<DateTime?>? serverUpdatedAt,
    Value<bool>? isTombstone,
    Value<String>? payloadJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedEntitiesCompanion(
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      version: version ?? this.version,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      isTombstone: isTombstone ?? this.isTombstone,
      payloadJson: payloadJson ?? this.payloadJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (isTombstone.present) {
      map['is_tombstone'] = Variable<bool>(isTombstone.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedEntitiesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('version: $version, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('isTombstone: $isTombstone, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxRecordsTable extends OutboxRecords
    with TableInfo<$OutboxRecordsTable, OutboxRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnOperationIdMeta =
      const VerificationMeta('dependsOnOperationId');
  @override
  late final GeneratedColumn<String> dependsOnOperationId =
      GeneratedColumn<String>(
        'depends_on_operation_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastStatusCodeMeta = const VerificationMeta(
    'lastStatusCode',
  );
  @override
  late final GeneratedColumn<int> lastStatusCode = GeneratedColumn<int>(
    'last_status_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCategoryMeta = const VerificationMeta(
    'lastErrorCategory',
  );
  @override
  late final GeneratedColumn<String> lastErrorCategory =
      GeneratedColumn<String>(
        'last_error_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    companyId,
    kind,
    payloadJson,
    dependsOnOperationId,
    baseVersion,
    state,
    attempts,
    lastStatusCode,
    lastErrorCode,
    lastErrorCategory,
    nextAttemptAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('depends_on_operation_id')) {
      context.handle(
        _dependsOnOperationIdMeta,
        dependsOnOperationId.isAcceptableOrUnknown(
          data['depends_on_operation_id']!,
          _dependsOnOperationIdMeta,
        ),
      );
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_status_code')) {
      context.handle(
        _lastStatusCodeMeta,
        lastStatusCode.isAcceptableOrUnknown(
          data['last_status_code']!,
          _lastStatusCodeMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('last_error_category')) {
      context.handle(
        _lastErrorCategoryMeta,
        lastErrorCategory.isAcceptableOrUnknown(
          data['last_error_category']!,
          _lastErrorCategoryMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      dependsOnOperationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}depends_on_operation_id'],
      ),
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastStatusCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_status_code'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      lastErrorCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_category'],
      ),
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OutboxRecordsTable createAlias(String alias) {
    return $OutboxRecordsTable(attachedDatabase, alias);
  }
}

class OutboxRecord extends DataClass implements Insertable<OutboxRecord> {
  final String id;
  final String accountId;
  final String companyId;
  final String kind;
  final String payloadJson;
  final String? dependsOnOperationId;
  final int? baseVersion;
  final String state;
  final int attempts;
  final int? lastStatusCode;
  final String? lastErrorCode;
  final String? lastErrorCategory;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OutboxRecord({
    required this.id,
    required this.accountId,
    required this.companyId,
    required this.kind,
    required this.payloadJson,
    this.dependsOnOperationId,
    this.baseVersion,
    required this.state,
    required this.attempts,
    this.lastStatusCode,
    this.lastErrorCode,
    this.lastErrorCategory,
    this.nextAttemptAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['company_id'] = Variable<String>(companyId);
    map['kind'] = Variable<String>(kind);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || dependsOnOperationId != null) {
      map['depends_on_operation_id'] = Variable<String>(dependsOnOperationId);
    }
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastStatusCode != null) {
      map['last_status_code'] = Variable<int>(lastStatusCode);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    if (!nullToAbsent || lastErrorCategory != null) {
      map['last_error_category'] = Variable<String>(lastErrorCategory);
    }
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OutboxRecordsCompanion toCompanion(bool nullToAbsent) {
    return OutboxRecordsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      companyId: Value(companyId),
      kind: Value(kind),
      payloadJson: Value(payloadJson),
      dependsOnOperationId: dependsOnOperationId == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOnOperationId),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      state: Value(state),
      attempts: Value(attempts),
      lastStatusCode: lastStatusCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStatusCode),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      lastErrorCategory: lastErrorCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCategory),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRecord(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      companyId: serializer.fromJson<String>(json['companyId']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      dependsOnOperationId: serializer.fromJson<String?>(
        json['dependsOnOperationId'],
      ),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastStatusCode: serializer.fromJson<int?>(json['lastStatusCode']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      lastErrorCategory: serializer.fromJson<String?>(
        json['lastErrorCategory'],
      ),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'companyId': serializer.toJson<String>(companyId),
      'kind': serializer.toJson<String>(kind),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'dependsOnOperationId': serializer.toJson<String?>(dependsOnOperationId),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'lastStatusCode': serializer.toJson<int?>(lastStatusCode),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'lastErrorCategory': serializer.toJson<String?>(lastErrorCategory),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxRecord copyWith({
    String? id,
    String? accountId,
    String? companyId,
    String? kind,
    String? payloadJson,
    Value<String?> dependsOnOperationId = const Value.absent(),
    Value<int?> baseVersion = const Value.absent(),
    String? state,
    int? attempts,
    Value<int?> lastStatusCode = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    Value<String?> lastErrorCategory = const Value.absent(),
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutboxRecord(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    companyId: companyId ?? this.companyId,
    kind: kind ?? this.kind,
    payloadJson: payloadJson ?? this.payloadJson,
    dependsOnOperationId: dependsOnOperationId.present
        ? dependsOnOperationId.value
        : this.dependsOnOperationId,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastStatusCode: lastStatusCode.present
        ? lastStatusCode.value
        : this.lastStatusCode,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    lastErrorCategory: lastErrorCategory.present
        ? lastErrorCategory.value
        : this.lastErrorCategory,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxRecord copyWithCompanion(OutboxRecordsCompanion data) {
    return OutboxRecord(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      dependsOnOperationId: data.dependsOnOperationId.present
          ? data.dependsOnOperationId.value
          : this.dependsOnOperationId,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastStatusCode: data.lastStatusCode.present
          ? data.lastStatusCode.value
          : this.lastStatusCode,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      lastErrorCategory: data.lastErrorCategory.present
          ? data.lastErrorCategory.value
          : this.lastErrorCategory,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRecord(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('dependsOnOperationId: $dependsOnOperationId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastStatusCode: $lastStatusCode, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorCategory: $lastErrorCategory, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    companyId,
    kind,
    payloadJson,
    dependsOnOperationId,
    baseVersion,
    state,
    attempts,
    lastStatusCode,
    lastErrorCode,
    lastErrorCategory,
    nextAttemptAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRecord &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.kind == this.kind &&
          other.payloadJson == this.payloadJson &&
          other.dependsOnOperationId == this.dependsOnOperationId &&
          other.baseVersion == this.baseVersion &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastStatusCode == this.lastStatusCode &&
          other.lastErrorCode == this.lastErrorCode &&
          other.lastErrorCategory == this.lastErrorCategory &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OutboxRecordsCompanion extends UpdateCompanion<OutboxRecord> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> companyId;
  final Value<String> kind;
  final Value<String> payloadJson;
  final Value<String?> dependsOnOperationId;
  final Value<int?> baseVersion;
  final Value<String> state;
  final Value<int> attempts;
  final Value<int?> lastStatusCode;
  final Value<String?> lastErrorCode;
  final Value<String?> lastErrorCategory;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OutboxRecordsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.dependsOnOperationId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastStatusCode = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorCategory = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxRecordsCompanion.insert({
    required String id,
    required String accountId,
    required String companyId,
    required String kind,
    required String payloadJson,
    this.dependsOnOperationId = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastStatusCode = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.lastErrorCategory = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       companyId = Value(companyId),
       kind = Value(kind),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxRecord> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<String>? kind,
    Expression<String>? payloadJson,
    Expression<String>? dependsOnOperationId,
    Expression<int>? baseVersion,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<int>? lastStatusCode,
    Expression<String>? lastErrorCode,
    Expression<String>? lastErrorCategory,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (kind != null) 'kind': kind,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (dependsOnOperationId != null)
        'depends_on_operation_id': dependsOnOperationId,
      if (baseVersion != null) 'base_version': baseVersion,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastStatusCode != null) 'last_status_code': lastStatusCode,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (lastErrorCategory != null) 'last_error_category': lastErrorCategory,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? companyId,
    Value<String>? kind,
    Value<String>? payloadJson,
    Value<String?>? dependsOnOperationId,
    Value<int?>? baseVersion,
    Value<String>? state,
    Value<int>? attempts,
    Value<int?>? lastStatusCode,
    Value<String?>? lastErrorCode,
    Value<String?>? lastErrorCategory,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OutboxRecordsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      kind: kind ?? this.kind,
      payloadJson: payloadJson ?? this.payloadJson,
      dependsOnOperationId: dependsOnOperationId ?? this.dependsOnOperationId,
      baseVersion: baseVersion ?? this.baseVersion,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastStatusCode: lastStatusCode ?? this.lastStatusCode,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      lastErrorCategory: lastErrorCategory ?? this.lastErrorCategory,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (dependsOnOperationId.present) {
      map['depends_on_operation_id'] = Variable<String>(
        dependsOnOperationId.value,
      );
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastStatusCode.present) {
      map['last_status_code'] = Variable<int>(lastStatusCode.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (lastErrorCategory.present) {
      map['last_error_category'] = Variable<String>(lastErrorCategory.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRecordsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('kind: $kind, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('dependsOnOperationId: $dependsOnOperationId, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastStatusCode: $lastStatusCode, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('lastErrorCategory: $lastErrorCategory, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiagnosticRecordsTable extends DiagnosticRecords
    with TableInfo<$DiagnosticRecordsTable, DiagnosticRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiagnosticRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
    'event',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMillisecondsMeta =
      const VerificationMeta('durationMilliseconds');
  @override
  late final GeneratedColumn<int> durationMilliseconds = GeneratedColumn<int>(
    'duration_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    companyId,
    event,
    status,
    durationMilliseconds,
    itemCount,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diagnostic_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiagnosticRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    }
    if (data.containsKey('event')) {
      context.handle(
        _eventMeta,
        event.isAcceptableOrUnknown(data['event']!, _eventMeta),
      );
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('duration_milliseconds')) {
      context.handle(
        _durationMillisecondsMeta,
        durationMilliseconds.isAcceptableOrUnknown(
          data['duration_milliseconds']!,
          _durationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiagnosticRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiagnosticRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      ),
      event: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      durationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_milliseconds'],
      ),
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $DiagnosticRecordsTable createAlias(String alias) {
    return $DiagnosticRecordsTable(attachedDatabase, alias);
  }
}

class DiagnosticRecord extends DataClass
    implements Insertable<DiagnosticRecord> {
  final int id;
  final String? accountId;
  final String? companyId;
  final String event;
  final String status;
  final int? durationMilliseconds;
  final int? itemCount;
  final DateTime occurredAt;
  const DiagnosticRecord({
    required this.id,
    this.accountId,
    this.companyId,
    required this.event,
    required this.status,
    this.durationMilliseconds,
    this.itemCount,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || companyId != null) {
      map['company_id'] = Variable<String>(companyId);
    }
    map['event'] = Variable<String>(event);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || durationMilliseconds != null) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds);
    }
    if (!nullToAbsent || itemCount != null) {
      map['item_count'] = Variable<int>(itemCount);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  DiagnosticRecordsCompanion toCompanion(bool nullToAbsent) {
    return DiagnosticRecordsCompanion(
      id: Value(id),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      companyId: companyId == null && nullToAbsent
          ? const Value.absent()
          : Value(companyId),
      event: Value(event),
      status: Value(status),
      durationMilliseconds: durationMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMilliseconds),
      itemCount: itemCount == null && nullToAbsent
          ? const Value.absent()
          : Value(itemCount),
      occurredAt: Value(occurredAt),
    );
  }

  factory DiagnosticRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiagnosticRecord(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      companyId: serializer.fromJson<String?>(json['companyId']),
      event: serializer.fromJson<String>(json['event']),
      status: serializer.fromJson<String>(json['status']),
      durationMilliseconds: serializer.fromJson<int?>(
        json['durationMilliseconds'],
      ),
      itemCount: serializer.fromJson<int?>(json['itemCount']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<String?>(accountId),
      'companyId': serializer.toJson<String?>(companyId),
      'event': serializer.toJson<String>(event),
      'status': serializer.toJson<String>(status),
      'durationMilliseconds': serializer.toJson<int?>(durationMilliseconds),
      'itemCount': serializer.toJson<int?>(itemCount),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  DiagnosticRecord copyWith({
    int? id,
    Value<String?> accountId = const Value.absent(),
    Value<String?> companyId = const Value.absent(),
    String? event,
    String? status,
    Value<int?> durationMilliseconds = const Value.absent(),
    Value<int?> itemCount = const Value.absent(),
    DateTime? occurredAt,
  }) => DiagnosticRecord(
    id: id ?? this.id,
    accountId: accountId.present ? accountId.value : this.accountId,
    companyId: companyId.present ? companyId.value : this.companyId,
    event: event ?? this.event,
    status: status ?? this.status,
    durationMilliseconds: durationMilliseconds.present
        ? durationMilliseconds.value
        : this.durationMilliseconds,
    itemCount: itemCount.present ? itemCount.value : this.itemCount,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  DiagnosticRecord copyWithCompanion(DiagnosticRecordsCompanion data) {
    return DiagnosticRecord(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      event: data.event.present ? data.event.value : this.event,
      status: data.status.present ? data.status.value : this.status,
      durationMilliseconds: data.durationMilliseconds.present
          ? data.durationMilliseconds.value
          : this.durationMilliseconds,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosticRecord(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('event: $event, ')
          ..write('status: $status, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('itemCount: $itemCount, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    companyId,
    event,
    status,
    durationMilliseconds,
    itemCount,
    occurredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiagnosticRecord &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.event == this.event &&
          other.status == this.status &&
          other.durationMilliseconds == this.durationMilliseconds &&
          other.itemCount == this.itemCount &&
          other.occurredAt == this.occurredAt);
}

class DiagnosticRecordsCompanion extends UpdateCompanion<DiagnosticRecord> {
  final Value<int> id;
  final Value<String?> accountId;
  final Value<String?> companyId;
  final Value<String> event;
  final Value<String> status;
  final Value<int?> durationMilliseconds;
  final Value<int?> itemCount;
  final Value<DateTime> occurredAt;
  const DiagnosticRecordsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.event = const Value.absent(),
    this.status = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  DiagnosticRecordsCompanion.insert({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    required String event,
    required String status,
    this.durationMilliseconds = const Value.absent(),
    this.itemCount = const Value.absent(),
    required DateTime occurredAt,
  }) : event = Value(event),
       status = Value(status),
       occurredAt = Value(occurredAt);
  static Insertable<DiagnosticRecord> custom({
    Expression<int>? id,
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<String>? event,
    Expression<String>? status,
    Expression<int>? durationMilliseconds,
    Expression<int>? itemCount,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (event != null) 'event': event,
      if (status != null) 'status': status,
      if (durationMilliseconds != null)
        'duration_milliseconds': durationMilliseconds,
      if (itemCount != null) 'item_count': itemCount,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  DiagnosticRecordsCompanion copyWith({
    Value<int>? id,
    Value<String?>? accountId,
    Value<String?>? companyId,
    Value<String>? event,
    Value<String>? status,
    Value<int?>? durationMilliseconds,
    Value<int?>? itemCount,
    Value<DateTime>? occurredAt,
  }) {
    return DiagnosticRecordsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      event: event ?? this.event,
      status: status ?? this.status,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      itemCount: itemCount ?? this.itemCount,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (durationMilliseconds.present) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosticRecordsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('event: $event, ')
          ..write('status: $status, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('itemCount: $itemCount, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $DraftRecordsTable extends DraftRecords
    with TableInfo<$DraftRecordsTable, DraftRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftIdMeta = const VerificationMeta(
    'draftId',
  );
  @override
  late final GeneratedColumn<String> draftId = GeneratedColumn<String>(
    'draft_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    companyId,
    kind,
    draftId,
    payloadJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('draft_id')) {
      context.handle(
        _draftIdMeta,
        draftId.isAcceptableOrUnknown(data['draft_id']!, _draftIdMeta),
      );
    } else if (isInserting) {
      context.missing(_draftIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, companyId, kind, draftId};
  @override
  DraftRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRecord(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      draftId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DraftRecordsTable createAlias(String alias) {
    return $DraftRecordsTable(attachedDatabase, alias);
  }
}

class DraftRecord extends DataClass implements Insertable<DraftRecord> {
  final String accountId;
  final String companyId;
  final String kind;
  final String draftId;
  final String payloadJson;
  final DateTime updatedAt;
  const DraftRecord({
    required this.accountId,
    required this.companyId,
    required this.kind,
    required this.draftId,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['company_id'] = Variable<String>(companyId);
    map['kind'] = Variable<String>(kind);
    map['draft_id'] = Variable<String>(draftId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DraftRecordsCompanion toCompanion(bool nullToAbsent) {
    return DraftRecordsCompanion(
      accountId: Value(accountId),
      companyId: Value(companyId),
      kind: Value(kind),
      draftId: Value(draftId),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory DraftRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRecord(
      accountId: serializer.fromJson<String>(json['accountId']),
      companyId: serializer.fromJson<String>(json['companyId']),
      kind: serializer.fromJson<String>(json['kind']),
      draftId: serializer.fromJson<String>(json['draftId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'companyId': serializer.toJson<String>(companyId),
      'kind': serializer.toJson<String>(kind),
      'draftId': serializer.toJson<String>(draftId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DraftRecord copyWith({
    String? accountId,
    String? companyId,
    String? kind,
    String? draftId,
    String? payloadJson,
    DateTime? updatedAt,
  }) => DraftRecord(
    accountId: accountId ?? this.accountId,
    companyId: companyId ?? this.companyId,
    kind: kind ?? this.kind,
    draftId: draftId ?? this.draftId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DraftRecord copyWithCompanion(DraftRecordsCompanion data) {
    return DraftRecord(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      kind: data.kind.present ? data.kind.value : this.kind,
      draftId: data.draftId.present ? data.draftId.value : this.draftId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRecord(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('kind: $kind, ')
          ..write('draftId: $draftId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(accountId, companyId, kind, draftId, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRecord &&
          other.accountId == this.accountId &&
          other.companyId == this.companyId &&
          other.kind == this.kind &&
          other.draftId == this.draftId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class DraftRecordsCompanion extends UpdateCompanion<DraftRecord> {
  final Value<String> accountId;
  final Value<String> companyId;
  final Value<String> kind;
  final Value<String> draftId;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DraftRecordsCompanion({
    this.accountId = const Value.absent(),
    this.companyId = const Value.absent(),
    this.kind = const Value.absent(),
    this.draftId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftRecordsCompanion.insert({
    required String accountId,
    required String companyId,
    required String kind,
    required String draftId,
    required String payloadJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       companyId = Value(companyId),
       kind = Value(kind),
       draftId = Value(draftId),
       payloadJson = Value(payloadJson),
       updatedAt = Value(updatedAt);
  static Insertable<DraftRecord> custom({
    Expression<String>? accountId,
    Expression<String>? companyId,
    Expression<String>? kind,
    Expression<String>? draftId,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (companyId != null) 'company_id': companyId,
      if (kind != null) 'kind': kind,
      if (draftId != null) 'draft_id': draftId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftRecordsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? companyId,
    Value<String>? kind,
    Value<String>? draftId,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DraftRecordsCompanion(
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      kind: kind ?? this.kind,
      draftId: draftId ?? this.draftId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (draftId.present) {
      map['draft_id'] = Variable<String>(draftId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftRecordsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('companyId: $companyId, ')
          ..write('kind: $kind, ')
          ..write('draftId: $draftId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalScopesTable localScopes = $LocalScopesTable(this);
  late final $BootstrapSnapshotsTable bootstrapSnapshots =
      $BootstrapSnapshotsTable(this);
  late final $CachedEntitiesTable cachedEntities = $CachedEntitiesTable(this);
  late final $OutboxRecordsTable outboxRecords = $OutboxRecordsTable(this);
  late final $DiagnosticRecordsTable diagnosticRecords =
      $DiagnosticRecordsTable(this);
  late final $DraftRecordsTable draftRecords = $DraftRecordsTable(this);
  late final Index outboxScopeStateCreated = Index(
    'outbox_scope_state_created',
    'CREATE INDEX outbox_scope_state_created ON outbox_records (account_id, company_id, state, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localScopes,
    bootstrapSnapshots,
    cachedEntities,
    outboxRecords,
    diagnosticRecords,
    draftRecords,
    outboxScopeStateCreated,
  ];
}

typedef $$LocalScopesTableCreateCompanionBuilder =
    LocalScopesCompanion Function({
      required String accountId,
      required String companyId,
      Value<bool> isActive,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<String?> syncCursor,
      Value<int> rowid,
    });
typedef $$LocalScopesTableUpdateCompanionBuilder =
    LocalScopesCompanion Function({
      Value<String> accountId,
      Value<String> companyId,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastSyncedAt,
      Value<String?> syncCursor,
      Value<int> rowid,
    });

class $$LocalScopesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalScopesTable> {
  $$LocalScopesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncCursor => $composableBuilder(
    column: $table.syncCursor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalScopesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalScopesTable> {
  $$LocalScopesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncCursor => $composableBuilder(
    column: $table.syncCursor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalScopesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalScopesTable> {
  $$LocalScopesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncCursor => $composableBuilder(
    column: $table.syncCursor,
    builder: (column) => column,
  );
}

class $$LocalScopesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalScopesTable,
          LocalScope,
          $$LocalScopesTableFilterComposer,
          $$LocalScopesTableOrderingComposer,
          $$LocalScopesTableAnnotationComposer,
          $$LocalScopesTableCreateCompanionBuilder,
          $$LocalScopesTableUpdateCompanionBuilder,
          (
            LocalScope,
            BaseReferences<_$AppDatabase, $LocalScopesTable, LocalScope>,
          ),
          LocalScope,
          PrefetchHooks Function()
        > {
  $$LocalScopesTableTableManager(_$AppDatabase db, $LocalScopesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalScopesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalScopesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalScopesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> syncCursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalScopesCompanion(
                accountId: accountId,
                companyId: companyId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastSyncedAt: lastSyncedAt,
                syncCursor: syncCursor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String companyId,
                Value<bool> isActive = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<String?> syncCursor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalScopesCompanion.insert(
                accountId: accountId,
                companyId: companyId,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastSyncedAt: lastSyncedAt,
                syncCursor: syncCursor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalScopesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalScopesTable,
      LocalScope,
      $$LocalScopesTableFilterComposer,
      $$LocalScopesTableOrderingComposer,
      $$LocalScopesTableAnnotationComposer,
      $$LocalScopesTableCreateCompanionBuilder,
      $$LocalScopesTableUpdateCompanionBuilder,
      (
        LocalScope,
        BaseReferences<_$AppDatabase, $LocalScopesTable, LocalScope>,
      ),
      LocalScope,
      PrefetchHooks Function()
    >;
typedef $$BootstrapSnapshotsTableCreateCompanionBuilder =
    BootstrapSnapshotsCompanion Function({
      required String accountId,
      required String companyId,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BootstrapSnapshotsTableUpdateCompanionBuilder =
    BootstrapSnapshotsCompanion Function({
      Value<String> accountId,
      Value<String> companyId,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$BootstrapSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $BootstrapSnapshotsTable> {
  $$BootstrapSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BootstrapSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $BootstrapSnapshotsTable> {
  $$BootstrapSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BootstrapSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BootstrapSnapshotsTable> {
  $$BootstrapSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BootstrapSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BootstrapSnapshotsTable,
          BootstrapSnapshot,
          $$BootstrapSnapshotsTableFilterComposer,
          $$BootstrapSnapshotsTableOrderingComposer,
          $$BootstrapSnapshotsTableAnnotationComposer,
          $$BootstrapSnapshotsTableCreateCompanionBuilder,
          $$BootstrapSnapshotsTableUpdateCompanionBuilder,
          (
            BootstrapSnapshot,
            BaseReferences<
              _$AppDatabase,
              $BootstrapSnapshotsTable,
              BootstrapSnapshot
            >,
          ),
          BootstrapSnapshot,
          PrefetchHooks Function()
        > {
  $$BootstrapSnapshotsTableTableManager(
    _$AppDatabase db,
    $BootstrapSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BootstrapSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BootstrapSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BootstrapSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BootstrapSnapshotsCompanion(
                accountId: accountId,
                companyId: companyId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String companyId,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BootstrapSnapshotsCompanion.insert(
                accountId: accountId,
                companyId: companyId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BootstrapSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BootstrapSnapshotsTable,
      BootstrapSnapshot,
      $$BootstrapSnapshotsTableFilterComposer,
      $$BootstrapSnapshotsTableOrderingComposer,
      $$BootstrapSnapshotsTableAnnotationComposer,
      $$BootstrapSnapshotsTableCreateCompanionBuilder,
      $$BootstrapSnapshotsTableUpdateCompanionBuilder,
      (
        BootstrapSnapshot,
        BaseReferences<
          _$AppDatabase,
          $BootstrapSnapshotsTable,
          BootstrapSnapshot
        >,
      ),
      BootstrapSnapshot,
      PrefetchHooks Function()
    >;
typedef $$CachedEntitiesTableCreateCompanionBuilder =
    CachedEntitiesCompanion Function({
      required String accountId,
      required String companyId,
      required String entityType,
      required String entityId,
      Value<int?> version,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> isTombstone,
      required String payloadJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedEntitiesTableUpdateCompanionBuilder =
    CachedEntitiesCompanion Function({
      Value<String> accountId,
      Value<String> companyId,
      Value<String> entityType,
      Value<String> entityId,
      Value<int?> version,
      Value<DateTime?> serverUpdatedAt,
      Value<bool> isTombstone,
      Value<String> payloadJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedEntitiesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedEntitiesTable> {
  $$CachedEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTombstone => $composableBuilder(
    column: $table.isTombstone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedEntitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedEntitiesTable> {
  $$CachedEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTombstone => $composableBuilder(
    column: $table.isTombstone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedEntitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedEntitiesTable> {
  $$CachedEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isTombstone => $composableBuilder(
    column: $table.isTombstone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedEntitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedEntitiesTable,
          CachedEntity,
          $$CachedEntitiesTableFilterComposer,
          $$CachedEntitiesTableOrderingComposer,
          $$CachedEntitiesTableAnnotationComposer,
          $$CachedEntitiesTableCreateCompanionBuilder,
          $$CachedEntitiesTableUpdateCompanionBuilder,
          (
            CachedEntity,
            BaseReferences<_$AppDatabase, $CachedEntitiesTable, CachedEntity>,
          ),
          CachedEntity,
          PrefetchHooks Function()
        > {
  $$CachedEntitiesTableTableManager(
    _$AppDatabase db,
    $CachedEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedEntitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int?> version = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> isTombstone = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedEntitiesCompanion(
                accountId: accountId,
                companyId: companyId,
                entityType: entityType,
                entityId: entityId,
                version: version,
                serverUpdatedAt: serverUpdatedAt,
                isTombstone: isTombstone,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String companyId,
                required String entityType,
                required String entityId,
                Value<int?> version = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> isTombstone = const Value.absent(),
                required String payloadJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedEntitiesCompanion.insert(
                accountId: accountId,
                companyId: companyId,
                entityType: entityType,
                entityId: entityId,
                version: version,
                serverUpdatedAt: serverUpdatedAt,
                isTombstone: isTombstone,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedEntitiesTable,
      CachedEntity,
      $$CachedEntitiesTableFilterComposer,
      $$CachedEntitiesTableOrderingComposer,
      $$CachedEntitiesTableAnnotationComposer,
      $$CachedEntitiesTableCreateCompanionBuilder,
      $$CachedEntitiesTableUpdateCompanionBuilder,
      (
        CachedEntity,
        BaseReferences<_$AppDatabase, $CachedEntitiesTable, CachedEntity>,
      ),
      CachedEntity,
      PrefetchHooks Function()
    >;
typedef $$OutboxRecordsTableCreateCompanionBuilder =
    OutboxRecordsCompanion Function({
      required String id,
      required String accountId,
      required String companyId,
      required String kind,
      required String payloadJson,
      Value<String?> dependsOnOperationId,
      Value<int?> baseVersion,
      Value<String> state,
      Value<int> attempts,
      Value<int?> lastStatusCode,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorCategory,
      Value<DateTime?> nextAttemptAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OutboxRecordsTableUpdateCompanionBuilder =
    OutboxRecordsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> companyId,
      Value<String> kind,
      Value<String> payloadJson,
      Value<String?> dependsOnOperationId,
      Value<int?> baseVersion,
      Value<String> state,
      Value<int> attempts,
      Value<int?> lastStatusCode,
      Value<String?> lastErrorCode,
      Value<String?> lastErrorCategory,
      Value<DateTime?> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OutboxRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastStatusCode => $composableBuilder(
    column: $table.lastStatusCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCategory => $composableBuilder(
    column: $table.lastErrorCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStatusCode => $composableBuilder(
    column: $table.lastStatusCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCategory => $composableBuilder(
    column: $table.lastErrorCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxRecordsTable> {
  $$OutboxRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dependsOnOperationId => $composableBuilder(
    column: $table.dependsOnOperationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get lastStatusCode => $composableBuilder(
    column: $table.lastStatusCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCategory => $composableBuilder(
    column: $table.lastErrorCategory,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OutboxRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxRecordsTable,
          OutboxRecord,
          $$OutboxRecordsTableFilterComposer,
          $$OutboxRecordsTableOrderingComposer,
          $$OutboxRecordsTableAnnotationComposer,
          $$OutboxRecordsTableCreateCompanionBuilder,
          $$OutboxRecordsTableUpdateCompanionBuilder,
          (
            OutboxRecord,
            BaseReferences<_$AppDatabase, $OutboxRecordsTable, OutboxRecord>,
          ),
          OutboxRecord,
          PrefetchHooks Function()
        > {
  $$OutboxRecordsTableTableManager(_$AppDatabase db, $OutboxRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String?> dependsOnOperationId = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> lastStatusCode = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorCategory = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxRecordsCompanion(
                id: id,
                accountId: accountId,
                companyId: companyId,
                kind: kind,
                payloadJson: payloadJson,
                dependsOnOperationId: dependsOnOperationId,
                baseVersion: baseVersion,
                state: state,
                attempts: attempts,
                lastStatusCode: lastStatusCode,
                lastErrorCode: lastErrorCode,
                lastErrorCategory: lastErrorCategory,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String companyId,
                required String kind,
                required String payloadJson,
                Value<String?> dependsOnOperationId = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int?> lastStatusCode = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<String?> lastErrorCategory = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxRecordsCompanion.insert(
                id: id,
                accountId: accountId,
                companyId: companyId,
                kind: kind,
                payloadJson: payloadJson,
                dependsOnOperationId: dependsOnOperationId,
                baseVersion: baseVersion,
                state: state,
                attempts: attempts,
                lastStatusCode: lastStatusCode,
                lastErrorCode: lastErrorCode,
                lastErrorCategory: lastErrorCategory,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxRecordsTable,
      OutboxRecord,
      $$OutboxRecordsTableFilterComposer,
      $$OutboxRecordsTableOrderingComposer,
      $$OutboxRecordsTableAnnotationComposer,
      $$OutboxRecordsTableCreateCompanionBuilder,
      $$OutboxRecordsTableUpdateCompanionBuilder,
      (
        OutboxRecord,
        BaseReferences<_$AppDatabase, $OutboxRecordsTable, OutboxRecord>,
      ),
      OutboxRecord,
      PrefetchHooks Function()
    >;
typedef $$DiagnosticRecordsTableCreateCompanionBuilder =
    DiagnosticRecordsCompanion Function({
      Value<int> id,
      Value<String?> accountId,
      Value<String?> companyId,
      required String event,
      required String status,
      Value<int?> durationMilliseconds,
      Value<int?> itemCount,
      required DateTime occurredAt,
    });
typedef $$DiagnosticRecordsTableUpdateCompanionBuilder =
    DiagnosticRecordsCompanion Function({
      Value<int> id,
      Value<String?> accountId,
      Value<String?> companyId,
      Value<String> event,
      Value<String> status,
      Value<int?> durationMilliseconds,
      Value<int?> itemCount,
      Value<DateTime> occurredAt,
    });

class $$DiagnosticRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DiagnosticRecordsTable> {
  $$DiagnosticRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get event => $composableBuilder(
    column: $table.event,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiagnosticRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiagnosticRecordsTable> {
  $$DiagnosticRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get event => $composableBuilder(
    column: $table.event,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiagnosticRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiagnosticRecordsTable> {
  $$DiagnosticRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$DiagnosticRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiagnosticRecordsTable,
          DiagnosticRecord,
          $$DiagnosticRecordsTableFilterComposer,
          $$DiagnosticRecordsTableOrderingComposer,
          $$DiagnosticRecordsTableAnnotationComposer,
          $$DiagnosticRecordsTableCreateCompanionBuilder,
          $$DiagnosticRecordsTableUpdateCompanionBuilder,
          (
            DiagnosticRecord,
            BaseReferences<
              _$AppDatabase,
              $DiagnosticRecordsTable,
              DiagnosticRecord
            >,
          ),
          DiagnosticRecord,
          PrefetchHooks Function()
        > {
  $$DiagnosticRecordsTableTableManager(
    _$AppDatabase db,
    $DiagnosticRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiagnosticRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiagnosticRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiagnosticRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                Value<String> event = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<int?> itemCount = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => DiagnosticRecordsCompanion(
                id: id,
                accountId: accountId,
                companyId: companyId,
                event: event,
                status: status,
                durationMilliseconds: durationMilliseconds,
                itemCount: itemCount,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> companyId = const Value.absent(),
                required String event,
                required String status,
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<int?> itemCount = const Value.absent(),
                required DateTime occurredAt,
              }) => DiagnosticRecordsCompanion.insert(
                id: id,
                accountId: accountId,
                companyId: companyId,
                event: event,
                status: status,
                durationMilliseconds: durationMilliseconds,
                itemCount: itemCount,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiagnosticRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiagnosticRecordsTable,
      DiagnosticRecord,
      $$DiagnosticRecordsTableFilterComposer,
      $$DiagnosticRecordsTableOrderingComposer,
      $$DiagnosticRecordsTableAnnotationComposer,
      $$DiagnosticRecordsTableCreateCompanionBuilder,
      $$DiagnosticRecordsTableUpdateCompanionBuilder,
      (
        DiagnosticRecord,
        BaseReferences<
          _$AppDatabase,
          $DiagnosticRecordsTable,
          DiagnosticRecord
        >,
      ),
      DiagnosticRecord,
      PrefetchHooks Function()
    >;
typedef $$DraftRecordsTableCreateCompanionBuilder =
    DraftRecordsCompanion Function({
      required String accountId,
      required String companyId,
      required String kind,
      required String draftId,
      required String payloadJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DraftRecordsTableUpdateCompanionBuilder =
    DraftRecordsCompanion Function({
      Value<String> accountId,
      Value<String> companyId,
      Value<String> kind,
      Value<String> draftId,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DraftRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DraftRecordsTable> {
  $$DraftRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DraftRecordsTable> {
  $$DraftRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftId => $composableBuilder(
    column: $table.draftId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DraftRecordsTable> {
  $$DraftRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get draftId =>
      $composableBuilder(column: $table.draftId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DraftRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DraftRecordsTable,
          DraftRecord,
          $$DraftRecordsTableFilterComposer,
          $$DraftRecordsTableOrderingComposer,
          $$DraftRecordsTableAnnotationComposer,
          $$DraftRecordsTableCreateCompanionBuilder,
          $$DraftRecordsTableUpdateCompanionBuilder,
          (
            DraftRecord,
            BaseReferences<_$AppDatabase, $DraftRecordsTable, DraftRecord>,
          ),
          DraftRecord,
          PrefetchHooks Function()
        > {
  $$DraftRecordsTableTableManager(_$AppDatabase db, $DraftRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> companyId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> draftId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftRecordsCompanion(
                accountId: accountId,
                companyId: companyId,
                kind: kind,
                draftId: draftId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String companyId,
                required String kind,
                required String draftId,
                required String payloadJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DraftRecordsCompanion.insert(
                accountId: accountId,
                companyId: companyId,
                kind: kind,
                draftId: draftId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DraftRecordsTable,
      DraftRecord,
      $$DraftRecordsTableFilterComposer,
      $$DraftRecordsTableOrderingComposer,
      $$DraftRecordsTableAnnotationComposer,
      $$DraftRecordsTableCreateCompanionBuilder,
      $$DraftRecordsTableUpdateCompanionBuilder,
      (
        DraftRecord,
        BaseReferences<_$AppDatabase, $DraftRecordsTable, DraftRecord>,
      ),
      DraftRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalScopesTableTableManager get localScopes =>
      $$LocalScopesTableTableManager(_db, _db.localScopes);
  $$BootstrapSnapshotsTableTableManager get bootstrapSnapshots =>
      $$BootstrapSnapshotsTableTableManager(_db, _db.bootstrapSnapshots);
  $$CachedEntitiesTableTableManager get cachedEntities =>
      $$CachedEntitiesTableTableManager(_db, _db.cachedEntities);
  $$OutboxRecordsTableTableManager get outboxRecords =>
      $$OutboxRecordsTableTableManager(_db, _db.outboxRecords);
  $$DiagnosticRecordsTableTableManager get diagnosticRecords =>
      $$DiagnosticRecordsTableTableManager(_db, _db.diagnosticRecords);
  $$DraftRecordsTableTableManager get draftRecords =>
      $$DraftRecordsTableTableManager(_db, _db.draftRecords);
}
