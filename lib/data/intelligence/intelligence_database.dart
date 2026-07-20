import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'intelligence_tables.dart';

part 'intelligence_database.g.dart';

@DriftDatabase(
  tables: [
    IntelligenceAssets,
    AiJobs,
    TranscriptSegments,
    ContentSegments,
    EmbeddingItems,
    WatchEvents,
    AgentRuns,
    SmartCollections,
  ],
)
class IntelligenceDatabase extends _$IntelligenceDatabase {
  IntelligenceDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'open_filmly_intelligence'));

  IntelligenceDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS intelligence_fts USING fts5(
          segment_id UNINDEXED,
          asset_id UNINDEXED,
          start_ms UNINDEXED,
          end_ms UNINDEXED,
          content,
          translated_content,
          search_text
        )
      ''');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('''
          CREATE VIRTUAL TABLE IF NOT EXISTS intelligence_fts USING fts5(
            segment_id UNINDEXED,
            asset_id UNINDEXED,
            start_ms UNINDEXED,
            end_ms UNINDEXED,
            content,
            translated_content,
            search_text
          )
        ''');
      }
      if (from < 3) {
        await m.createTable(agentRuns);
        await m.createTable(smartCollections);
      }
    },
  );
}
