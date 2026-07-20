import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/intelligence/agent_run_repository.dart';
import '../data/intelligence/ai_job_repository.dart';
import '../data/intelligence/intelligence_asset_repository.dart';
import '../data/intelligence/intelligence_database.dart';
import '../data/intelligence/intelligence_search_repository.dart';
import '../data/intelligence/smart_collection_repository.dart';
import '../data/intelligence/watch_event_repository.dart';
import '../providers/data_providers.dart';
import '../services/intelligence/media_identity_service.dart';
import '../services/intelligence/media_context_service.dart';
import '../services/intelligence/media_agent_service.dart';
import '../services/intelligence/ai_job_service.dart';
import '../services/intelligence/ai_provider.dart';
import '../services/intelligence/ai_worker_client.dart';
import '../services/intelligence/media_intelligence_service.dart';
import '../services/intelligence/personal_memory_service.dart';
import '../services/intelligence/semantic_search_service.dart';
import '../services/intelligence/subtitle_generation_service.dart';
import '../services/intelligence/transcript_service.dart';

final intelligenceDatabaseProvider = Provider<IntelligenceDatabase>((ref) {
  final database = IntelligenceDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final aiJobRepositoryProvider = Provider<AiJobRepository>(
  (ref) => AiJobRepository(ref.watch(intelligenceDatabaseProvider)),
);

final localAiProviderProvider = FutureProvider<AiProvider?>((ref) async {
  final config = await ref.watch(configProvider.future);
  final executable = config.aiWorkerPath.trim();
  if (executable.isEmpty) return null;
  final transport = await ProcessWorkerTransport.start(executable);
  final client = AiWorkerClient(transport);
  ref.onDispose(() => unawaited(client.close()));
  return LocalWorkerProvider(client, modelDirectory: config.aiModelDirectory);
});

final mediaIntelligenceServiceProvider =
    FutureProvider<MediaIntelligenceService?>((ref) async {
      final provider = await ref.watch(localAiProviderProvider.future);
      if (provider == null) return null;
      final jobs = ref.watch(aiJobRepositoryProvider);
      final jobService = AiJobService(jobs);
      await jobService.recoverAfterRestart();
      return MediaIntelligenceService(
        assets: ref.watch(intelligenceAssetRepositoryProvider),
        jobs: jobs,
        jobService: jobService,
        transcripts: ref.watch(transcriptServiceProvider),
        provider: provider,
      );
    });

final intelligenceAssetRepositoryProvider =
    Provider<IntelligenceAssetRepository>(
      (ref) =>
          IntelligenceAssetRepository(ref.watch(intelligenceDatabaseProvider)),
    );

final intelligenceSearchRepositoryProvider =
    Provider<IntelligenceSearchRepository>(
      (ref) =>
          IntelligenceSearchRepository(ref.watch(intelligenceDatabaseProvider)),
    );

final watchEventRepositoryProvider = Provider<WatchEventRepository>(
  (ref) => WatchEventRepository(ref.watch(intelligenceDatabaseProvider)),
);

final agentRunRepositoryProvider = Provider<AgentRunRepository>(
  (ref) => AgentRunRepository(ref.watch(intelligenceDatabaseProvider)),
);

final smartCollectionRepositoryProvider = Provider<SmartCollectionRepository>(
  (ref) => SmartCollectionRepository(ref.watch(intelligenceDatabaseProvider)),
);

final personalMemoryServiceProvider = Provider<PersonalMemoryService>((ref) {
  return PersonalMemoryService(
    events: ref.watch(watchEventRepositoryProvider),
    assets: ref.watch(intelligenceAssetRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
  );
});

final personalMemorySummaryProvider = FutureProvider<PersonalMemorySummary>((
  ref,
) {
  return ref.watch(personalMemoryServiceProvider).summary();
});

final semanticSearchServiceProvider = Provider<SemanticSearchService>((ref) {
  return SemanticSearchService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    assets: ref.watch(intelligenceAssetRepositoryProvider),
    transcriptSearch: ref.watch(intelligenceSearchRepositoryProvider),
  );
});

final askFilmlyProvider = FutureProvider.family<List<AskFilmlyResult>, String>(
  (ref, query) => ref.watch(semanticSearchServiceProvider).search(query),
);

final mediaIdentityServiceProvider = Provider<MediaIdentityService>(
  (ref) => const MediaIdentityService(),
);

final transcriptServiceProvider = Provider<TranscriptService>(
  (ref) => TranscriptService(ref.watch(intelligenceDatabaseProvider)),
);

final mediaContextServiceProvider = Provider<MediaContextService>(
  (ref) => MediaContextService(ref.watch(transcriptServiceProvider)),
);

final subtitleGenerationServiceProvider = Provider<SubtitleGenerationService>(
  (ref) => SubtitleGenerationService(ref.watch(transcriptServiceProvider)),
);

final mediaAgentServiceProvider = FutureProvider<MediaAgentService>((
  ref,
) async {
  final config = await ref.watch(configProvider.future);
  final intelligence = await ref.watch(mediaIntelligenceServiceProvider.future);
  final service = MediaAgentService(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    progressRepository: ref.watch(playbackProgressRepositoryProvider),
    runs: ref.watch(agentRunRepositoryProvider),
    collections: ref.watch(smartCollectionRepositoryProvider),
    subtitleGenerator: intelligence == null
        ? null
        : (media) async {
            final raw = (media.fullPath?.trim().isNotEmpty == true)
                ? media.fullPath!.trim()
                : media.path.trim();
            final parsed = Uri.tryParse(raw);
            final path = parsed?.scheme == 'file' ? parsed!.toFilePath() : raw;
            if (parsed?.hasScheme == true && parsed?.scheme != 'file') {
              throw StateError('网络媒体暂不支持本地批量字幕生成');
            }
            final result = await intelligence.generateSubtitlesForLocalFile(
              path: path,
              model: config.aiModel,
              sourceLanguage: 'auto',
              targetLanguage: config.aiTargetLanguage,
              outputDirectory: config.aiIndexDirectory.trim().isEmpty
                  ? null
                  : Directory(
                      p.join(config.aiIndexDirectory.trim(), 'subtitles'),
                    ),
            );
            return result.artifacts
                .map((artifact) => artifact.file.path)
                .toList(growable: false);
          },
  );
  await service.recoverInterrupted();
  return service;
});
