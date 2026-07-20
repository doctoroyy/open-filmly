import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/intelligence/intelligence_database.dart';
import 'package:open_filmly/data/intelligence/watch_event_repository.dart';
import 'package:open_filmly/services/intelligence/ai_provider.dart';
import 'package:open_filmly/services/intelligence/intelligence_bundle_service.dart';
import 'package:open_filmly/services/intelligence/media_identity_service.dart';
import 'package:open_filmly/services/intelligence/transcript_service.dart';

void main() {
  test(
    'exports and imports AI data without requiring the core database',
    () async {
      final source = IntelligenceDatabase.inMemory();
      final target = IntelligenceDatabase.inMemory();
      final directory = await Directory.systemTemp.createTemp('filmly-bundle-');
      addTearDown(() async {
        await source.close();
        await target.close();
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final identity = MediaIdentityService.fromDescriptor(
        sourceScope: 'local',
        canonicalUri: '/Movies/rain.mkv',
        fileSize: 100,
      );
      await source
          .into(source.intelligenceAssets)
          .insert(
            IntelligenceAssetsCompanion.insert(
              id: identity.identityKey,
              mediaId: const Value('movie-1'),
              sourceScope: identity.sourceScope,
              canonicalUri: identity.canonicalUri,
              identityKey: identity.identityKey,
              fileSize: const Value(100),
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
      await TranscriptService(source).saveProviderResult(
        identity.identityKey,
        const TranscriptionResult(
          language: 'en',
          segments: [
            ProviderTranscriptSegment(startMs: 0, endMs: 1000, text: 'hello'),
          ],
        ),
      );
      await WatchEventRepository(source).record(
        assetId: identity.identityKey,
        kind: WatchEventKind.play,
        positionMs: 10,
      );

      await IntelligenceBundleService(source).exportToDirectory(directory);
      await IntelligenceBundleService(target).importFromDirectory(directory);

      expect(
        await target.select(target.intelligenceAssets).get(),
        hasLength(1),
      );
      expect(
        await TranscriptService(target).getByAsset(identity.identityKey),
        hasLength(1),
      );
      expect(await WatchEventRepository(target).list(), hasLength(1));
    },
  );
}
