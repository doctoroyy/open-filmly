import 'package:drift/drift.dart';

@DataClassName('IntelligenceAssetRow')
class IntelligenceAssets extends Table {
  TextColumn get id => text()();
  TextColumn get mediaId => text().nullable()();
  TextColumn get episodeId => text().nullable()();
  TextColumn get sourceScope => text()();
  TextColumn get canonicalUri => text()();
  TextColumn get identityKey => text()();
  TextColumn get fileHash => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get modifiedAt => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AiJobRow')
class AiJobs extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  TextColumn get type => text()();
  TextColumn get model => text()();
  TextColumn get status => text().withDefault(const Constant('queued'))();
  RealColumn get progress => real().withDefault(const Constant(0))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get checkpoint => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TranscriptSegmentRow')
class TranscriptSegments extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get content => text()();
  TextColumn get language => text().withDefault(const Constant(''))();
  TextColumn get translatedText => text().nullable()();
  RealColumn get confidence => real().nullable()();
  TextColumn get speaker => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ContentSegmentRow')
class ContentSegments extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get peopleJson => text().nullable()();
  TextColumn get placesJson => text().nullable()();
  TextColumn get themesJson => text().nullable()();
  TextColumn get screenshotPath => text().nullable()();
  TextColumn get searchText => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EmbeddingItemRow')
class EmbeddingItems extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  TextColumn get segmentId => text()();
  TextColumn get modality => text()();
  TextColumn get model => text()();
  IntColumn get dimensions => integer()();
  BlobColumn get vector => blob()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WatchEventRow')
class WatchEvents extends Table {
  TextColumn get id => text()();
  TextColumn get assetId => text()();
  TextColumn get kind => text()();
  IntColumn get positionMs => integer()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get occurredAt => text()();
  TextColumn get payload => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A durable preview/confirmation/execution record for Media Agent actions.
/// Keeping this in the intelligence database means an interrupted or failed
/// automation can never corrupt the core media library database.
@DataClassName('AgentRunRow')
class AgentRuns extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get planJson => text()();
  TextColumn get previewJson => text()();
  TextColumn get resultJson => text().nullable()();
  TextColumn get error => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Smart collections are derived views, not copies of media rows.
@DataClassName('SmartCollectionRow')
class SmartCollections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get query => text()();
  TextColumn get mediaIdsJson => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
