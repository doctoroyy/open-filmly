import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/intelligence/agent_conversation_repository.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/agent_run_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_asset_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/intelligence_search_repository.dart';
import 'package:open_filmly/data/intelligence/smart_collection_repository.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/data/repositories/playback_progress_repository.dart';
import 'package:open_filmly/services/intelligence/agent_conversation_service.dart';
import 'package:open_filmly/services/intelligence/agent_tools.dart';
import 'package:open_filmly/services/intelligence/content_segment_service.dart';
import 'package:open_filmly/services/intelligence/library_intelligence_indexer.dart';
import 'package:open_filmly/services/intelligence/local_embedding_service.dart';
import 'package:open_filmly/services/intelligence/local_rule_agent_planner.dart';
import 'package:open_filmly/services/intelligence/media_agent_service.dart';
import 'package:open_filmly/services/intelligence/media_identity_service.dart';
import 'package:open_filmly/services/intelligence/offline_media_agent_engine.dart';
import 'package:open_filmly/services/intelligence/semantic_search_service.dart';
import 'package:open_filmly/services/intelligence/subtitle_ingest_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

/// Practical Media Agent suite: real fixture library + shipped tools/planner
/// /offline engine / plan lifecycle / durable conversation — no mocked unit SUT.
void main() {
  late AppDatabase core;
  late IntelligenceDatabase intelligence;
  late MediaRepository mediaRepository;
  late PlaybackProgressRepository progressRepository;
  late Directory fixtureDir;
  late File videoWithSub;
  late File videoNoSub;

  setUp(() async {
    core = AppDatabase(NativeDatabase.memory());
    intelligence = IntelligenceDatabase.inMemory();
    mediaRepository = MediaRepository(core);
    progressRepository = PlaybackProgressRepository(core);
    fixtureDir = await Directory.systemTemp.createTemp('filmly-agent-practical-');
    videoWithSub = File('${fixtureDir.path}/Rain.Night.mkv');
    await videoWithSub.writeAsString('video');
    await File('${fixtureDir.path}/Rain.Night.chs.srt').writeAsString('''
1
00:00:01,000 --> 00:00:03,000
他在雨夜的长安城门等待
''');
    videoNoSub = File('${fixtureDir.path}/Silent.Movie.720p.mkv');
    await videoNoSub.writeAsString('video');

    await mediaRepository.upsert(
      Media(
        id: videoWithSub.path,
        title: '雨夜长安',
        year: '2022',
        type: MediaType.movie,
        path: videoWithSub.path,
        fullPath: videoWithSub.path,
        fileHash: 'hash-rain',
        posterPath: '/posters/rain.jpg',
        rating: '8.2',
        overview: '长安雨夜故事',
        genres: const ['悬疑', '古装'],
        detailsJson: '{"genres":["悬疑","古装"]}',
        dateAdded: '2020-01-01T00:00:00.000Z',
      ),
    );
    await mediaRepository.upsert(
      Media(
        id: videoNoSub.path,
        title: 'Silent 720p',
        year: '2021',
        type: MediaType.movie,
        path: videoNoSub.path,
        fullPath: videoNoSub.path,
        fileHash: 'hash-silent',
        detailsJson: '{"genres":["Sci-Fi"]}',
        dateAdded: '2020-01-01T00:00:00.000Z',
      ),
    );
    await mediaRepository.upsert(
      const Media(
        id: 'dup-a',
        title: 'Duplicate A',
        year: '2020',
        type: MediaType.movie,
        path: '/Movies/dup-a.mkv',
        fileHash: 'same-dup',
        detailsJson: '{"genres":["Action"]}',
      ),
    );
    await mediaRepository.upsert(
      const Media(
        id: 'dup-b',
        title: 'Duplicate B',
        year: '2020',
        type: MediaType.movie,
        path: '/Movies/dup-b.mkv',
        fileHash: 'same-dup',
        detailsJson: '{"genres":["Action"]}',
      ),
    );
  });

  tearDown(() async {
    await core.close();
    await intelligence.close();
    if (await fixtureDir.exists()) {
      await fixtureDir.delete(recursive: true);
    }
  });

  test('AgentTools returns grounded stats, health, duplicates, missingSubtitles',
      () async {
    final stats = await AgentTools.execute(
      name: 'get_library_stats',
      arguments: const {},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
    );
    expect(stats['totalCount'], 4);
    expect(stats['movieCount'], 4);
    expect(stats['unwatchedCount'], 4);

    final health = await AgentTools.execute(
      name: 'inspect_metadata_health',
      arguments: const {},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
    );
    expect(health['totalChecked'], 4);
    expect(health['missingPosterCount'], greaterThan(0));
    expect(health['missingOverviewCount'], greaterThan(0));
    expect(health['samples'], isA<List>());

    final duplicates = await AgentTools.execute(
      name: 'inspect_media_issues',
      arguments: const {'issueType': 'duplicates'},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
    );
    expect(duplicates['foundCount'], 2);

    final missingSubs = await AgentTools.execute(
      name: 'inspect_media_issues',
      arguments: const {'issueType': 'missingSubtitles'},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
    );
    expect(missingSubs['foundCount'], greaterThanOrEqualTo(1));
    final titles = (missingSubs['items'] as List)
        .map((item) => (item as Map)['title'])
        .toList();
    expect(titles, contains('Silent 720p'));
  });

  test('dialogue search works after real sidecar index; intelligence status is honest',
      () async {
    final transcripts = TranscriptService(intelligence);
    final assets = IntelligenceAssetRepository(intelligence);
    final indexer = LibraryIntelligenceIndexer(
      mediaRepository: mediaRepository,
      assets: assets,
      transcripts: transcripts,
      ingest: SubtitleIngestService(transcripts),
      contentSegments: ContentSegmentService(intelligence, transcripts),
      embeddings: LocalEmbeddingService(intelligence, transcripts),
    );
    await indexer.indexMedia(
      (await mediaRepository.getById(videoWithSub.path))!,
    );

    final semantic = SemanticSearchService(
      mediaRepository: mediaRepository,
      assets: assets,
      transcriptSearch: IntelligenceSearchRepository(intelligence),
      transcripts: transcripts,
      contentSegments: ContentSegmentService(intelligence, transcripts),
      embeddings: LocalEmbeddingService(intelligence, transcripts),
    );

    final scenes = await AgentTools.execute(
      name: 'search_dialogue_scenes',
      arguments: const {'query': '雨夜长安'},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      semanticSearch: semantic,
    );
    expect(scenes['count'], greaterThan(0));
    final first = (scenes['scenes'] as List).first as Map;
    expect(first['snippet']?.toString(), contains('雨夜'));
    expect(first['startMs'], isNotNull);

    final status = await AgentTools.execute(
      name: 'get_intelligence_status',
      arguments: const {},
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      intelligenceIndexer: indexer,
    );
    expect(status['libraryItems'], 4);
    expect(status['assetsWithTranscripts'], greaterThan(0));
  });

  test('offline engine answers stats and builds confirmable duplicate plan',
      () async {
    final agentService = MediaAgentService(
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      runs: AgentRunRepository(intelligence),
      collections: SmartCollectionRepository(intelligence),
      planner: const LocalRuleAgentPlanner(),
    );
    final offline = OfflineMediaAgentEngine(
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      agentService: agentService,
    );

    final statsTurn = await offline.tryHandle('影视库统计一下');
    expect(statsTurn, isNotNull);
    expect(statsTurn!.toolsUsed, contains('get_library_stats'));
    expect(statsTurn.replyText, contains('总计 4'));

    final planTurn = await offline.tryHandle('帮我查重复文件');
    expect(planTurn, isNotNull);
    expect(planTurn!.plan, isNotNull);
    expect(planTurn.plan!.operation, MediaAgentOperation.findDuplicates);
    expect(planTurn.plan!.preview.length, greaterThanOrEqualTo(2));

    // Safety: execute without confirm fails.
    expect(
      () => agentService.execute(planTurn.plan!.id),
      throwsA(isA<StateError>()),
    );
    await agentService.confirm(planTurn.plan!.id);
    final done = await agentService.execute(planTurn.plan!.id);
    expect(done.status, MediaAgentRunStatus.succeeded);
    // Report-only ops do not touch media files on disk.
    expect(await videoWithSub.exists(), isTrue);
  });

  test('conversation durability links plan and reloads after fresh service',
      () async {
    final runs = AgentRunRepository(intelligence);
    final conversations = AgentConversationRepository(intelligence);
    final agentService = MediaAgentService(
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      runs: runs,
      collections: SmartCollectionRepository(intelligence),
      planner: const LocalRuleAgentPlanner(),
    );
    final offline = OfflineMediaAgentEngine(
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      agentService: agentService,
    );

    final service = AgentConversationService(
      conversations: conversations,
      runs: runs,
      responder: ({required userPrompt, required context}) async {
        final result = await offline.tryHandle(userPrompt);
        if (result == null) {
          throw StateError('offline engine missed: $userPrompt');
        }
        return result;
      },
    );

    final turn = await service.send(text: '查找重复媒体');
    expect(turn.responseMessage.planId, isNotNull);
    expect(turn.responseMessage.toolsUsed, isNotEmpty);

    // Fresh service instance (simulates relaunch).
    final reloaded = AgentConversationService(
      conversations: AgentConversationRepository(intelligence),
      runs: AgentRunRepository(intelligence),
      responder: ({required userPrompt, required context}) async {
        throw StateError('should not call provider on reload');
      },
    );
    final messages = await reloaded.listMessages(turn.conversation.id);
    expect(messages.length, greaterThanOrEqualTo(2));
    expect(messages.last.planId, turn.responseMessage.planId);

    final plan = await runs.getById(turn.responseMessage.planId!);
    expect(plan?.conversationId, turn.conversation.id);
    expect(plan?.status, MediaAgentRunStatus.planned);
  });

  test('LocalRuleAgentPlanner refuses silent delete mapping', () async {
    const planner = LocalRuleAgentPlanner();
    final intent = await planner.plan('删除所有重复文件');
    expect(intent.operation, MediaAgentOperation.findDuplicates);
  });

  test('smart collection plan can execute and undo without touching media files',
      () async {
    final collections = SmartCollectionRepository(intelligence);
    final service = MediaAgentService(
      mediaRepository: mediaRepository,
      progressRepository: progressRepository,
      runs: AgentRunRepository(intelligence),
      collections: collections,
      planner: const LocalRuleAgentPlanner(),
    );

    final plan = await service.planFromRequest('建一个悬疑智能合集');
    expect(plan.operation, MediaAgentOperation.smartCollection);
    await service.confirm(plan.id);
    final done = await service.execute(plan.id);
    expect(done.status, MediaAgentRunStatus.succeeded);
    final collectionId = done.result['collectionId']?.toString();
    expect(collectionId, isNotNull);
    expect(await collections.getById(collectionId!), isNotNull);

    final undone = await service.undo(plan.id);
    expect(undone.status, MediaAgentRunStatus.undone);
    expect(await collections.getById(collectionId), isNull);
    expect(await videoWithSub.exists(), isTrue);
  });
}
