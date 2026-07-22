import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/intelligence/agent_models.dart';
import 'package:open_filmly/data/intelligence/agent_run_repository.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/smart_collection_repository.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';
import 'package:open_filmly/data/repositories/playback_progress_repository.dart';
import 'package:open_filmly/services/intelligence/media_agent_service.dart';
import 'package:open_filmly/services/intelligence/agent_planner.dart';

void main() {
  test(
    'requires confirmation and can execute then undo subtitle generation',
    () async {
      final core = AppDatabase(NativeDatabase.memory());
      final intelligence = IntelligenceDatabase.inMemory();
      final output = await Directory.systemTemp.createTemp('filmly-agent-');
      addTearDown(core.close);
      addTearDown(intelligence.close);
      addTearDown(() => output.delete(recursive: true));

      final mediaRepository = MediaRepository(core);
      await mediaRepository.upsert(
        const Media(
          id: 'agent-movie',
          title: 'Agent Movie',
          year: '2026',
          type: MediaType.movie,
          path: '/Movies/Agent.Movie.720p.mp4',
          fileHash: 'hash-agent',
          detailsJson: '{"genres":["Sci-Fi"]}',
        ),
      );
      final generated = File('${output.path}/agent.srt');
      final service = MediaAgentService(
        mediaRepository: mediaRepository,
        progressRepository: PlaybackProgressRepository(core),
        runs: AgentRunRepository(intelligence),
        collections: SmartCollectionRepository(intelligence),
        subtitleGenerator: (media) async {
          await generated.writeAsString(
            '1\n00:00:00,000 --> 00:00:01,000\nHello\n',
          );
          return [generated.path];
        },
      );

      final plan = await service.plan(MediaAgentOperation.batchSubtitles);
      expect(plan.preview, hasLength(1));
      expect(() => service.execute(plan.id), throwsA(isA<StateError>()));

      await service.confirm(plan.id);
      final completed = await service.execute(plan.id);
      expect(completed.status, MediaAgentRunStatus.succeeded);
      expect(await generated.exists(), isTrue);

      final undone = await service.undo(plan.id);
      expect(undone.status, MediaAgentRunStatus.undone);
      expect(await generated.exists(), isFalse);
    },
  );

  test(
    'previews duplicates, low quality, unwatched media and smart collections',
    () async {
      final core = AppDatabase(NativeDatabase.memory());
      final intelligence = IntelligenceDatabase.inMemory();
      addTearDown(core.close);
      addTearDown(intelligence.close);
      final mediaRepository = MediaRepository(core);
      for (final media in [
        const Media(
          id: 'duplicate-a',
          title: 'A 720p',
          year: '2026',
          type: MediaType.movie,
          path: '/Movies/a.mp4',
          fileHash: 'same-hash',
          detailsJson: '{"genres":["Sci-Fi"]}',
          dateAdded: '2020-01-01T00:00:00.000Z',
        ),
        const Media(
          id: 'duplicate-b',
          title: 'B',
          year: '2026',
          type: MediaType.movie,
          path: '/Movies/b.mp4',
          fileHash: 'same-hash',
          detailsJson: '{"genres":["Sci-Fi"]}',
          dateAdded: '2020-01-01T00:00:00.000Z',
        ),
        const Media(
          id: 'unrelated',
          title: 'Drama',
          year: '2025',
          type: MediaType.movie,
          path: '/Movies/drama.mkv',
          detailsJson: '{"genres":["Drama"]}',
          dateAdded: '2020-01-01T00:00:00.000Z',
        ),
      ]) {
        await mediaRepository.upsert(media);
      }
      final service = MediaAgentService(
        mediaRepository: mediaRepository,
        progressRepository: PlaybackProgressRepository(core),
        runs: AgentRunRepository(intelligence),
        collections: SmartCollectionRepository(intelligence),
      );

      final duplicates = await service.plan(MediaAgentOperation.findDuplicates);
      expect(
        duplicates.preview.map((item) => item.mediaId),
        containsAll(['duplicate-a', 'duplicate-b']),
      );
      final lowQuality = await service.plan(
        MediaAgentOperation.inspectLowQuality,
      );
      expect(lowQuality.preview.single.mediaId, 'duplicate-a');
      final unwatched = await service.plan(MediaAgentOperation.listUnwatched);
      expect(unwatched.preview, hasLength(3));

      final collection = await service.plan(
        MediaAgentOperation.smartCollection,
        query: 'Sci-Fi',
        collectionName: '科幻片',
      );
      await service.confirm(collection.id);
      final run = await service.execute(collection.id);
      expect(run.status, MediaAgentRunStatus.succeeded);
      expect(
        await SmartCollectionRepository(intelligence).list(),
        hasLength(1),
      );
    },
  );

  test(
    'turns a natural-language request into a normal confirmation plan',
    () async {
      final core = AppDatabase(NativeDatabase.memory());
      final intelligence = IntelligenceDatabase.inMemory();
      addTearDown(core.close);
      addTearDown(intelligence.close);
      final mediaRepository = MediaRepository(core);
      await mediaRepository.upsert(
        const Media(
          id: 'agent-request-movie',
          title: 'Space Film',
          year: '2026',
          type: MediaType.movie,
          path: '/Movies/space.mkv',
          detailsJson: '{"genres":["Sci-Fi"]}',
        ),
      );
      final service = MediaAgentService(
        mediaRepository: mediaRepository,
        progressRepository: PlaybackProgressRepository(core),
        runs: AgentRunRepository(intelligence),
        collections: SmartCollectionRepository(intelligence),
        planner: _FakeAgentPlanner(),
      );

      final plan = await service.planFromRequest('把科幻片整理成合集');

      expect(plan.operation, MediaAgentOperation.smartCollection);
      expect(plan.parameters['query'], 'Sci-Fi');
      expect(plan.preview.single.title, 'Space Film');
    },
  );
}

class _FakeAgentPlanner implements MediaAgentPlanner {
  @override
  Future<AgentIntent> plan(String request) async => const AgentIntent(
    operation: MediaAgentOperation.smartCollection,
    query: 'Sci-Fi',
    collectionName: '科幻片',
  );
}
