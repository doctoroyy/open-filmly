// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<String> year = GeneratedColumn<String>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullPathMeta = const VerificationMeta(
    'fullPath',
  );
  @override
  late final GeneratedColumn<String> fullPath = GeneratedColumn<String>(
    'full_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posterPathMeta = const VerificationMeta(
    'posterPath',
  );
  @override
  late final GeneratedColumn<String> posterPath = GeneratedColumn<String>(
    'poster_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<String> rating = GeneratedColumn<String>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<String> dateAdded = GeneratedColumn<String>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<String> lastUpdated = GeneratedColumn<String>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    year,
    type,
    path,
    fullPath,
    posterPath,
    rating,
    details,
    fileHash,
    dateAdded,
    lastUpdated,
    isFavorite,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('full_path')) {
      context.handle(
        _fullPathMeta,
        fullPath.isAcceptableOrUnknown(data['full_path']!, _fullPathMeta),
      );
    }
    if (data.containsKey('poster_path')) {
      context.handle(
        _posterPathMeta,
        posterPath.isAcceptableOrUnknown(data['poster_path']!, _posterPathMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fullPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_path'],
      ),
      posterPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}poster_path'],
      ),
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rating'],
      ),
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      ),
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_added'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_updated'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaRow extends DataClass implements Insertable<MediaRow> {
  final String id;
  final String title;
  final String year;
  final String type;
  final String path;
  final String? fullPath;
  final String? posterPath;
  final String? rating;
  final String? details;
  final String? fileHash;
  final String dateAdded;
  final String lastUpdated;
  final bool isFavorite;
  const MediaRow({
    required this.id,
    required this.title,
    required this.year,
    required this.type,
    required this.path,
    this.fullPath,
    this.posterPath,
    this.rating,
    this.details,
    this.fileHash,
    required this.dateAdded,
    required this.lastUpdated,
    required this.isFavorite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['year'] = Variable<String>(year);
    map['type'] = Variable<String>(type);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || fullPath != null) {
      map['full_path'] = Variable<String>(fullPath);
    }
    if (!nullToAbsent || posterPath != null) {
      map['poster_path'] = Variable<String>(posterPath);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<String>(rating);
    }
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    if (!nullToAbsent || fileHash != null) {
      map['file_hash'] = Variable<String>(fileHash);
    }
    map['date_added'] = Variable<String>(dateAdded);
    map['last_updated'] = Variable<String>(lastUpdated);
    map['is_favorite'] = Variable<bool>(isFavorite);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      title: Value(title),
      year: Value(year),
      type: Value(type),
      path: Value(path),
      fullPath: fullPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fullPath),
      posterPath: posterPath == null && nullToAbsent
          ? const Value.absent()
          : Value(posterPath),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      fileHash: fileHash == null && nullToAbsent
          ? const Value.absent()
          : Value(fileHash),
      dateAdded: Value(dateAdded),
      lastUpdated: Value(lastUpdated),
      isFavorite: Value(isFavorite),
    );
  }

  factory MediaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      year: serializer.fromJson<String>(json['year']),
      type: serializer.fromJson<String>(json['type']),
      path: serializer.fromJson<String>(json['path']),
      fullPath: serializer.fromJson<String?>(json['fullPath']),
      posterPath: serializer.fromJson<String?>(json['posterPath']),
      rating: serializer.fromJson<String?>(json['rating']),
      details: serializer.fromJson<String?>(json['details']),
      fileHash: serializer.fromJson<String?>(json['fileHash']),
      dateAdded: serializer.fromJson<String>(json['dateAdded']),
      lastUpdated: serializer.fromJson<String>(json['lastUpdated']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'year': serializer.toJson<String>(year),
      'type': serializer.toJson<String>(type),
      'path': serializer.toJson<String>(path),
      'fullPath': serializer.toJson<String?>(fullPath),
      'posterPath': serializer.toJson<String?>(posterPath),
      'rating': serializer.toJson<String?>(rating),
      'details': serializer.toJson<String?>(details),
      'fileHash': serializer.toJson<String?>(fileHash),
      'dateAdded': serializer.toJson<String>(dateAdded),
      'lastUpdated': serializer.toJson<String>(lastUpdated),
      'isFavorite': serializer.toJson<bool>(isFavorite),
    };
  }

  MediaRow copyWith({
    String? id,
    String? title,
    String? year,
    String? type,
    String? path,
    Value<String?> fullPath = const Value.absent(),
    Value<String?> posterPath = const Value.absent(),
    Value<String?> rating = const Value.absent(),
    Value<String?> details = const Value.absent(),
    Value<String?> fileHash = const Value.absent(),
    String? dateAdded,
    String? lastUpdated,
    bool? isFavorite,
  }) => MediaRow(
    id: id ?? this.id,
    title: title ?? this.title,
    year: year ?? this.year,
    type: type ?? this.type,
    path: path ?? this.path,
    fullPath: fullPath.present ? fullPath.value : this.fullPath,
    posterPath: posterPath.present ? posterPath.value : this.posterPath,
    rating: rating.present ? rating.value : this.rating,
    details: details.present ? details.value : this.details,
    fileHash: fileHash.present ? fileHash.value : this.fileHash,
    dateAdded: dateAdded ?? this.dateAdded,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    isFavorite: isFavorite ?? this.isFavorite,
  );
  MediaRow copyWithCompanion(MediaItemsCompanion data) {
    return MediaRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      year: data.year.present ? data.year.value : this.year,
      type: data.type.present ? data.type.value : this.type,
      path: data.path.present ? data.path.value : this.path,
      fullPath: data.fullPath.present ? data.fullPath.value : this.fullPath,
      posterPath: data.posterPath.present
          ? data.posterPath.value
          : this.posterPath,
      rating: data.rating.present ? data.rating.value : this.rating,
      details: data.details.present ? data.details.value : this.details,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('type: $type, ')
          ..write('path: $path, ')
          ..write('fullPath: $fullPath, ')
          ..write('posterPath: $posterPath, ')
          ..write('rating: $rating, ')
          ..write('details: $details, ')
          ..write('fileHash: $fileHash, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isFavorite: $isFavorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    year,
    type,
    path,
    fullPath,
    posterPath,
    rating,
    details,
    fileHash,
    dateAdded,
    lastUpdated,
    isFavorite,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.year == this.year &&
          other.type == this.type &&
          other.path == this.path &&
          other.fullPath == this.fullPath &&
          other.posterPath == this.posterPath &&
          other.rating == this.rating &&
          other.details == this.details &&
          other.fileHash == this.fileHash &&
          other.dateAdded == this.dateAdded &&
          other.lastUpdated == this.lastUpdated &&
          other.isFavorite == this.isFavorite);
}

