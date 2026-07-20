// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'intelligence_database.dart';

// ignore_for_file: type=lint
class $IntelligenceAssetsTable extends IntelligenceAssets
    with TableInfo<$IntelligenceAssetsTable, IntelligenceAssetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IntelligenceAssetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<String> mediaId = GeneratedColumn<String>(
    'media_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceScopeMeta = const VerificationMeta(
    'sourceScope',
  );
  @override
  late final GeneratedColumn<String> sourceScope = GeneratedColumn<String>(
    'source_scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalUriMeta = const VerificationMeta(
    'canonicalUri',
  );
  @override
  late final GeneratedColumn<String> canonicalUri = GeneratedColumn<String>(
    'canonical_uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identityKeyMeta = const VerificationMeta(
    'identityKey',
  );
  @override
  late final GeneratedColumn<String> identityKey = GeneratedColumn<String>(
    'identity_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaId,
    episodeId,
    sourceScope,
    canonicalUri,
    identityKey,
    fileHash,
    fileSize,
    modifiedAt,
    durationMs,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'intelligence_assets';
  @override
  VerificationContext validateIntegrity(
    Insertable<IntelligenceAssetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('source_scope')) {
      context.handle(
        _sourceScopeMeta,
        sourceScope.isAcceptableOrUnknown(
          data['source_scope']!,
          _sourceScopeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceScopeMeta);
    }
    if (data.containsKey('canonical_uri')) {
      context.handle(
        _canonicalUriMeta,
        canonicalUri.isAcceptableOrUnknown(
          data['canonical_uri']!,
          _canonicalUriMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalUriMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
        _identityKeyMeta,
        identityKey.isAcceptableOrUnknown(
          data['identity_key']!,
          _identityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
  IntelligenceAssetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IntelligenceAssetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_id'],
      ),
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      sourceScope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_scope'],
      )!,
      canonicalUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_uri'],
      )!,
      identityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_key'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $IntelligenceAssetsTable createAlias(String alias) {
    return $IntelligenceAssetsTable(attachedDatabase, alias);
  }
}

class IntelligenceAssetRow extends DataClass
    implements Insertable<IntelligenceAssetRow> {
  final String id;
  final String? mediaId;
  final String? episodeId;
  final String sourceScope;
  final String canonicalUri;
  final String identityKey;
  final String? fileHash;
  final int? fileSize;
  final int? modifiedAt;
  final int? durationMs;
  final String status;
  final String createdAt;
  final String updatedAt;
  const IntelligenceAssetRow({
    required this.id,
    this.mediaId,
    this.episodeId,
    required this.sourceScope,
    required this.canonicalUri,
    required this.identityKey,
    this.fileHash,
    this.fileSize,
    this.modifiedAt,
    this.durationMs,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<String>(mediaId);
    }
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['source_scope'] = Variable<String>(sourceScope);
    map['canonical_uri'] = Variable<String>(canonicalUri);
    map['identity_key'] = Variable<String>(identityKey);
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<int>(modifiedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  IntelligenceAssetsCompanion toCompanion(bool nullToAbsent) {
    return IntelligenceAssetsCompanion(
      id: Value(id),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      sourceScope: Value(sourceScope),
      canonicalUri: Value(canonicalUri),
      identityKey: Value(identityKey),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory IntelligenceAssetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IntelligenceAssetRow(
      id: serializer.fromJson<String>(json['id']),
      mediaId: serializer.fromJson<String?>(json['mediaId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      sourceScope: serializer.fromJson<String>(json['sourceScope']),
      canonicalUri: serializer.fromJson<String>(json['canonicalUri']),
      identityKey: serializer.fromJson<String>(json['identityKey']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      modifiedAt: serializer.fromJson<int?>(json['modifiedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'mediaId': serializer.toJson<String?>(mediaId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'sourceScope': serializer.toJson<String>(sourceScope),
      'canonicalUri': serializer.toJson<String>(canonicalUri),
      'identityKey': serializer.toJson<String>(identityKey),
      'fileHash': serializer.toJson<String?>(fileHash),
      'fileSize': serializer.toJson<int?>(fileSize),
      'modifiedAt': serializer.toJson<int?>(modifiedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  IntelligenceAssetRow copyWith({
    String? id,
    Value<String?> mediaId = const Value.absent(),
    Value<String?> episodeId = const Value.absent(),
    String? sourceScope,
    String? canonicalUri,
    String? identityKey,
    Value<String?> fileHash = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    Value<int?> modifiedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    String? status,
    String? createdAt,
    String? updatedAt,
  }) => IntelligenceAssetRow(
    id: id ?? this.id,
    mediaId: mediaId.present ? mediaId.value : this.mediaId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    sourceScope: sourceScope ?? this.sourceScope,
    canonicalUri: canonicalUri ?? this.canonicalUri,
    identityKey: identityKey ?? this.identityKey,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  IntelligenceAssetRow copyWithCompanion(IntelligenceAssetsCompanion data) {
    return IntelligenceAssetRow(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      sourceScope: data.sourceScope.present
          ? data.sourceScope.value
          : this.sourceScope,
      canonicalUri: data.canonicalUri.present
          ? data.canonicalUri.value
          : this.canonicalUri,
      identityKey: data.identityKey.present
          ? data.identityKey.value
          : this.identityKey,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IntelligenceAssetRow(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeId: $episodeId, ')
          ..write('sourceScope: $sourceScope, ')
          ..write('canonicalUri: $canonicalUri, ')
          ..write('identityKey: $identityKey, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaId,
    episodeId,
    sourceScope,
    canonicalUri,
    identityKey,
    fileHash,
    fileSize,
    modifiedAt,
    durationMs,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntelligenceAssetRow &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.episodeId == this.episodeId &&
          other.sourceScope == this.sourceScope &&
          other.canonicalUri == this.canonicalUri &&
          other.identityKey == this.identityKey &&
          other.fileHash == this.fileHash &&
          other.fileSize == this.fileSize &&
          other.modifiedAt == this.modifiedAt &&
          other.durationMs == this.durationMs &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class IntelligenceAssetsCompanion
    extends UpdateCompanion<IntelligenceAssetRow> {
  final Value<String> id;
  final Value<String?> mediaId;
  final Value<String?> episodeId;
  final Value<String> sourceScope;
  final Value<String> canonicalUri;
  final Value<String> identityKey;
  final Value<String?> fileHash;
  final Value<int?> fileSize;
  final Value<int?> modifiedAt;
  final Value<int?> durationMs;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const IntelligenceAssetsCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.sourceScope = const Value.absent(),
    this.canonicalUri = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IntelligenceAssetsCompanion.insert({
    required String id,
    this.mediaId = const Value.absent(),
    this.episodeId = const Value.absent(),
    required String sourceScope,
    required String canonicalUri,
    required String identityKey,
    this.fileHash = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceScope = Value(sourceScope),
       canonicalUri = Value(canonicalUri),
       identityKey = Value(identityKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<IntelligenceAssetRow> custom({
    Expression<String>? id,
    Expression<String>? mediaId,
    Expression<String>? episodeId,
    Expression<String>? sourceScope,
    Expression<String>? canonicalUri,
    Expression<String>? identityKey,
    Expression<String>? fileHash,
    Expression<int>? fileSize,
    Expression<int>? modifiedAt,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (episodeId != null) 'episode_id': episodeId,
      if (sourceScope != null) 'source_scope': sourceScope,
      if (canonicalUri != null) 'canonical_uri': canonicalUri,
      if (identityKey != null) 'identity_key': identityKey,
      if (fileHash != null) 'file_hash': fileHash,
      if (fileSize != null) 'file_size': fileSize,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IntelligenceAssetsCompanion copyWith({
    Value<String>? id,
    Value<String?>? mediaId,
    Value<String?>? episodeId,
    Value<String>? sourceScope,
    Value<String>? canonicalUri,
    Value<String>? identityKey,
    Value<String?>? fileHash,
    Value<int?>? fileSize,
    Value<int?>? modifiedAt,
    Value<int?>? durationMs,
    Value<String>? status,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return IntelligenceAssetsCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      episodeId: episodeId ?? this.episodeId,
      sourceScope: sourceScope ?? this.sourceScope,
      canonicalUri: canonicalUri ?? this.canonicalUri,
      identityKey: identityKey ?? this.identityKey,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
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
    if (mediaId.present) {
      map['media_id'] = Variable<String>(mediaId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (sourceScope.present) {
      map['source_scope'] = Variable<String>(sourceScope.value);
    }
    if (canonicalUri.present) {
      map['canonical_uri'] = Variable<String>(canonicalUri.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<String>(identityKey.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IntelligenceAssetsCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('episodeId: $episodeId, ')
          ..write('sourceScope: $sourceScope, ')
          ..write('canonicalUri: $canonicalUri, ')
          ..write('identityKey: $identityKey, ')
          ..write('fileHash: $fileHash, ')
          ..write('fileSize: $fileSize, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiJobsTable extends AiJobs with TableInfo<$AiJobsTable, AiJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _checkpointMeta = const VerificationMeta(
    'checkpoint',
  );
  @override
  late final GeneratedColumn<String> checkpoint = GeneratedColumn<String>(
    'checkpoint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    type,
    model,
    status,
    progress,
    attempts,
    checkpoint,
    error,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('checkpoint')) {
      context.handle(
        _checkpointMeta,
        checkpoint.isAcceptableOrUnknown(data['checkpoint']!, _checkpointMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
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
  AiJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      checkpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checkpoint'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AiJobsTable createAlias(String alias) {
    return $AiJobsTable(attachedDatabase, alias);
  }
}

class AiJobRow extends DataClass implements Insertable<AiJobRow> {
  final String id;
  final String assetId;
  final String type;
  final String model;
  final String status;
  final double progress;
  final int attempts;
  final String? checkpoint;
  final String? error;
  final String createdAt;
  final String updatedAt;
  const AiJobRow({
    required this.id,
    required this.assetId,
    required this.type,
    required this.model,
    required this.status,
    required this.progress,
    required this.attempts,
    this.checkpoint,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['type'] = Variable<String>(type);
    map['model'] = Variable<String>(model);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<double>(progress);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || checkpoint != null) {
      map['checkpoint'] = Variable<String>(checkpoint);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AiJobsCompanion toCompanion(bool nullToAbsent) {
    return AiJobsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      type: Value(type),
      model: Value(model),
      status: Value(status),
      progress: Value(progress),
      attempts: Value(attempts),
      checkpoint: checkpoint == null && nullToAbsent
          ? const Value.absent()
          : Value(checkpoint),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiJobRow(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      type: serializer.fromJson<String>(json['type']),
      model: serializer.fromJson<String>(json['model']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<double>(json['progress']),
      attempts: serializer.fromJson<int>(json['attempts']),
      checkpoint: serializer.fromJson<String?>(json['checkpoint']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'type': serializer.toJson<String>(type),
      'model': serializer.toJson<String>(model),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<double>(progress),
      'attempts': serializer.toJson<int>(attempts),
      'checkpoint': serializer.toJson<String?>(checkpoint),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  AiJobRow copyWith({
    String? id,
    String? assetId,
    String? type,
    String? model,
    String? status,
    double? progress,
    int? attempts,
    Value<String?> checkpoint = const Value.absent(),
    Value<String?> error = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => AiJobRow(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    type: type ?? this.type,
    model: model ?? this.model,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    attempts: attempts ?? this.attempts,
    checkpoint: checkpoint.present ? checkpoint.value : this.checkpoint,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AiJobRow copyWithCompanion(AiJobsCompanion data) {
    return AiJobRow(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      type: data.type.present ? data.type.value : this.type,
      model: data.model.present ? data.model.value : this.model,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      checkpoint: data.checkpoint.present
          ? data.checkpoint.value
          : this.checkpoint,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiJobRow(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('attempts: $attempts, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    type,
    model,
    status,
    progress,
    attempts,
    checkpoint,
    error,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiJobRow &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.type == this.type &&
          other.model == this.model &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.attempts == this.attempts &&
          other.checkpoint == this.checkpoint &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiJobsCompanion extends UpdateCompanion<AiJobRow> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<String> type;
  final Value<String> model;
  final Value<String> status;
  final Value<double> progress;
  final Value<int> attempts;
  final Value<String?> checkpoint;
  final Value<String?> error;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AiJobsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.type = const Value.absent(),
    this.model = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.attempts = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiJobsCompanion.insert({
    required String id,
    required String assetId,
    required String type,
    required String model,
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.attempts = const Value.absent(),
    this.checkpoint = const Value.absent(),
    this.error = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       type = Value(type),
       model = Value(model),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AiJobRow> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<String>? type,
    Expression<String>? model,
    Expression<String>? status,
    Expression<double>? progress,
    Expression<int>? attempts,
    Expression<String>? checkpoint,
    Expression<String>? error,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (type != null) 'type': type,
      if (model != null) 'model': model,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (attempts != null) 'attempts': attempts,
      if (checkpoint != null) 'checkpoint': checkpoint,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<String>? type,
    Value<String>? model,
    Value<String>? status,
    Value<double>? progress,
    Value<int>? attempts,
    Value<String?>? checkpoint,
    Value<String?>? error,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return AiJobsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      type: type ?? this.type,
      model: model ?? this.model,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      attempts: attempts ?? this.attempts,
      checkpoint: checkpoint ?? this.checkpoint,
      error: error ?? this.error,
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
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (checkpoint.present) {
      map['checkpoint'] = Variable<String>(checkpoint.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiJobsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('attempts: $attempts, ')
          ..write('checkpoint: $checkpoint, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TranscriptSegmentsTable extends TranscriptSegments
    with TableInfo<$TranscriptSegmentsTable, TranscriptSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranscriptSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _translatedTextMeta = const VerificationMeta(
    'translatedText',
  );
  @override
  late final GeneratedColumn<String> translatedText = GeneratedColumn<String>(
    'translated_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speakerMeta = const VerificationMeta(
    'speaker',
  );
  @override
  late final GeneratedColumn<String> speaker = GeneratedColumn<String>(
    'speaker',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    startMs,
    endMs,
    content,
    language,
    translatedText,
    confidence,
    speaker,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transcript_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranscriptSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('translated_text')) {
      context.handle(
        _translatedTextMeta,
        translatedText.isAcceptableOrUnknown(
          data['translated_text']!,
          _translatedTextMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('speaker')) {
      context.handle(
        _speakerMeta,
        speaker.isAcceptableOrUnknown(data['speaker']!, _speakerMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranscriptSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranscriptSegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      translatedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_text'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      speaker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TranscriptSegmentsTable createAlias(String alias) {
    return $TranscriptSegmentsTable(attachedDatabase, alias);
  }
}

class TranscriptSegmentRow extends DataClass
    implements Insertable<TranscriptSegmentRow> {
  final String id;
  final String assetId;
  final int startMs;
  final int endMs;
  final String content;
  final String language;
  final String? translatedText;
  final double? confidence;
  final String? speaker;
  final String createdAt;
  const TranscriptSegmentRow({
    required this.id,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.content,
    required this.language,
    this.translatedText,
    this.confidence,
    this.speaker,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['content'] = Variable<String>(content);
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || translatedText != null) {
      map['translated_text'] = Variable<String>(translatedText);
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    if (!nullToAbsent || speaker != null) {
      map['speaker'] = Variable<String>(speaker);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  TranscriptSegmentsCompanion toCompanion(bool nullToAbsent) {
    return TranscriptSegmentsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      startMs: Value(startMs),
      endMs: Value(endMs),
      content: Value(content),
      language: Value(language),
      translatedText: translatedText == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedText),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      speaker: speaker == null && nullToAbsent
          ? const Value.absent()
          : Value(speaker),
      createdAt: Value(createdAt),
    );
  }

  factory TranscriptSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranscriptSegmentRow(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      content: serializer.fromJson<String>(json['content']),
      language: serializer.fromJson<String>(json['language']),
      translatedText: serializer.fromJson<String?>(json['translatedText']),
      confidence: serializer.fromJson<double?>(json['confidence']),
      speaker: serializer.fromJson<String?>(json['speaker']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'content': serializer.toJson<String>(content),
      'language': serializer.toJson<String>(language),
      'translatedText': serializer.toJson<String?>(translatedText),
      'confidence': serializer.toJson<double?>(confidence),
      'speaker': serializer.toJson<String?>(speaker),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  TranscriptSegmentRow copyWith({
    String? id,
    String? assetId,
    int? startMs,
    int? endMs,
    String? content,
    String? language,
    Value<String?> translatedText = const Value.absent(),
    Value<double?> confidence = const Value.absent(),
    Value<String?> speaker = const Value.absent(),
    String? createdAt,
  }) => TranscriptSegmentRow(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    content: content ?? this.content,
    language: language ?? this.language,
    translatedText: translatedText.present
        ? translatedText.value
        : this.translatedText,
    confidence: confidence.present ? confidence.value : this.confidence,
    speaker: speaker.present ? speaker.value : this.speaker,
    createdAt: createdAt ?? this.createdAt,
  );
  TranscriptSegmentRow copyWithCompanion(TranscriptSegmentsCompanion data) {
    return TranscriptSegmentRow(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      content: data.content.present ? data.content.value : this.content,
      language: data.language.present ? data.language.value : this.language,
      translatedText: data.translatedText.present
          ? data.translatedText.value
          : this.translatedText,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      speaker: data.speaker.present ? data.speaker.value : this.speaker,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentRow(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('translatedText: $translatedText, ')
          ..write('confidence: $confidence, ')
          ..write('speaker: $speaker, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    startMs,
    endMs,
    content,
    language,
    translatedText,
    confidence,
    speaker,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranscriptSegmentRow &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.content == this.content &&
          other.language == this.language &&
          other.translatedText == this.translatedText &&
          other.confidence == this.confidence &&
          other.speaker == this.speaker &&
          other.createdAt == this.createdAt);
}

class TranscriptSegmentsCompanion
    extends UpdateCompanion<TranscriptSegmentRow> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> content;
  final Value<String> language;
  final Value<String?> translatedText;
  final Value<double?> confidence;
  final Value<String?> speaker;
  final Value<String> createdAt;
  final Value<int> rowid;
  const TranscriptSegmentsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.content = const Value.absent(),
    this.language = const Value.absent(),
    this.translatedText = const Value.absent(),
    this.confidence = const Value.absent(),
    this.speaker = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TranscriptSegmentsCompanion.insert({
    required String id,
    required String assetId,
    required int startMs,
    required int endMs,
    required String content,
    this.language = const Value.absent(),
    this.translatedText = const Value.absent(),
    this.confidence = const Value.absent(),
    this.speaker = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       startMs = Value(startMs),
       endMs = Value(endMs),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<TranscriptSegmentRow> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? content,
    Expression<String>? language,
    Expression<String>? translatedText,
    Expression<double>? confidence,
    Expression<String>? speaker,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (content != null) 'content': content,
      if (language != null) 'language': language,
      if (translatedText != null) 'translated_text': translatedText,
      if (confidence != null) 'confidence': confidence,
      if (speaker != null) 'speaker': speaker,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TranscriptSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? content,
    Value<String>? language,
    Value<String?>? translatedText,
    Value<double?>? confidence,
    Value<String?>? speaker,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return TranscriptSegmentsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      content: content ?? this.content,
      language: language ?? this.language,
      translatedText: translatedText ?? this.translatedText,
      confidence: confidence ?? this.confidence,
      speaker: speaker ?? this.speaker,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (translatedText.present) {
      map['translated_text'] = Variable<String>(translatedText.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (speaker.present) {
      map['speaker'] = Variable<String>(speaker.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranscriptSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('content: $content, ')
          ..write('language: $language, ')
          ..write('translatedText: $translatedText, ')
          ..write('confidence: $confidence, ')
          ..write('speaker: $speaker, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentSegmentsTable extends ContentSegments
    with TableInfo<$ContentSegmentsTable, ContentSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMsMeta = const VerificationMeta(
    'startMs',
  );
  @override
  late final GeneratedColumn<int> startMs = GeneratedColumn<int>(
    'start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMsMeta = const VerificationMeta('endMs');
  @override
  late final GeneratedColumn<int> endMs = GeneratedColumn<int>(
    'end_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _peopleJsonMeta = const VerificationMeta(
    'peopleJson',
  );
  @override
  late final GeneratedColumn<String> peopleJson = GeneratedColumn<String>(
    'people_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _placesJsonMeta = const VerificationMeta(
    'placesJson',
  );
  @override
  late final GeneratedColumn<String> placesJson = GeneratedColumn<String>(
    'places_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _themesJsonMeta = const VerificationMeta(
    'themesJson',
  );
  @override
  late final GeneratedColumn<String> themesJson = GeneratedColumn<String>(
    'themes_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _screenshotPathMeta = const VerificationMeta(
    'screenshotPath',
  );
  @override
  late final GeneratedColumn<String> screenshotPath = GeneratedColumn<String>(
    'screenshot_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _searchTextMeta = const VerificationMeta(
    'searchText',
  );
  @override
  late final GeneratedColumn<String> searchText = GeneratedColumn<String>(
    'search_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    startMs,
    endMs,
    title,
    summary,
    peopleJson,
    placesJson,
    themesJson,
    screenshotPath,
    searchText,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('start_ms')) {
      context.handle(
        _startMsMeta,
        startMs.isAcceptableOrUnknown(data['start_ms']!, _startMsMeta),
      );
    } else if (isInserting) {
      context.missing(_startMsMeta);
    }
    if (data.containsKey('end_ms')) {
      context.handle(
        _endMsMeta,
        endMs.isAcceptableOrUnknown(data['end_ms']!, _endMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endMsMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('people_json')) {
      context.handle(
        _peopleJsonMeta,
        peopleJson.isAcceptableOrUnknown(data['people_json']!, _peopleJsonMeta),
      );
    }
    if (data.containsKey('places_json')) {
      context.handle(
        _placesJsonMeta,
        placesJson.isAcceptableOrUnknown(data['places_json']!, _placesJsonMeta),
      );
    }
    if (data.containsKey('themes_json')) {
      context.handle(
        _themesJsonMeta,
        themesJson.isAcceptableOrUnknown(data['themes_json']!, _themesJsonMeta),
      );
    }
    if (data.containsKey('screenshot_path')) {
      context.handle(
        _screenshotPathMeta,
        screenshotPath.isAcceptableOrUnknown(
          data['screenshot_path']!,
          _screenshotPathMeta,
        ),
      );
    }
    if (data.containsKey('search_text')) {
      context.handle(
        _searchTextMeta,
        searchText.isAcceptableOrUnknown(data['search_text']!, _searchTextMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentSegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      startMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_ms'],
      )!,
      endMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_ms'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      peopleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}people_json'],
      ),
      placesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}places_json'],
      ),
      themesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}themes_json'],
      ),
      screenshotPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}screenshot_path'],
      ),
      searchText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_text'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ContentSegmentsTable createAlias(String alias) {
    return $ContentSegmentsTable(attachedDatabase, alias);
  }
}

class ContentSegmentRow extends DataClass
    implements Insertable<ContentSegmentRow> {
  final String id;
  final String assetId;
  final int startMs;
  final int endMs;
  final String title;
  final String summary;
  final String? peopleJson;
  final String? placesJson;
  final String? themesJson;
  final String? screenshotPath;
  final String searchText;
  final String createdAt;
  const ContentSegmentRow({
    required this.id,
    required this.assetId,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.summary,
    this.peopleJson,
    this.placesJson,
    this.themesJson,
    this.screenshotPath,
    required this.searchText,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['start_ms'] = Variable<int>(startMs);
    map['end_ms'] = Variable<int>(endMs);
    map['title'] = Variable<String>(title);
    map['summary'] = Variable<String>(summary);
    if (!nullToAbsent || peopleJson != null) {
      map['people_json'] = Variable<String>(peopleJson);
    }
    if (!nullToAbsent || placesJson != null) {
      map['places_json'] = Variable<String>(placesJson);
    }
    if (!nullToAbsent || themesJson != null) {
      map['themes_json'] = Variable<String>(themesJson);
    }
    if (!nullToAbsent || screenshotPath != null) {
      map['screenshot_path'] = Variable<String>(screenshotPath);
    }
    map['search_text'] = Variable<String>(searchText);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ContentSegmentsCompanion toCompanion(bool nullToAbsent) {
    return ContentSegmentsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      startMs: Value(startMs),
      endMs: Value(endMs),
      title: Value(title),
      summary: Value(summary),
      peopleJson: peopleJson == null && nullToAbsent
          ? const Value.absent()
          : Value(peopleJson),
      placesJson: placesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(placesJson),
      themesJson: themesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(themesJson),
      screenshotPath: screenshotPath == null && nullToAbsent
          ? const Value.absent()
          : Value(screenshotPath),
      searchText: Value(searchText),
      createdAt: Value(createdAt),
    );
  }

  factory ContentSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentSegmentRow(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      startMs: serializer.fromJson<int>(json['startMs']),
      endMs: serializer.fromJson<int>(json['endMs']),
      title: serializer.fromJson<String>(json['title']),
      summary: serializer.fromJson<String>(json['summary']),
      peopleJson: serializer.fromJson<String?>(json['peopleJson']),
      placesJson: serializer.fromJson<String?>(json['placesJson']),
      themesJson: serializer.fromJson<String?>(json['themesJson']),
      screenshotPath: serializer.fromJson<String?>(json['screenshotPath']),
      searchText: serializer.fromJson<String>(json['searchText']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'startMs': serializer.toJson<int>(startMs),
      'endMs': serializer.toJson<int>(endMs),
      'title': serializer.toJson<String>(title),
      'summary': serializer.toJson<String>(summary),
      'peopleJson': serializer.toJson<String?>(peopleJson),
      'placesJson': serializer.toJson<String?>(placesJson),
      'themesJson': serializer.toJson<String?>(themesJson),
      'screenshotPath': serializer.toJson<String?>(screenshotPath),
      'searchText': serializer.toJson<String>(searchText),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  ContentSegmentRow copyWith({
    String? id,
    String? assetId,
    int? startMs,
    int? endMs,
    String? title,
    String? summary,
    Value<String?> peopleJson = const Value.absent(),
    Value<String?> placesJson = const Value.absent(),
    Value<String?> themesJson = const Value.absent(),
    Value<String?> screenshotPath = const Value.absent(),
    String? searchText,
    String? createdAt,
  }) => ContentSegmentRow(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    startMs: startMs ?? this.startMs,
    endMs: endMs ?? this.endMs,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    peopleJson: peopleJson.present ? peopleJson.value : this.peopleJson,
    placesJson: placesJson.present ? placesJson.value : this.placesJson,
    themesJson: themesJson.present ? themesJson.value : this.themesJson,
    screenshotPath: screenshotPath.present
        ? screenshotPath.value
        : this.screenshotPath,
    searchText: searchText ?? this.searchText,
    createdAt: createdAt ?? this.createdAt,
  );
  ContentSegmentRow copyWithCompanion(ContentSegmentsCompanion data) {
    return ContentSegmentRow(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      startMs: data.startMs.present ? data.startMs.value : this.startMs,
      endMs: data.endMs.present ? data.endMs.value : this.endMs,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      peopleJson: data.peopleJson.present
          ? data.peopleJson.value
          : this.peopleJson,
      placesJson: data.placesJson.present
          ? data.placesJson.value
          : this.placesJson,
      themesJson: data.themesJson.present
          ? data.themesJson.value
          : this.themesJson,
      screenshotPath: data.screenshotPath.present
          ? data.screenshotPath.value
          : this.screenshotPath,
      searchText: data.searchText.present
          ? data.searchText.value
          : this.searchText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentSegmentRow(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('peopleJson: $peopleJson, ')
          ..write('placesJson: $placesJson, ')
          ..write('themesJson: $themesJson, ')
          ..write('screenshotPath: $screenshotPath, ')
          ..write('searchText: $searchText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    startMs,
    endMs,
    title,
    summary,
    peopleJson,
    placesJson,
    themesJson,
    screenshotPath,
    searchText,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentSegmentRow &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.startMs == this.startMs &&
          other.endMs == this.endMs &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.peopleJson == this.peopleJson &&
          other.placesJson == this.placesJson &&
          other.themesJson == this.themesJson &&
          other.screenshotPath == this.screenshotPath &&
          other.searchText == this.searchText &&
          other.createdAt == this.createdAt);
}

class ContentSegmentsCompanion extends UpdateCompanion<ContentSegmentRow> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<int> startMs;
  final Value<int> endMs;
  final Value<String> title;
  final Value<String> summary;
  final Value<String?> peopleJson;
  final Value<String?> placesJson;
  final Value<String?> themesJson;
  final Value<String?> screenshotPath;
  final Value<String> searchText;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ContentSegmentsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.startMs = const Value.absent(),
    this.endMs = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.peopleJson = const Value.absent(),
    this.placesJson = const Value.absent(),
    this.themesJson = const Value.absent(),
    this.screenshotPath = const Value.absent(),
    this.searchText = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentSegmentsCompanion.insert({
    required String id,
    required String assetId,
    required int startMs,
    required int endMs,
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.peopleJson = const Value.absent(),
    this.placesJson = const Value.absent(),
    this.themesJson = const Value.absent(),
    this.screenshotPath = const Value.absent(),
    this.searchText = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       startMs = Value(startMs),
       endMs = Value(endMs),
       createdAt = Value(createdAt);
  static Insertable<ContentSegmentRow> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<int>? startMs,
    Expression<int>? endMs,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? peopleJson,
    Expression<String>? placesJson,
    Expression<String>? themesJson,
    Expression<String>? screenshotPath,
    Expression<String>? searchText,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (startMs != null) 'start_ms': startMs,
      if (endMs != null) 'end_ms': endMs,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (peopleJson != null) 'people_json': peopleJson,
      if (placesJson != null) 'places_json': placesJson,
      if (themesJson != null) 'themes_json': themesJson,
      if (screenshotPath != null) 'screenshot_path': screenshotPath,
      if (searchText != null) 'search_text': searchText,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<int>? startMs,
    Value<int>? endMs,
    Value<String>? title,
    Value<String>? summary,
    Value<String?>? peopleJson,
    Value<String?>? placesJson,
    Value<String?>? themesJson,
    Value<String?>? screenshotPath,
    Value<String>? searchText,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ContentSegmentsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      peopleJson: peopleJson ?? this.peopleJson,
      placesJson: placesJson ?? this.placesJson,
      themesJson: themesJson ?? this.themesJson,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      searchText: searchText ?? this.searchText,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (startMs.present) {
      map['start_ms'] = Variable<int>(startMs.value);
    }
    if (endMs.present) {
      map['end_ms'] = Variable<int>(endMs.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (peopleJson.present) {
      map['people_json'] = Variable<String>(peopleJson.value);
    }
    if (placesJson.present) {
      map['places_json'] = Variable<String>(placesJson.value);
    }
    if (themesJson.present) {
      map['themes_json'] = Variable<String>(themesJson.value);
    }
    if (screenshotPath.present) {
      map['screenshot_path'] = Variable<String>(screenshotPath.value);
    }
    if (searchText.present) {
      map['search_text'] = Variable<String>(searchText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('startMs: $startMs, ')
          ..write('endMs: $endMs, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('peopleJson: $peopleJson, ')
          ..write('placesJson: $placesJson, ')
          ..write('themesJson: $themesJson, ')
          ..write('screenshotPath: $screenshotPath, ')
          ..write('searchText: $searchText, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingItemsTable extends EmbeddingItems
    with TableInfo<$EmbeddingItemsTable, EmbeddingItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modalityMeta = const VerificationMeta(
    'modality',
  );
  @override
  late final GeneratedColumn<String> modality = GeneratedColumn<String>(
    'modality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimensionsMeta = const VerificationMeta(
    'dimensions',
  );
  @override
  late final GeneratedColumn<int> dimensions = GeneratedColumn<int>(
    'dimensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
    'vector',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    segmentId,
    modality,
    model,
    dimensions,
    vector,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embedding_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EmbeddingItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentIdMeta);
    }
    if (data.containsKey('modality')) {
      context.handle(
        _modalityMeta,
        modality.isAcceptableOrUnknown(data['modality']!, _modalityMeta),
      );
    } else if (isInserting) {
      context.missing(_modalityMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('dimensions')) {
      context.handle(
        _dimensionsMeta,
        dimensions.isAcceptableOrUnknown(data['dimensions']!, _dimensionsMeta),
      );
    } else if (isInserting) {
      context.missing(_dimensionsMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(
        _vectorMeta,
        vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta),
      );
    } else if (isInserting) {
      context.missing(_vectorMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EmbeddingItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EmbeddingItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      )!,
      modality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modality'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      dimensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dimensions'],
      )!,
      vector: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vector'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EmbeddingItemsTable createAlias(String alias) {
    return $EmbeddingItemsTable(attachedDatabase, alias);
  }
}

class EmbeddingItemRow extends DataClass
    implements Insertable<EmbeddingItemRow> {
  final String id;
  final String assetId;
  final String segmentId;
  final String modality;
  final String model;
  final int dimensions;
  final Uint8List vector;
  final String createdAt;
  const EmbeddingItemRow({
    required this.id,
    required this.assetId,
    required this.segmentId,
    required this.modality,
    required this.model,
    required this.dimensions,
    required this.vector,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['segment_id'] = Variable<String>(segmentId);
    map['modality'] = Variable<String>(modality);
    map['model'] = Variable<String>(model);
    map['dimensions'] = Variable<int>(dimensions);
    map['vector'] = Variable<Uint8List>(vector);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  EmbeddingItemsCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingItemsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      segmentId: Value(segmentId),
      modality: Value(modality),
      model: Value(model),
      dimensions: Value(dimensions),
      vector: Value(vector),
      createdAt: Value(createdAt),
    );
  }

  factory EmbeddingItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EmbeddingItemRow(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      segmentId: serializer.fromJson<String>(json['segmentId']),
      modality: serializer.fromJson<String>(json['modality']),
      model: serializer.fromJson<String>(json['model']),
      dimensions: serializer.fromJson<int>(json['dimensions']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'segmentId': serializer.toJson<String>(segmentId),
      'modality': serializer.toJson<String>(modality),
      'model': serializer.toJson<String>(model),
      'dimensions': serializer.toJson<int>(dimensions),
      'vector': serializer.toJson<Uint8List>(vector),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  EmbeddingItemRow copyWith({
    String? id,
    String? assetId,
    String? segmentId,
    String? modality,
    String? model,
    int? dimensions,
    Uint8List? vector,
    String? createdAt,
  }) => EmbeddingItemRow(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    segmentId: segmentId ?? this.segmentId,
    modality: modality ?? this.modality,
    model: model ?? this.model,
    dimensions: dimensions ?? this.dimensions,
    vector: vector ?? this.vector,
    createdAt: createdAt ?? this.createdAt,
  );
  EmbeddingItemRow copyWithCompanion(EmbeddingItemsCompanion data) {
    return EmbeddingItemRow(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      modality: data.modality.present ? data.modality.value : this.modality,
      model: data.model.present ? data.model.value : this.model,
      dimensions: data.dimensions.present
          ? data.dimensions.value
          : this.dimensions,
      vector: data.vector.present ? data.vector.value : this.vector,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingItemRow(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('segmentId: $segmentId, ')
          ..write('modality: $modality, ')
          ..write('model: $model, ')
          ..write('dimensions: $dimensions, ')
          ..write('vector: $vector, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    segmentId,
    modality,
    model,
    dimensions,
    $driftBlobEquality.hash(vector),
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EmbeddingItemRow &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.segmentId == this.segmentId &&
          other.modality == this.modality &&
          other.model == this.model &&
          other.dimensions == this.dimensions &&
          $driftBlobEquality.equals(other.vector, this.vector) &&
          other.createdAt == this.createdAt);
}

class EmbeddingItemsCompanion extends UpdateCompanion<EmbeddingItemRow> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<String> segmentId;
  final Value<String> modality;
  final Value<String> model;
  final Value<int> dimensions;
  final Value<Uint8List> vector;
  final Value<String> createdAt;
  final Value<int> rowid;
  const EmbeddingItemsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.modality = const Value.absent(),
    this.model = const Value.absent(),
    this.dimensions = const Value.absent(),
    this.vector = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EmbeddingItemsCompanion.insert({
    required String id,
    required String assetId,
    required String segmentId,
    required String modality,
    required String model,
    required int dimensions,
    required Uint8List vector,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       segmentId = Value(segmentId),
       modality = Value(modality),
       model = Value(model),
       dimensions = Value(dimensions),
       vector = Value(vector),
       createdAt = Value(createdAt);
  static Insertable<EmbeddingItemRow> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<String>? segmentId,
    Expression<String>? modality,
    Expression<String>? model,
    Expression<int>? dimensions,
    Expression<Uint8List>? vector,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (segmentId != null) 'segment_id': segmentId,
      if (modality != null) 'modality': modality,
      if (model != null) 'model': model,
      if (dimensions != null) 'dimensions': dimensions,
      if (vector != null) 'vector': vector,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EmbeddingItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<String>? segmentId,
    Value<String>? modality,
    Value<String>? model,
    Value<int>? dimensions,
    Value<Uint8List>? vector,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return EmbeddingItemsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      segmentId: segmentId ?? this.segmentId,
      modality: modality ?? this.modality,
      model: model ?? this.model,
      dimensions: dimensions ?? this.dimensions,
      vector: vector ?? this.vector,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (modality.present) {
      map['modality'] = Variable<String>(modality.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (dimensions.present) {
      map['dimensions'] = Variable<int>(dimensions.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingItemsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('segmentId: $segmentId, ')
          ..write('modality: $modality, ')
          ..write('model: $model, ')
          ..write('dimensions: $dimensions, ')
          ..write('vector: $vector, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WatchEventsTable extends WatchEvents
    with TableInfo<$WatchEventsTable, WatchEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WatchEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
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
  static const VerificationMeta _positionMsMeta = const VerificationMeta(
    'positionMs',
  );
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
    'position_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    assetId,
    kind,
    positionMs,
    durationMs,
    occurredAt,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'watch_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<WatchEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
        _positionMsMeta,
        positionMs.isAcceptableOrUnknown(data['position_ms']!, _positionMsMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
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
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WatchEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WatchEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      positionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurred_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      ),
    );
  }

  @override
  $WatchEventsTable createAlias(String alias) {
    return $WatchEventsTable(attachedDatabase, alias);
  }
}

class WatchEventRow extends DataClass implements Insertable<WatchEventRow> {
  final String id;
  final String assetId;
  final String kind;
  final int positionMs;
  final int? durationMs;
  final String occurredAt;
  final String? payload;
  const WatchEventRow({
    required this.id,
    required this.assetId,
    required this.kind,
    required this.positionMs,
    this.durationMs,
    required this.occurredAt,
    this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['asset_id'] = Variable<String>(assetId);
    map['kind'] = Variable<String>(kind);
    map['position_ms'] = Variable<int>(positionMs);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['occurred_at'] = Variable<String>(occurredAt);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    return map;
  }

  WatchEventsCompanion toCompanion(bool nullToAbsent) {
    return WatchEventsCompanion(
      id: Value(id),
      assetId: Value(assetId),
      kind: Value(kind),
      positionMs: Value(positionMs),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      occurredAt: Value(occurredAt),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
    );
  }

  factory WatchEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WatchEventRow(
      id: serializer.fromJson<String>(json['id']),
      assetId: serializer.fromJson<String>(json['assetId']),
      kind: serializer.fromJson<String>(json['kind']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      payload: serializer.fromJson<String?>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'assetId': serializer.toJson<String>(assetId),
      'kind': serializer.toJson<String>(kind),
      'positionMs': serializer.toJson<int>(positionMs),
      'durationMs': serializer.toJson<int?>(durationMs),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'payload': serializer.toJson<String?>(payload),
    };
  }

  WatchEventRow copyWith({
    String? id,
    String? assetId,
    String? kind,
    int? positionMs,
    Value<int?> durationMs = const Value.absent(),
    String? occurredAt,
    Value<String?> payload = const Value.absent(),
  }) => WatchEventRow(
    id: id ?? this.id,
    assetId: assetId ?? this.assetId,
    kind: kind ?? this.kind,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    occurredAt: occurredAt ?? this.occurredAt,
    payload: payload.present ? payload.value : this.payload,
  );
  WatchEventRow copyWithCompanion(WatchEventsCompanion data) {
    return WatchEventRow(
      id: data.id.present ? data.id.value : this.id,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      kind: data.kind.present ? data.kind.value : this.kind,
      positionMs: data.positionMs.present
          ? data.positionMs.value
          : this.positionMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WatchEventRow(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('kind: $kind, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    assetId,
    kind,
    positionMs,
    durationMs,
    occurredAt,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WatchEventRow &&
          other.id == this.id &&
          other.assetId == this.assetId &&
          other.kind == this.kind &&
          other.positionMs == this.positionMs &&
          other.durationMs == this.durationMs &&
          other.occurredAt == this.occurredAt &&
          other.payload == this.payload);
}

class WatchEventsCompanion extends UpdateCompanion<WatchEventRow> {
  final Value<String> id;
  final Value<String> assetId;
  final Value<String> kind;
  final Value<int> positionMs;
  final Value<int?> durationMs;
  final Value<String> occurredAt;
  final Value<String?> payload;
  final Value<int> rowid;
  const WatchEventsCompanion({
    this.id = const Value.absent(),
    this.assetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WatchEventsCompanion.insert({
    required String id,
    required String assetId,
    required String kind,
    required int positionMs,
    this.durationMs = const Value.absent(),
    required String occurredAt,
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       assetId = Value(assetId),
       kind = Value(kind),
       positionMs = Value(positionMs),
       occurredAt = Value(occurredAt);
  static Insertable<WatchEventRow> custom({
    Expression<String>? id,
    Expression<String>? assetId,
    Expression<String>? kind,
    Expression<int>? positionMs,
    Expression<int>? durationMs,
    Expression<String>? occurredAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (assetId != null) 'asset_id': assetId,
      if (kind != null) 'kind': kind,
      if (positionMs != null) 'position_ms': positionMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WatchEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? assetId,
    Value<String>? kind,
    Value<int>? positionMs,
    Value<int?>? durationMs,
    Value<String>? occurredAt,
    Value<String?>? payload,
    Value<int>? rowid,
  }) {
    return WatchEventsCompanion(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      kind: kind ?? this.kind,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      occurredAt: occurredAt ?? this.occurredAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WatchEventsCompanion(')
          ..write('id: $id, ')
          ..write('assetId: $assetId, ')
          ..write('kind: $kind, ')
          ..write('positionMs: $positionMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentRunsTable extends AgentRuns
    with TableInfo<$AgentRunsTable, AgentRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
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
    requiredDuringInsert: false,
    defaultValue: const Constant('planned'),
  );
  static const VerificationMeta _planJsonMeta = const VerificationMeta(
    'planJson',
  );
  @override
  late final GeneratedColumn<String> planJson = GeneratedColumn<String>(
    'plan_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewJsonMeta = const VerificationMeta(
    'previewJson',
  );
  @override
  late final GeneratedColumn<String> previewJson = GeneratedColumn<String>(
    'preview_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operation,
    status,
    planJson,
    previewJson,
    resultJson,
    error,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('plan_json')) {
      context.handle(
        _planJsonMeta,
        planJson.isAcceptableOrUnknown(data['plan_json']!, _planJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_planJsonMeta);
    }
    if (data.containsKey('preview_json')) {
      context.handle(
        _previewJsonMeta,
        previewJson.isAcceptableOrUnknown(
          data['preview_json']!,
          _previewJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previewJsonMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
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
  AgentRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      planJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_json'],
      )!,
      previewJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_json'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AgentRunsTable createAlias(String alias) {
    return $AgentRunsTable(attachedDatabase, alias);
  }
}

class AgentRunRow extends DataClass implements Insertable<AgentRunRow> {
  final String id;
  final String operation;
  final String status;
  final String planJson;
  final String previewJson;
  final String? resultJson;
  final String? error;
  final String createdAt;
  final String updatedAt;
  const AgentRunRow({
    required this.id,
    required this.operation,
    required this.status,
    required this.planJson,
    required this.previewJson,
    this.resultJson,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation'] = Variable<String>(operation);
    map['status'] = Variable<String>(status);
    map['plan_json'] = Variable<String>(planJson);
    map['preview_json'] = Variable<String>(previewJson);
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AgentRunsCompanion toCompanion(bool nullToAbsent) {
    return AgentRunsCompanion(
      id: Value(id),
      operation: Value(operation),
      status: Value(status),
      planJson: Value(planJson),
      previewJson: Value(previewJson),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AgentRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentRunRow(
      id: serializer.fromJson<String>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      status: serializer.fromJson<String>(json['status']),
      planJson: serializer.fromJson<String>(json['planJson']),
      previewJson: serializer.fromJson<String>(json['previewJson']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      error: serializer.fromJson<String?>(json['error']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operation': serializer.toJson<String>(operation),
      'status': serializer.toJson<String>(status),
      'planJson': serializer.toJson<String>(planJson),
      'previewJson': serializer.toJson<String>(previewJson),
      'resultJson': serializer.toJson<String?>(resultJson),
      'error': serializer.toJson<String?>(error),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  AgentRunRow copyWith({
    String? id,
    String? operation,
    String? status,
    String? planJson,
    String? previewJson,
    Value<String?> resultJson = const Value.absent(),
    Value<String?> error = const Value.absent(),
    String? createdAt,
    String? updatedAt,
  }) => AgentRunRow(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    status: status ?? this.status,
    planJson: planJson ?? this.planJson,
    previewJson: previewJson ?? this.previewJson,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    error: error.present ? error.value : this.error,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AgentRunRow copyWithCompanion(AgentRunsCompanion data) {
    return AgentRunRow(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      status: data.status.present ? data.status.value : this.status,
      planJson: data.planJson.present ? data.planJson.value : this.planJson,
      previewJson: data.previewJson.present
          ? data.previewJson.value
          : this.previewJson,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      error: data.error.present ? data.error.value : this.error,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunRow(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('status: $status, ')
          ..write('planJson: $planJson, ')
          ..write('previewJson: $previewJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operation,
    status,
    planJson,
    previewJson,
    resultJson,
    error,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentRunRow &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.status == this.status &&
          other.planJson == this.planJson &&
          other.previewJson == this.previewJson &&
          other.resultJson == this.resultJson &&
          other.error == this.error &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AgentRunsCompanion extends UpdateCompanion<AgentRunRow> {
  final Value<String> id;
  final Value<String> operation;
  final Value<String> status;
  final Value<String> planJson;
  final Value<String> previewJson;
  final Value<String?> resultJson;
  final Value<String?> error;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AgentRunsCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.status = const Value.absent(),
    this.planJson = const Value.absent(),
    this.previewJson = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentRunsCompanion.insert({
    required String id,
    required String operation,
    this.status = const Value.absent(),
    required String planJson,
    required String previewJson,
    this.resultJson = const Value.absent(),
    this.error = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       operation = Value(operation),
       planJson = Value(planJson),
       previewJson = Value(previewJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AgentRunRow> custom({
    Expression<String>? id,
    Expression<String>? operation,
    Expression<String>? status,
    Expression<String>? planJson,
    Expression<String>? previewJson,
    Expression<String>? resultJson,
    Expression<String>? error,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (status != null) 'status': status,
      if (planJson != null) 'plan_json': planJson,
      if (previewJson != null) 'preview_json': previewJson,
      if (resultJson != null) 'result_json': resultJson,
      if (error != null) 'error': error,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? operation,
    Value<String>? status,
    Value<String>? planJson,
    Value<String>? previewJson,
    Value<String?>? resultJson,
    Value<String?>? error,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return AgentRunsCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      status: status ?? this.status,
      planJson: planJson ?? this.planJson,
      previewJson: previewJson ?? this.previewJson,
      resultJson: resultJson ?? this.resultJson,
      error: error ?? this.error,
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
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (planJson.present) {
      map['plan_json'] = Variable<String>(planJson.value);
    }
    if (previewJson.present) {
      map['preview_json'] = Variable<String>(previewJson.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunsCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('status: $status, ')
          ..write('planJson: $planJson, ')
          ..write('previewJson: $previewJson, ')
          ..write('resultJson: $resultJson, ')
          ..write('error: $error, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SmartCollectionsTable extends SmartCollections
    with TableInfo<$SmartCollectionsTable, SmartCollectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmartCollectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaIdsJsonMeta = const VerificationMeta(
    'mediaIdsJson',
  );
  @override
  late final GeneratedColumn<String> mediaIdsJson = GeneratedColumn<String>(
    'media_ids_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    query,
    mediaIdsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'smart_collections';
  @override
  VerificationContext validateIntegrity(
    Insertable<SmartCollectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('media_ids_json')) {
      context.handle(
        _mediaIdsJsonMeta,
        mediaIdsJson.isAcceptableOrUnknown(
          data['media_ids_json']!,
          _mediaIdsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mediaIdsJsonMeta);
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
  SmartCollectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmartCollectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      query: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}query'],
      )!,
      mediaIdsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_ids_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SmartCollectionsTable createAlias(String alias) {
    return $SmartCollectionsTable(attachedDatabase, alias);
  }
}

class SmartCollectionRow extends DataClass
    implements Insertable<SmartCollectionRow> {
  final String id;
  final String name;
  final String query;
  final String mediaIdsJson;
  final String createdAt;
  final String updatedAt;
  const SmartCollectionRow({
    required this.id,
    required this.name,
    required this.query,
    required this.mediaIdsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['query'] = Variable<String>(query);
    map['media_ids_json'] = Variable<String>(mediaIdsJson);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  SmartCollectionsCompanion toCompanion(bool nullToAbsent) {
    return SmartCollectionsCompanion(
      id: Value(id),
      name: Value(name),
      query: Value(query),
      mediaIdsJson: Value(mediaIdsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SmartCollectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmartCollectionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      query: serializer.fromJson<String>(json['query']),
      mediaIdsJson: serializer.fromJson<String>(json['mediaIdsJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'query': serializer.toJson<String>(query),
      'mediaIdsJson': serializer.toJson<String>(mediaIdsJson),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  SmartCollectionRow copyWith({
    String? id,
    String? name,
    String? query,
    String? mediaIdsJson,
    String? createdAt,
    String? updatedAt,
  }) => SmartCollectionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    query: query ?? this.query,
    mediaIdsJson: mediaIdsJson ?? this.mediaIdsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SmartCollectionRow copyWithCompanion(SmartCollectionsCompanion data) {
    return SmartCollectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      query: data.query.present ? data.query.value : this.query,
      mediaIdsJson: data.mediaIdsJson.present
          ? data.mediaIdsJson.value
          : this.mediaIdsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmartCollectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('query: $query, ')
          ..write('mediaIdsJson: $mediaIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, query, mediaIdsJson, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmartCollectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.query == this.query &&
          other.mediaIdsJson == this.mediaIdsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SmartCollectionsCompanion extends UpdateCompanion<SmartCollectionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> query;
  final Value<String> mediaIdsJson;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const SmartCollectionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.query = const Value.absent(),
    this.mediaIdsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SmartCollectionsCompanion.insert({
    required String id,
    required String name,
    required String query,
    required String mediaIdsJson,
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       query = Value(query),
       mediaIdsJson = Value(mediaIdsJson),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SmartCollectionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? query,
    Expression<String>? mediaIdsJson,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (query != null) 'query': query,
      if (mediaIdsJson != null) 'media_ids_json': mediaIdsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SmartCollectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? query,
    Value<String>? mediaIdsJson,
    Value<String>? createdAt,
    Value<String>? updatedAt,
    Value<int>? rowid,
  }) {
    return SmartCollectionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      query: query ?? this.query,
      mediaIdsJson: mediaIdsJson ?? this.mediaIdsJson,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (mediaIdsJson.present) {
      map['media_ids_json'] = Variable<String>(mediaIdsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmartCollectionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('query: $query, ')
          ..write('mediaIdsJson: $mediaIdsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$IntelligenceDatabase extends GeneratedDatabase {
  _$IntelligenceDatabase(QueryExecutor e) : super(e);
  $IntelligenceDatabaseManager get managers =>
      $IntelligenceDatabaseManager(this);
  late final $IntelligenceAssetsTable intelligenceAssets =
      $IntelligenceAssetsTable(this);
  late final $AiJobsTable aiJobs = $AiJobsTable(this);
  late final $TranscriptSegmentsTable transcriptSegments =
      $TranscriptSegmentsTable(this);
  late final $ContentSegmentsTable contentSegments = $ContentSegmentsTable(
    this,
  );
  late final $EmbeddingItemsTable embeddingItems = $EmbeddingItemsTable(this);
  late final $WatchEventsTable watchEvents = $WatchEventsTable(this);
  late final $AgentRunsTable agentRuns = $AgentRunsTable(this);
  late final $SmartCollectionsTable smartCollections = $SmartCollectionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    intelligenceAssets,
    aiJobs,
    transcriptSegments,
    contentSegments,
    embeddingItems,
    watchEvents,
    agentRuns,
    smartCollections,
  ];
}

typedef $$IntelligenceAssetsTableCreateCompanionBuilder =
    IntelligenceAssetsCompanion Function({
      required String id,
      Value<String?> mediaId,
      Value<String?> episodeId,
      required String sourceScope,
      required String canonicalUri,
      required String identityKey,
      Value<String?> fileHash,
      Value<int?> fileSize,
      Value<int?> modifiedAt,
      Value<int?> durationMs,
      Value<String> status,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$IntelligenceAssetsTableUpdateCompanionBuilder =
    IntelligenceAssetsCompanion Function({
      Value<String> id,
      Value<String?> mediaId,
      Value<String?> episodeId,
      Value<String> sourceScope,
      Value<String> canonicalUri,
      Value<String> identityKey,
      Value<String?> fileHash,
      Value<int?> fileSize,
      Value<int?> modifiedAt,
      Value<int?> durationMs,
      Value<String> status,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$IntelligenceAssetsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $IntelligenceAssetsTable> {
  $$IntelligenceAssetsTableFilterComposer({
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

  ColumnFilters<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceScope => $composableBuilder(
    column: $table.sourceScope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IntelligenceAssetsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $IntelligenceAssetsTable> {
  $$IntelligenceAssetsTableOrderingComposer({
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

  ColumnOrderings<String> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceScope => $composableBuilder(
    column: $table.sourceScope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IntelligenceAssetsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $IntelligenceAssetsTable> {
  $$IntelligenceAssetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<String> get sourceScope => $composableBuilder(
    column: $table.sourceScope,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalUri => $composableBuilder(
    column: $table.canonicalUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$IntelligenceAssetsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $IntelligenceAssetsTable,
          IntelligenceAssetRow,
          $$IntelligenceAssetsTableFilterComposer,
          $$IntelligenceAssetsTableOrderingComposer,
          $$IntelligenceAssetsTableAnnotationComposer,
          $$IntelligenceAssetsTableCreateCompanionBuilder,
          $$IntelligenceAssetsTableUpdateCompanionBuilder,
          (
            IntelligenceAssetRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $IntelligenceAssetsTable,
              IntelligenceAssetRow
            >,
          ),
          IntelligenceAssetRow,
          PrefetchHooks Function()
        > {
  $$IntelligenceAssetsTableTableManager(
    _$IntelligenceDatabase db,
    $IntelligenceAssetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IntelligenceAssetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IntelligenceAssetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IntelligenceAssetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> mediaId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<String> sourceScope = const Value.absent(),
                Value<String> canonicalUri = const Value.absent(),
                Value<String> identityKey = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IntelligenceAssetsCompanion(
                id: id,
                mediaId: mediaId,
                episodeId: episodeId,
                sourceScope: sourceScope,
                canonicalUri: canonicalUri,
                identityKey: identityKey,
                fileHash: fileHash,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                durationMs: durationMs,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> mediaId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                required String sourceScope,
                required String canonicalUri,
                required String identityKey,
                Value<String?> fileHash = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => IntelligenceAssetsCompanion.insert(
                id: id,
                mediaId: mediaId,
                episodeId: episodeId,
                sourceScope: sourceScope,
                canonicalUri: canonicalUri,
                identityKey: identityKey,
                fileHash: fileHash,
                fileSize: fileSize,
                modifiedAt: modifiedAt,
                durationMs: durationMs,
                status: status,
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

typedef $$IntelligenceAssetsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $IntelligenceAssetsTable,
      IntelligenceAssetRow,
      $$IntelligenceAssetsTableFilterComposer,
      $$IntelligenceAssetsTableOrderingComposer,
      $$IntelligenceAssetsTableAnnotationComposer,
      $$IntelligenceAssetsTableCreateCompanionBuilder,
      $$IntelligenceAssetsTableUpdateCompanionBuilder,
      (
        IntelligenceAssetRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $IntelligenceAssetsTable,
          IntelligenceAssetRow
        >,
      ),
      IntelligenceAssetRow,
      PrefetchHooks Function()
    >;
typedef $$AiJobsTableCreateCompanionBuilder =
    AiJobsCompanion Function({
      required String id,
      required String assetId,
      required String type,
      required String model,
      Value<String> status,
      Value<double> progress,
      Value<int> attempts,
      Value<String?> checkpoint,
      Value<String?> error,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$AiJobsTableUpdateCompanionBuilder =
    AiJobsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<String> type,
      Value<String> model,
      Value<String> status,
      Value<double> progress,
      Value<int> attempts,
      Value<String?> checkpoint,
      Value<String?> error,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$AiJobsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $AiJobsTable> {
  $$AiJobsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiJobsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $AiJobsTable> {
  $$AiJobsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiJobsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $AiJobsTable> {
  $$AiJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get checkpoint => $composableBuilder(
    column: $table.checkpoint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiJobsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $AiJobsTable,
          AiJobRow,
          $$AiJobsTableFilterComposer,
          $$AiJobsTableOrderingComposer,
          $$AiJobsTableAnnotationComposer,
          $$AiJobsTableCreateCompanionBuilder,
          $$AiJobsTableUpdateCompanionBuilder,
          (
            AiJobRow,
            BaseReferences<_$IntelligenceDatabase, $AiJobsTable, AiJobRow>,
          ),
          AiJobRow,
          PrefetchHooks Function()
        > {
  $$AiJobsTableTableManager(_$IntelligenceDatabase db, $AiJobsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> checkpoint = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AiJobsCompanion(
                id: id,
                assetId: assetId,
                type: type,
                model: model,
                status: status,
                progress: progress,
                attempts: attempts,
                checkpoint: checkpoint,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required String type,
                required String model,
                Value<String> status = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> checkpoint = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AiJobsCompanion.insert(
                id: id,
                assetId: assetId,
                type: type,
                model: model,
                status: status,
                progress: progress,
                attempts: attempts,
                checkpoint: checkpoint,
                error: error,
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

typedef $$AiJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $AiJobsTable,
      AiJobRow,
      $$AiJobsTableFilterComposer,
      $$AiJobsTableOrderingComposer,
      $$AiJobsTableAnnotationComposer,
      $$AiJobsTableCreateCompanionBuilder,
      $$AiJobsTableUpdateCompanionBuilder,
      (
        AiJobRow,
        BaseReferences<_$IntelligenceDatabase, $AiJobsTable, AiJobRow>,
      ),
      AiJobRow,
      PrefetchHooks Function()
    >;
typedef $$TranscriptSegmentsTableCreateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      required String id,
      required String assetId,
      required int startMs,
      required int endMs,
      required String content,
      Value<String> language,
      Value<String?> translatedText,
      Value<double?> confidence,
      Value<String?> speaker,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$TranscriptSegmentsTableUpdateCompanionBuilder =
    TranscriptSegmentsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<int> startMs,
      Value<int> endMs,
      Value<String> content,
      Value<String> language,
      Value<String?> translatedText,
      Value<double?> confidence,
      Value<String?> speaker,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$TranscriptSegmentsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranscriptSegmentsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranscriptSegmentsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $TranscriptSegmentsTable> {
  $$TranscriptSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get speaker =>
      $composableBuilder(column: $table.speaker, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TranscriptSegmentsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow,
          $$TranscriptSegmentsTableFilterComposer,
          $$TranscriptSegmentsTableOrderingComposer,
          $$TranscriptSegmentsTableAnnotationComposer,
          $$TranscriptSegmentsTableCreateCompanionBuilder,
          $$TranscriptSegmentsTableUpdateCompanionBuilder,
          (
            TranscriptSegmentRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $TranscriptSegmentsTable,
              TranscriptSegmentRow
            >,
          ),
          TranscriptSegmentRow,
          PrefetchHooks Function()
        > {
  $$TranscriptSegmentsTableTableManager(
    _$IntelligenceDatabase db,
    $TranscriptSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranscriptSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranscriptSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranscriptSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> translatedText = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> speaker = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion(
                id: id,
                assetId: assetId,
                startMs: startMs,
                endMs: endMs,
                content: content,
                language: language,
                translatedText: translatedText,
                confidence: confidence,
                speaker: speaker,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required int startMs,
                required int endMs,
                required String content,
                Value<String> language = const Value.absent(),
                Value<String?> translatedText = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<String?> speaker = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TranscriptSegmentsCompanion.insert(
                id: id,
                assetId: assetId,
                startMs: startMs,
                endMs: endMs,
                content: content,
                language: language,
                translatedText: translatedText,
                confidence: confidence,
                speaker: speaker,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranscriptSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $TranscriptSegmentsTable,
      TranscriptSegmentRow,
      $$TranscriptSegmentsTableFilterComposer,
      $$TranscriptSegmentsTableOrderingComposer,
      $$TranscriptSegmentsTableAnnotationComposer,
      $$TranscriptSegmentsTableCreateCompanionBuilder,
      $$TranscriptSegmentsTableUpdateCompanionBuilder,
      (
        TranscriptSegmentRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $TranscriptSegmentsTable,
          TranscriptSegmentRow
        >,
      ),
      TranscriptSegmentRow,
      PrefetchHooks Function()
    >;
typedef $$ContentSegmentsTableCreateCompanionBuilder =
    ContentSegmentsCompanion Function({
      required String id,
      required String assetId,
      required int startMs,
      required int endMs,
      Value<String> title,
      Value<String> summary,
      Value<String?> peopleJson,
      Value<String?> placesJson,
      Value<String?> themesJson,
      Value<String?> screenshotPath,
      Value<String> searchText,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$ContentSegmentsTableUpdateCompanionBuilder =
    ContentSegmentsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<int> startMs,
      Value<int> endMs,
      Value<String> title,
      Value<String> summary,
      Value<String?> peopleJson,
      Value<String?> placesJson,
      Value<String?> themesJson,
      Value<String?> screenshotPath,
      Value<String> searchText,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$ContentSegmentsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $ContentSegmentsTable> {
  $$ContentSegmentsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peopleJson => $composableBuilder(
    column: $table.peopleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placesJson => $composableBuilder(
    column: $table.placesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themesJson => $composableBuilder(
    column: $table.themesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentSegmentsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $ContentSegmentsTable> {
  $$ContentSegmentsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMs => $composableBuilder(
    column: $table.startMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMs => $composableBuilder(
    column: $table.endMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peopleJson => $composableBuilder(
    column: $table.peopleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placesJson => $composableBuilder(
    column: $table.placesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themesJson => $composableBuilder(
    column: $table.themesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentSegmentsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $ContentSegmentsTable> {
  $$ContentSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get startMs =>
      $composableBuilder(column: $table.startMs, builder: (column) => column);

  GeneratedColumn<int> get endMs =>
      $composableBuilder(column: $table.endMs, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get peopleJson => $composableBuilder(
    column: $table.peopleJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get placesJson => $composableBuilder(
    column: $table.placesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themesJson => $composableBuilder(
    column: $table.themesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get screenshotPath => $composableBuilder(
    column: $table.screenshotPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get searchText => $composableBuilder(
    column: $table.searchText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ContentSegmentsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $ContentSegmentsTable,
          ContentSegmentRow,
          $$ContentSegmentsTableFilterComposer,
          $$ContentSegmentsTableOrderingComposer,
          $$ContentSegmentsTableAnnotationComposer,
          $$ContentSegmentsTableCreateCompanionBuilder,
          $$ContentSegmentsTableUpdateCompanionBuilder,
          (
            ContentSegmentRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $ContentSegmentsTable,
              ContentSegmentRow
            >,
          ),
          ContentSegmentRow,
          PrefetchHooks Function()
        > {
  $$ContentSegmentsTableTableManager(
    _$IntelligenceDatabase db,
    $ContentSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int> startMs = const Value.absent(),
                Value<int> endMs = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String?> peopleJson = const Value.absent(),
                Value<String?> placesJson = const Value.absent(),
                Value<String?> themesJson = const Value.absent(),
                Value<String?> screenshotPath = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentSegmentsCompanion(
                id: id,
                assetId: assetId,
                startMs: startMs,
                endMs: endMs,
                title: title,
                summary: summary,
                peopleJson: peopleJson,
                placesJson: placesJson,
                themesJson: themesJson,
                screenshotPath: screenshotPath,
                searchText: searchText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required int startMs,
                required int endMs,
                Value<String> title = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String?> peopleJson = const Value.absent(),
                Value<String?> placesJson = const Value.absent(),
                Value<String?> themesJson = const Value.absent(),
                Value<String?> screenshotPath = const Value.absent(),
                Value<String> searchText = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentSegmentsCompanion.insert(
                id: id,
                assetId: assetId,
                startMs: startMs,
                endMs: endMs,
                title: title,
                summary: summary,
                peopleJson: peopleJson,
                placesJson: placesJson,
                themesJson: themesJson,
                screenshotPath: screenshotPath,
                searchText: searchText,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $ContentSegmentsTable,
      ContentSegmentRow,
      $$ContentSegmentsTableFilterComposer,
      $$ContentSegmentsTableOrderingComposer,
      $$ContentSegmentsTableAnnotationComposer,
      $$ContentSegmentsTableCreateCompanionBuilder,
      $$ContentSegmentsTableUpdateCompanionBuilder,
      (
        ContentSegmentRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $ContentSegmentsTable,
          ContentSegmentRow
        >,
      ),
      ContentSegmentRow,
      PrefetchHooks Function()
    >;
typedef $$EmbeddingItemsTableCreateCompanionBuilder =
    EmbeddingItemsCompanion Function({
      required String id,
      required String assetId,
      required String segmentId,
      required String modality,
      required String model,
      required int dimensions,
      required Uint8List vector,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$EmbeddingItemsTableUpdateCompanionBuilder =
    EmbeddingItemsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<String> segmentId,
      Value<String> modality,
      Value<String> model,
      Value<int> dimensions,
      Value<Uint8List> vector,
      Value<String> createdAt,
      Value<int> rowid,
    });

class $$EmbeddingItemsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $EmbeddingItemsTable> {
  $$EmbeddingItemsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modality => $composableBuilder(
    column: $table.modality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingItemsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $EmbeddingItemsTable> {
  $$EmbeddingItemsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modality => $composableBuilder(
    column: $table.modality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingItemsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $EmbeddingItemsTable> {
  $$EmbeddingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get modality =>
      $composableBuilder(column: $table.modality, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get dimensions => $composableBuilder(
    column: $table.dimensions,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EmbeddingItemsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $EmbeddingItemsTable,
          EmbeddingItemRow,
          $$EmbeddingItemsTableFilterComposer,
          $$EmbeddingItemsTableOrderingComposer,
          $$EmbeddingItemsTableAnnotationComposer,
          $$EmbeddingItemsTableCreateCompanionBuilder,
          $$EmbeddingItemsTableUpdateCompanionBuilder,
          (
            EmbeddingItemRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $EmbeddingItemsTable,
              EmbeddingItemRow
            >,
          ),
          EmbeddingItemRow,
          PrefetchHooks Function()
        > {
  $$EmbeddingItemsTableTableManager(
    _$IntelligenceDatabase db,
    $EmbeddingItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> segmentId = const Value.absent(),
                Value<String> modality = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> dimensions = const Value.absent(),
                Value<Uint8List> vector = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingItemsCompanion(
                id: id,
                assetId: assetId,
                segmentId: segmentId,
                modality: modality,
                model: model,
                dimensions: dimensions,
                vector: vector,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required String segmentId,
                required String modality,
                required String model,
                required int dimensions,
                required Uint8List vector,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EmbeddingItemsCompanion.insert(
                id: id,
                assetId: assetId,
                segmentId: segmentId,
                modality: modality,
                model: model,
                dimensions: dimensions,
                vector: vector,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmbeddingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $EmbeddingItemsTable,
      EmbeddingItemRow,
      $$EmbeddingItemsTableFilterComposer,
      $$EmbeddingItemsTableOrderingComposer,
      $$EmbeddingItemsTableAnnotationComposer,
      $$EmbeddingItemsTableCreateCompanionBuilder,
      $$EmbeddingItemsTableUpdateCompanionBuilder,
      (
        EmbeddingItemRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $EmbeddingItemsTable,
          EmbeddingItemRow
        >,
      ),
      EmbeddingItemRow,
      PrefetchHooks Function()
    >;
typedef $$WatchEventsTableCreateCompanionBuilder =
    WatchEventsCompanion Function({
      required String id,
      required String assetId,
      required String kind,
      required int positionMs,
      Value<int?> durationMs,
      required String occurredAt,
      Value<String?> payload,
      Value<int> rowid,
    });
typedef $$WatchEventsTableUpdateCompanionBuilder =
    WatchEventsCompanion Function({
      Value<String> id,
      Value<String> assetId,
      Value<String> kind,
      Value<int> positionMs,
      Value<int?> durationMs,
      Value<String> occurredAt,
      Value<String?> payload,
      Value<int> rowid,
    });

class $$WatchEventsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $WatchEventsTable> {
  $$WatchEventsTableFilterComposer({
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

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WatchEventsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $WatchEventsTable> {
  $$WatchEventsTableOrderingComposer({
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

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WatchEventsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $WatchEventsTable> {
  $$WatchEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
    column: $table.positionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$WatchEventsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $WatchEventsTable,
          WatchEventRow,
          $$WatchEventsTableFilterComposer,
          $$WatchEventsTableOrderingComposer,
          $$WatchEventsTableAnnotationComposer,
          $$WatchEventsTableCreateCompanionBuilder,
          $$WatchEventsTableUpdateCompanionBuilder,
          (
            WatchEventRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $WatchEventsTable,
              WatchEventRow
            >,
          ),
          WatchEventRow,
          PrefetchHooks Function()
        > {
  $$WatchEventsTableTableManager(
    _$IntelligenceDatabase db,
    $WatchEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WatchEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WatchEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WatchEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> positionMs = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> occurredAt = const Value.absent(),
                Value<String?> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchEventsCompanion(
                id: id,
                assetId: assetId,
                kind: kind,
                positionMs: positionMs,
                durationMs: durationMs,
                occurredAt: occurredAt,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String assetId,
                required String kind,
                required int positionMs,
                Value<int?> durationMs = const Value.absent(),
                required String occurredAt,
                Value<String?> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WatchEventsCompanion.insert(
                id: id,
                assetId: assetId,
                kind: kind,
                positionMs: positionMs,
                durationMs: durationMs,
                occurredAt: occurredAt,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WatchEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $WatchEventsTable,
      WatchEventRow,
      $$WatchEventsTableFilterComposer,
      $$WatchEventsTableOrderingComposer,
      $$WatchEventsTableAnnotationComposer,
      $$WatchEventsTableCreateCompanionBuilder,
      $$WatchEventsTableUpdateCompanionBuilder,
      (
        WatchEventRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $WatchEventsTable,
          WatchEventRow
        >,
      ),
      WatchEventRow,
      PrefetchHooks Function()
    >;
typedef $$AgentRunsTableCreateCompanionBuilder =
    AgentRunsCompanion Function({
      required String id,
      required String operation,
      Value<String> status,
      required String planJson,
      required String previewJson,
      Value<String?> resultJson,
      Value<String?> error,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$AgentRunsTableUpdateCompanionBuilder =
    AgentRunsCompanion Function({
      Value<String> id,
      Value<String> operation,
      Value<String> status,
      Value<String> planJson,
      Value<String> previewJson,
      Value<String?> resultJson,
      Value<String?> error,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$AgentRunsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $AgentRunsTable> {
  $$AgentRunsTableFilterComposer({
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

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planJson => $composableBuilder(
    column: $table.planJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AgentRunsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $AgentRunsTable> {
  $$AgentRunsTableOrderingComposer({
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

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planJson => $composableBuilder(
    column: $table.planJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentRunsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $AgentRunsTable> {
  $$AgentRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get planJson =>
      $composableBuilder(column: $table.planJson, builder: (column) => column);

  GeneratedColumn<String> get previewJson => $composableBuilder(
    column: $table.previewJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AgentRunsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $AgentRunsTable,
          AgentRunRow,
          $$AgentRunsTableFilterComposer,
          $$AgentRunsTableOrderingComposer,
          $$AgentRunsTableAnnotationComposer,
          $$AgentRunsTableCreateCompanionBuilder,
          $$AgentRunsTableUpdateCompanionBuilder,
          (
            AgentRunRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $AgentRunsTable,
              AgentRunRow
            >,
          ),
          AgentRunRow,
          PrefetchHooks Function()
        > {
  $$AgentRunsTableTableManager(_$IntelligenceDatabase db, $AgentRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> planJson = const Value.absent(),
                Value<String> previewJson = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion(
                id: id,
                operation: operation,
                status: status,
                planJson: planJson,
                previewJson: previewJson,
                resultJson: resultJson,
                error: error,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String operation,
                Value<String> status = const Value.absent(),
                required String planJson,
                required String previewJson,
                Value<String?> resultJson = const Value.absent(),
                Value<String?> error = const Value.absent(),
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion.insert(
                id: id,
                operation: operation,
                status: status,
                planJson: planJson,
                previewJson: previewJson,
                resultJson: resultJson,
                error: error,
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

typedef $$AgentRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $AgentRunsTable,
      AgentRunRow,
      $$AgentRunsTableFilterComposer,
      $$AgentRunsTableOrderingComposer,
      $$AgentRunsTableAnnotationComposer,
      $$AgentRunsTableCreateCompanionBuilder,
      $$AgentRunsTableUpdateCompanionBuilder,
      (
        AgentRunRow,
        BaseReferences<_$IntelligenceDatabase, $AgentRunsTable, AgentRunRow>,
      ),
      AgentRunRow,
      PrefetchHooks Function()
    >;
typedef $$SmartCollectionsTableCreateCompanionBuilder =
    SmartCollectionsCompanion Function({
      required String id,
      required String name,
      required String query,
      required String mediaIdsJson,
      required String createdAt,
      required String updatedAt,
      Value<int> rowid,
    });
typedef $$SmartCollectionsTableUpdateCompanionBuilder =
    SmartCollectionsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> query,
      Value<String> mediaIdsJson,
      Value<String> createdAt,
      Value<String> updatedAt,
      Value<int> rowid,
    });

class $$SmartCollectionsTableFilterComposer
    extends Composer<_$IntelligenceDatabase, $SmartCollectionsTable> {
  $$SmartCollectionsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaIdsJson => $composableBuilder(
    column: $table.mediaIdsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SmartCollectionsTableOrderingComposer
    extends Composer<_$IntelligenceDatabase, $SmartCollectionsTable> {
  $$SmartCollectionsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaIdsJson => $composableBuilder(
    column: $table.mediaIdsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SmartCollectionsTableAnnotationComposer
    extends Composer<_$IntelligenceDatabase, $SmartCollectionsTable> {
  $$SmartCollectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get mediaIdsJson => $composableBuilder(
    column: $table.mediaIdsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SmartCollectionsTableTableManager
    extends
        RootTableManager<
          _$IntelligenceDatabase,
          $SmartCollectionsTable,
          SmartCollectionRow,
          $$SmartCollectionsTableFilterComposer,
          $$SmartCollectionsTableOrderingComposer,
          $$SmartCollectionsTableAnnotationComposer,
          $$SmartCollectionsTableCreateCompanionBuilder,
          $$SmartCollectionsTableUpdateCompanionBuilder,
          (
            SmartCollectionRow,
            BaseReferences<
              _$IntelligenceDatabase,
              $SmartCollectionsTable,
              SmartCollectionRow
            >,
          ),
          SmartCollectionRow,
          PrefetchHooks Function()
        > {
  $$SmartCollectionsTableTableManager(
    _$IntelligenceDatabase db,
    $SmartCollectionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmartCollectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmartCollectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmartCollectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> mediaIdsJson = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SmartCollectionsCompanion(
                id: id,
                name: name,
                query: query,
                mediaIdsJson: mediaIdsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String query,
                required String mediaIdsJson,
                required String createdAt,
                required String updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SmartCollectionsCompanion.insert(
                id: id,
                name: name,
                query: query,
                mediaIdsJson: mediaIdsJson,
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

typedef $$SmartCollectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$IntelligenceDatabase,
      $SmartCollectionsTable,
      SmartCollectionRow,
      $$SmartCollectionsTableFilterComposer,
      $$SmartCollectionsTableOrderingComposer,
      $$SmartCollectionsTableAnnotationComposer,
      $$SmartCollectionsTableCreateCompanionBuilder,
      $$SmartCollectionsTableUpdateCompanionBuilder,
      (
        SmartCollectionRow,
        BaseReferences<
          _$IntelligenceDatabase,
          $SmartCollectionsTable,
          SmartCollectionRow
        >,
      ),
      SmartCollectionRow,
      PrefetchHooks Function()
    >;

class $IntelligenceDatabaseManager {
  final _$IntelligenceDatabase _db;
  $IntelligenceDatabaseManager(this._db);
  $$IntelligenceAssetsTableTableManager get intelligenceAssets =>
      $$IntelligenceAssetsTableTableManager(_db, _db.intelligenceAssets);
  $$AiJobsTableTableManager get aiJobs =>
      $$AiJobsTableTableManager(_db, _db.aiJobs);
  $$TranscriptSegmentsTableTableManager get transcriptSegments =>
      $$TranscriptSegmentsTableTableManager(_db, _db.transcriptSegments);
  $$ContentSegmentsTableTableManager get contentSegments =>
      $$ContentSegmentsTableTableManager(_db, _db.contentSegments);
  $$EmbeddingItemsTableTableManager get embeddingItems =>
      $$EmbeddingItemsTableTableManager(_db, _db.embeddingItems);
  $$WatchEventsTableTableManager get watchEvents =>
      $$WatchEventsTableTableManager(_db, _db.watchEvents);
  $$AgentRunsTableTableManager get agentRuns =>
      $$AgentRunsTableTableManager(_db, _db.agentRuns);
  $$SmartCollectionsTableTableManager get smartCollections =>
      $$SmartCollectionsTableTableManager(_db, _db.smartCollections);
}
