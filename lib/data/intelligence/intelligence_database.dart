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
    AgentConversations,
    AgentConversationMessages,
  ],
)
class IntelligenceDatabase extends _$IntelligenceDatabase {
  IntelligenceDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'open_filmly_intelligence'));

  IntelligenceDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

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
      await _createConversationIndexes();
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
      if (from < 4) {
        await m.addColumn(agentRuns, agentRuns.conversationId);
        await m.createTable(agentConversations);
        await m.createTable(agentConversationMessages);
        await _createConversationIndexes();
      }
    },
  );

  Future<void> _createConversationIndexes() async {
    await customStatement('''
      CREATE INDEX IF NOT EXISTS agent_messages_conversation_sequence_idx
      ON agent_conversation_messages(conversation_id, sequence)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS agent_conversations_updated_idx
      ON agent_conversations(archived_at, pinned_at, updated_at DESC)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS agent_runs_conversation_idx
      ON agent_runs(conversation_id, updated_at DESC)
    ''');
  }
}