class MediaItemsCompanion extends UpdateCompanion<MediaRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> year;
  final Value<String> type;
  final Value<String> path;
  final Value<String?> fullPath;
  final Value<String?> posterPath;
  final Value<String?> rating;
  final Value<String?> details;
  final Value<String?> fileHash;
  final Value<String> dateAdded;
  final Value<String> lastUpdated;
  final Value<bool> isFavorite;
  final Value<int> rowid;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.year = const Value.absent(),
    this.type = const Value.absent(),
    this.path = const Value.absent(),
    this.fullPath = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.rating = const Value.absent(),
    this.details = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    required String id,
    required String title,
    this.year = const Value.absent(),
    required String type,
    required String path,
    this.fullPath = const Value.absent(),
    this.posterPath = const Value.absent(),
    this.rating = const Value.absent(),
    this.details = const Value.absent(),
    this.fileHash = const Value.absent(),
    required String dateAdded,
    required String lastUpdated,
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       type = Value(type),
       path = Value(path),
       dateAdded = Value(dateAdded),
       lastUpdated = Value(lastUpdated);
  static Insertable<MediaRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? year,
    Expression<String>? type,
    Expression<String>? path,
    Expression<String>? fullPath,
    Expression<String>? posterPath,
    Expression<String>? rating,
    Expression<String>? details,
    Expression<String>? fileHash,
    Expression<String>? dateAdded,
    Expression<String>? lastUpdated,
    Expression<bool>? isFavorite,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (year != null) 'year': year,
      if (type != null) 'type': type,
      if (path != null) 'path': path,
      if (fullPath != null) 'full_path': fullPath,
      if (posterPath != null) 'poster_path': posterPath,
      if (rating != null) 'rating': rating,
      if (details != null) 'details': details,
      if (fileHash != null) 'file_hash': fileHash,
      if (dateAdded != null) 'date_added': dateAdded,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? year,
    Value<String>? type,
    Value<String>? path,
    Value<String?>? fullPath,
    Value<String?>? posterPath,
    Value<String?>? rating,
    Value<String?>? details,
    Value<String?>? fileHash,
    Value<String>? dateAdded,
    Value<String>? lastUpdated,
    Value<bool>? isFavorite,
    Value<int>? rowid,
  }) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      type: type ?? this.type,
      path: path ?? this.path,
      fullPath: fullPath ?? this.fullPath,
      posterPath: posterPath ?? this.posterPath,
      rating: rating ?? this.rating,
      details: details ?? this.details,
      fileHash: fileHash ?? this.fileHash,
      dateAdded: dateAdded ?? this.dateAdded,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFavorite: isFavorite ?? this.isFavorite,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (year.present) {
      map['year'] = Variable<String>(year.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fullPath.present) {
      map['full_path'] = Variable<String>(fullPath.value);
    }
    if (posterPath.present) {
      map['poster_path'] = Variable<String>(posterPath.value);
    }
    if (rating.present) {
      map['rating'] = Variable<String>(rating.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<String>(dateAdded.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<String>(lastUpdated.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('year: $year, ')
          ..write('type: $type, ')
          ..write('path: $path, ')
          ..write('fullPath: $fullPath, ')
          ..write('posterPath: $posterPath, ')
          ..write('rating: $rating, ')
          ..write('details: $details, ')
          ..write('fileHash: $fileHash, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EpisodesTable extends Episodes
    with TableInfo<$EpisodesTable, EpisodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _showIdMeta = const VerificationMeta('showId');
  @override
  late final GeneratedColumn<String> showId = GeneratedColumn<String>(
    'show_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES media (id)',
    ),
  );
  static const VerificationMeta _seasonNumberMeta = const VerificationMeta(
    'seasonNumber',
  );
  @override
  late final GeneratedColumn<int> seasonNumber = GeneratedColumn<int>(
    'season_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeNumberMeta = const VerificationMeta(
    'episodeNumber',
  );
  @override
  late final GeneratedColumn<int> episodeNumber = GeneratedColumn<int>(
    'episode_number',
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullPathMeta = const VerificationMeta(
    'fullPath',
  );
  @override
  late final GeneratedColumn<String> fullPath = GeneratedColumn<String>(
    'full_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateAddedMeta = const VerificationMeta(
    'dateAdded',
  );
  @override
  late final GeneratedColumn<String> dateAdded = GeneratedColumn<String>(
    'date_added',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    showId,
    seasonNumber,
    episodeNumber,
    title,
    path,
    fullPath,
    dateAdded,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<EpisodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('show_id')) {
      context.handle(
        _showIdMeta,
        showId.isAcceptableOrUnknown(data['show_id']!, _showIdMeta),
      );
    } else if (isInserting) {
      context.missing(_showIdMeta);
    }
    if (data.containsKey('season_number')) {
      context.handle(
        _seasonNumberMeta,
        seasonNumber.isAcceptableOrUnknown(
          data['season_number']!,
          _seasonNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seasonNumberMeta);
    }
    if (data.containsKey('episode_number')) {
      context.handle(
        _episodeNumberMeta,
        episodeNumber.isAcceptableOrUnknown(
          data['episode_number']!,
          _episodeNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_episodeNumberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('full_path')) {
      context.handle(
        _fullPathMeta,
        fullPath.isAcceptableOrUnknown(data['full_path']!, _fullPathMeta),
      );
    }
    if (data.containsKey('date_added')) {
      context.handle(
        _dateAddedMeta,
        dateAdded.isAcceptableOrUnknown(data['date_added']!, _dateAddedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateAddedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EpisodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EpisodeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      showId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}show_id'],
      )!,
      seasonNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}season_number'],
      )!,
      episodeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}episode_number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fullPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_path'],
      ),
      dateAdded: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_added'],
      )!,
    );
  }

  @override
  $EpisodesTable createAlias(String alias) {
    return $EpisodesTable(attachedDatabase, alias);
  }
}

class EpisodeRow extends DataClass implements Insertable<EpisodeRow> {
  final String id;
  final String showId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String path;
  final String? fullPath;
  final String dateAdded;
  const EpisodeRow({
    required this.id,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.path,
    this.fullPath,
    required this.dateAdded,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['show_id'] = Variable<String>(showId);
    map['season_number'] = Variable<int>(seasonNumber);
    map['episode_number'] = Variable<int>(episodeNumber);
    map['title'] = Variable<String>(title);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || fullPath != null) {
      map['full_path'] = Variable<String>(fullPath);
    }
    map['date_added'] = Variable<String>(dateAdded);
    return map;
  }

  EpisodesCompanion toCompanion(bool nullToAbsent) {
    return EpisodesCompanion(
      id: Value(id),
      showId: Value(showId),
      seasonNumber: Value(seasonNumber),
      episodeNumber: Value(episodeNumber),
      title: Value(title),
      path: Value(path),
      fullPath: fullPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fullPath),
      dateAdded: Value(dateAdded),
    );
  }

  factory EpisodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EpisodeRow(
      id: serializer.fromJson<String>(json['id']),
      showId: serializer.fromJson<String>(json['showId']),
      seasonNumber: serializer.fromJson<int>(json['seasonNumber']),
      episodeNumber: serializer.fromJson<int>(json['episodeNumber']),
      title: serializer.fromJson<String>(json['title']),
      path: serializer.fromJson<String>(json['path']),
      fullPath: serializer.fromJson<String?>(json['fullPath']),
      dateAdded: serializer.fromJson<String>(json['dateAdded']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'showId': serializer.toJson<String>(showId),
      'seasonNumber': serializer.toJson<int>(seasonNumber),
      'episodeNumber': serializer.toJson<int>(episodeNumber),
      'title': serializer.toJson<String>(title),
      'path': serializer.toJson<String>(path),
      'fullPath': serializer.toJson<String?>(fullPath),
      'dateAdded': serializer.toJson<String>(dateAdded),
    };
  }

  EpisodeRow copyWith({
    String? id,
    String? showId,
    int? seasonNumber,
    int? episodeNumber,
    String? title,
    String? path,
    Value<String?> fullPath = const Value.absent(),
    String? dateAdded,
  }) => EpisodeRow(
    id: id ?? this.id,
    showId: showId ?? this.showId,
    seasonNumber: seasonNumber ?? this.seasonNumber,
    episodeNumber: episodeNumber ?? this.episodeNumber,
    title: title ?? this.title,
    path: path ?? this.path,
    fullPath: fullPath.present ? fullPath.value : this.fullPath,
    dateAdded: dateAdded ?? this.dateAdded,
  );
  EpisodeRow copyWithCompanion(EpisodesCompanion data) {
    return EpisodeRow(
      id: data.id.present ? data.id.value : this.id,
      showId: data.showId.present ? data.showId.value : this.showId,
      seasonNumber: data.seasonNumber.present
          ? data.seasonNumber.value
          : this.seasonNumber,
      episodeNumber: data.episodeNumber.present
          ? data.episodeNumber.value
          : this.episodeNumber,
      title: data.title.present ? data.title.value : this.title,
      path: data.path.present ? data.path.value : this.path,
      fullPath: data.fullPath.present ? data.fullPath.value : this.fullPath,
      dateAdded: data.dateAdded.present ? data.dateAdded.value : this.dateAdded,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EpisodeRow(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('path: $path, ')
          ..write('fullPath: $fullPath, ')
          ..write('dateAdded: $dateAdded')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    showId,
    seasonNumber,
    episodeNumber,
    title,
    path,
    fullPath,
    dateAdded,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EpisodeRow &&
          other.id == this.id &&
          other.showId == this.showId &&
          other.seasonNumber == this.seasonNumber &&
          other.episodeNumber == this.episodeNumber &&
          other.title == this.title &&
          other.path == this.path &&
          other.fullPath == this.fullPath &&
          other.dateAdded == this.dateAdded);
}

class EpisodesCompanion extends UpdateCompanion<EpisodeRow> {
  final Value<String> id;
  final Value<String> showId;
  final Value<int> seasonNumber;
  final Value<int> episodeNumber;
  final Value<String> title;
  final Value<String> path;
  final Value<String?> fullPath;
  final Value<String> dateAdded;
  final Value<int> rowid;
  const EpisodesCompanion({
    this.id = const Value.absent(),
    this.showId = const Value.absent(),
    this.seasonNumber = const Value.absent(),
    this.episodeNumber = const Value.absent(),
    this.title = const Value.absent(),
    this.path = const Value.absent(),
    this.fullPath = const Value.absent(),
    this.dateAdded = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EpisodesCompanion.insert({
    required String id,
    required String showId,
    required int seasonNumber,
    required int episodeNumber,
    this.title = const Value.absent(),
    required String path,
    this.fullPath = const Value.absent(),
    required String dateAdded,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       showId = Value(showId),
       seasonNumber = Value(seasonNumber),
       episodeNumber = Value(episodeNumber),
       path = Value(path),
       dateAdded = Value(dateAdded);
  static Insertable<EpisodeRow> custom({
    Expression<String>? id,
    Expression<String>? showId,
    Expression<int>? seasonNumber,
    Expression<int>? episodeNumber,
    Expression<String>? title,
    Expression<String>? path,
    Expression<String>? fullPath,
    Expression<String>? dateAdded,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (showId != null) 'show_id': showId,
      if (seasonNumber != null) 'season_number': seasonNumber,
      if (episodeNumber != null) 'episode_number': episodeNumber,
      if (title != null) 'title': title,
      if (path != null) 'path': path,
      if (fullPath != null) 'full_path': fullPath,
      if (dateAdded != null) 'date_added': dateAdded,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EpisodesCompanion copyWith({
    Value<String>? id,
    Value<String>? showId,
    Value<int>? seasonNumber,
    Value<int>? episodeNumber,
    Value<String>? title,
    Value<String>? path,
    Value<String?>? fullPath,
    Value<String>? dateAdded,
    Value<int>? rowid,
  }) {
    return EpisodesCompanion(
      id: id ?? this.id,
      showId: showId ?? this.showId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      path: path ?? this.path,
      fullPath: fullPath ?? this.fullPath,
      dateAdded: dateAdded ?? this.dateAdded,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (showId.present) {
      map['show_id'] = Variable<String>(showId.value);
    }
    if (seasonNumber.present) {
      map['season_number'] = Variable<int>(seasonNumber.value);
    }
    if (episodeNumber.present) {
      map['episode_number'] = Variable<int>(episodeNumber.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fullPath.present) {
      map['full_path'] = Variable<String>(fullPath.value);
    }
    if (dateAdded.present) {
      map['date_added'] = Variable<String>(dateAdded.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EpisodesCompanion(')
          ..write('id: $id, ')
          ..write('showId: $showId, ')
          ..write('seasonNumber: $seasonNumber, ')
          ..write('episodeNumber: $episodeNumber, ')
          ..write('title: $title, ')
          ..write('path: $path, ')
          ..write('fullPath: $fullPath, ')
          ..write('dateAdded: $dateAdded, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConfigEntriesTable extends ConfigEntries
    with TableInfo<$ConfigEntriesTable, ConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfigEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'config';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfigRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  ConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfigRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $ConfigEntriesTable createAlias(String alias) {
    return $ConfigEntriesTable(attachedDatabase, alias);
  }
}

class ConfigRow extends DataClass implements Insertable<ConfigRow> {
  final String key;
  final String value;
  const ConfigRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  ConfigEntriesCompanion toCompanion(bool nullToAbsent) {
    return ConfigEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory ConfigRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfigRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  ConfigRow copyWith({String? key, String? value}) =>
      ConfigRow(key: key ?? this.key, value: value ?? this.value);
  ConfigRow copyWithCompanion(ConfigEntriesCompanion data) {
    return ConfigRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfigRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigRow &&
          other.key == this.key &&
          other.value == this.value);
}

class ConfigEntriesCompanion extends UpdateCompanion<ConfigRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const ConfigEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfigEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<ConfigRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfigEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return ConfigEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfigEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $EpisodesTable episodes = $EpisodesTable(this);
  late final $ConfigEntriesTable configEntries = $ConfigEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaItems,
    episodes,
    configEntries,
  ];
}

typedef $$MediaItemsTableCreateCompanionBuilder =
    MediaItemsCompanion Function({
      required String id,
      required String title,
      Value<String> year,
      required String type,
      required String path,
      Value<String?> fullPath,
      Value<String?> posterPath,
      Value<String?> rating,
      Value<String?> details,
      Value<String?> fileHash,
      required String dateAdded,
      required String lastUpdated,
      Value<bool> isFavorite,
      Value<int> rowid,
    });
typedef $$MediaItemsTableUpdateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> year,
      Value<String> type,
      Value<String> path,
      Value<String?> fullPath,
      Value<String?> posterPath,
      Value<String?> rating,
      Value<String?> details,
      Value<String?> fileHash,
      Value<String> dateAdded,
      Value<String> lastUpdated,
      Value<bool> isFavorite,
      Value<int> rowid,
    });

final class $$MediaItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaItemsTable, MediaRow> {
  $$MediaItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EpisodesTable, List<EpisodeRow>>
  _episodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.episodes,
    aliasName: $_aliasNameGenerator(db.mediaItems.id, db.episodes.showId),
  );

  $$EpisodesTableProcessedTableManager get episodesRefs {
    final manager = $$EpisodesTableTableManager(
      $_db,
      $_db.episodes,
    ).filter((f) => f.showId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_episodesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullPath => $composableBuilder(
    column: $table.fullPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> episodesRefs(
    Expression<bool> Function($$EpisodesTableFilterComposer f) f,
  ) {
    final $$EpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableFilterComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullPath => $composableBuilder(
    column: $table.fullPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fullPath =>
      $composableBuilder(column: $table.fullPath, builder: (column) => column);

  GeneratedColumn<String> get posterPath => $composableBuilder(
    column: $table.posterPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  GeneratedColumn<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  Expression<T> episodesRefs<T extends Object>(
    Expression<T> Function($$EpisodesTableAnnotationComposer a) f,
  ) {
    final $$EpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.episodes,
      getReferencedColumn: (t) => t.showId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.episodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaItemsTable,
          MediaRow,
          $$MediaItemsTableFilterComposer,
          $$MediaItemsTableOrderingComposer,
          $$MediaItemsTableAnnotationComposer,
          $$MediaItemsTableCreateCompanionBuilder,
          $$MediaItemsTableUpdateCompanionBuilder,
          (MediaRow, $$MediaItemsTableReferences),
          MediaRow,
          PrefetchHooks Function({bool episodesRefs})
        > {
  $$MediaItemsTableTableManager(_$AppDatabase db, $MediaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> year = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> fullPath = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                Value<String> dateAdded = const Value.absent(),
                Value<String> lastUpdated = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaItemsCompanion(
                id: id,
                title: title,
                year: year,
                type: type,
                path: path,
                fullPath: fullPath,
                posterPath: posterPath,
                rating: rating,
                details: details,
                fileHash: fileHash,
                dateAdded: dateAdded,
                lastUpdated: lastUpdated,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> year = const Value.absent(),
                required String type,
                required String path,
                Value<String?> fullPath = const Value.absent(),
                Value<String?> posterPath = const Value.absent(),
                Value<String?> rating = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<String?> fileHash = const Value.absent(),
                required String dateAdded,
                required String lastUpdated,
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaItemsCompanion.insert(
                id: id,
                title: title,
                year: year,
                type: type,
                path: path,
                fullPath: fullPath,
                posterPath: posterPath,
                rating: rating,
                details: details,
                fileHash: fileHash,
                dateAdded: dateAdded,
                lastUpdated: lastUpdated,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MediaItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({episodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (episodesRefs) db.episodes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (episodesRefs)
                    await $_getPrefetchedData<
                      MediaRow,
                      $MediaItemsTable,
                      EpisodeRow
                    >(
                      currentTable: table,
                      referencedTable: $$MediaItemsTableReferences
                          ._episodesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MediaItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).episodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.showId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaItemsTable,
      MediaRow,
      $$MediaItemsTableFilterComposer,
      $$MediaItemsTableOrderingComposer,
      $$MediaItemsTableAnnotationComposer,
      $$MediaItemsTableCreateCompanionBuilder,
      $$MediaItemsTableUpdateCompanionBuilder,
      (MediaRow, $$MediaItemsTableReferences),
      MediaRow,
      PrefetchHooks Function({bool episodesRefs})
    >;
typedef $$EpisodesTableCreateCompanionBuilder =
    EpisodesCompanion Function({
      required String id,
      required String showId,
      required int seasonNumber,
      required int episodeNumber,
      Value<String> title,
      required String path,
      Value<String?> fullPath,
      required String dateAdded,
      Value<int> rowid,
    });
typedef $$EpisodesTableUpdateCompanionBuilder =
    EpisodesCompanion Function({
      Value<String> id,
      Value<String> showId,
      Value<int> seasonNumber,
      Value<int> episodeNumber,
      Value<String> title,
      Value<String> path,
      Value<String?> fullPath,
      Value<String> dateAdded,
      Value<int> rowid,
    });

final class $$EpisodesTableReferences
    extends BaseReferences<_$AppDatabase, $EpisodesTable, EpisodeRow> {
  $$EpisodesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaItemsTable _showIdTable(_$AppDatabase db) => db.mediaItems
      .createAlias($_aliasNameGenerator(db.episodes.showId, db.mediaItems.id));

  $$MediaItemsTableProcessedTableManager get showId {
    final $_column = $_itemColumn<String>('show_id')!;

    final manager = $$MediaItemsTableTableManager(
      $_db,
      $_db.mediaItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_showIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableFilterComposer({
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

  ColumnFilters<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullPath => $composableBuilder(
    column: $table.fullPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnFilters(column),
  );

  $$MediaItemsTableFilterComposer get showId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableFilterComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableOrderingComposer({
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

  ColumnOrderings<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullPath => $composableBuilder(
    column: $table.fullPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateAdded => $composableBuilder(
    column: $table.dateAdded,
    builder: (column) => ColumnOrderings(column),
  );

  $$MediaItemsTableOrderingComposer get showId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableOrderingComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EpisodesTable> {
  $$EpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seasonNumber => $composableBuilder(
    column: $table.seasonNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get episodeNumber => $composableBuilder(
    column: $table.episodeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fullPath =>
      $composableBuilder(column: $table.fullPath, builder: (column) => column);

  GeneratedColumn<String> get dateAdded =>
      $composableBuilder(column: $table.dateAdded, builder: (column) => column);

  $$MediaItemsTableAnnotationComposer get showId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.showId,
      referencedTable: $db.mediaItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EpisodesTable,
          EpisodeRow,
          $$EpisodesTableFilterComposer,
          $$EpisodesTableOrderingComposer,
          $$EpisodesTableAnnotationComposer,
          $$EpisodesTableCreateCompanionBuilder,
          $$EpisodesTableUpdateCompanionBuilder,
          (EpisodeRow, $$EpisodesTableReferences),
          EpisodeRow,
          PrefetchHooks Function({bool showId})
        > {
  $$EpisodesTableTableManager(_$AppDatabase db, $EpisodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> showId = const Value.absent(),
                Value<int> seasonNumber = const Value.absent(),
                Value<int> episodeNumber = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> fullPath = const Value.absent(),
                Value<String> dateAdded = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion(
                id: id,
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                title: title,
                path: path,
                fullPath: fullPath,
                dateAdded: dateAdded,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String showId,
                required int seasonNumber,
                required int episodeNumber,
                Value<String> title = const Value.absent(),
                required String path,
                Value<String?> fullPath = const Value.absent(),
                required String dateAdded,
                Value<int> rowid = const Value.absent(),
              }) => EpisodesCompanion.insert(
                id: id,
                showId: showId,
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                title: title,
                path: path,
                fullPath: fullPath,
                dateAdded: dateAdded,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({showId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (showId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.showId,
                                referencedTable: $$EpisodesTableReferences
                                    ._showIdTable(db),
                                referencedColumn: $$EpisodesTableReferences
                                    ._showIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EpisodesTable,
      EpisodeRow,
      $$EpisodesTableFilterComposer,
      $$EpisodesTableOrderingComposer,
      $$EpisodesTableAnnotationComposer,
      $$EpisodesTableCreateCompanionBuilder,
      $$EpisodesTableUpdateCompanionBuilder,
      (EpisodeRow, $$EpisodesTableReferences),
      EpisodeRow,
      PrefetchHooks Function({bool showId})
    >;
typedef $$ConfigEntriesTableCreateCompanionBuilder =
    ConfigEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$ConfigEntriesTableUpdateCompanionBuilder =
    ConfigEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$ConfigEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ConfigEntriesTable> {
  $$ConfigEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConfigEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConfigEntriesTable> {
  $$ConfigEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfigEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConfigEntriesTable> {
  $$ConfigEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$ConfigEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConfigEntriesTable,
          ConfigRow,
          $$ConfigEntriesTableFilterComposer,
          $$ConfigEntriesTableOrderingComposer,
          $$ConfigEntriesTableAnnotationComposer,
          $$ConfigEntriesTableCreateCompanionBuilder,
          $$ConfigEntriesTableUpdateCompanionBuilder,
          (
            ConfigRow,
            BaseReferences<_$AppDatabase, $ConfigEntriesTable, ConfigRow>,
          ),
          ConfigRow,
          PrefetchHooks Function()
        > {
  $$ConfigEntriesTableTableManager(_$AppDatabase db, $ConfigEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfigEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfigEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConfigEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  ConfigEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => ConfigEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConfigEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConfigEntriesTable,
      ConfigRow,
      $$ConfigEntriesTableFilterComposer,
      $$ConfigEntriesTableOrderingComposer,
      $$ConfigEntriesTableAnnotationComposer,
      $$ConfigEntriesTableCreateCompanionBuilder,
      $$ConfigEntriesTableUpdateCompanionBuilder,
      (
        ConfigRow,
        BaseReferences<_$AppDatabase, $ConfigEntriesTable, ConfigRow>,
      ),
      ConfigRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$EpisodesTableTableManager get episodes =>
      $$EpisodesTableTableManager(_db, _db.episodes);
  $$ConfigEntriesTableTableManager get configEntries =>
      $$ConfigEntriesTableTableManager(_db, _db.configEntries);
}
