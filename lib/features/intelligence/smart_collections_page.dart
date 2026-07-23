import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../data/intelligence/agent_models.dart';
import '../../data/models/media.dart';
import '../../providers/data_providers.dart';
import '../../providers/intelligence_providers.dart';
import '../../widgets/filmly_design.dart';

/// Browse Agent-created smart collections as first-class library shelves.
class SmartCollectionsPage extends ConsumerWidget {
  const SmartCollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<List<SmartCollection>>(
              future: ref.watch(smartCollectionRepositoryProvider).list(),
              builder: (context, snapshot) {
                final collections = snapshot.data ?? const <SmartCollection>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  children: [
                    Row(
                      children: [
                        FilmlyIconButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/'),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Smart Collections',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/agent'),
                          child: const Text('Ask Filmly to create one'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '由 Media Agent 生成的可编辑合集。它们只保存媒体引用，不会复制或移动文件。',
                      style: TextStyle(
                        color: FilmlyPalette.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (collections.isEmpty)
                      FilmlyGlassPanel(
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          '还没有智能合集。打开 Conversations，试着说：\n“建一个轻松的科幻片合集”。',
                          style: TextStyle(height: 1.5),
                        ),
                      )
                    else
                      for (final collection in collections)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CollectionCard(collection: collection),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.collection});

  final SmartCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilmlyGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  collection.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${collection.mediaIds.length} titles',
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (collection.query.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              collection.query,
              style: const TextStyle(
                color: FilmlyPalette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FutureBuilder<List<Media>>(
            future: () async {
              final repo = ref.read(mediaRepositoryProvider);
              final items = <Media>[];
              for (final id in collection.mediaIds.take(8)) {
                final media = await repo.getById(id);
                if (media != null) items.add(media);
              }
              return items;
            }(),
            builder: (context, snapshot) {
              final media = snapshot.data ?? const <Media>[];
              if (media.isEmpty) {
                return const Text(
                  '合集还没有可解析的媒体项。',
                  style: TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 12,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in media)
                    ActionChip(
                      label: Text(item.title),
                      onPressed: () =>
                          context.push(mediaDetailLocation(item.id)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
