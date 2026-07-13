import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';

/// Local folder management page — users add/remove folders and trigger scans.
/// This is the primary "add source" flow for desktop users who have media on
/// their local disk or mounted volumes.
class LocalFoldersPage extends ConsumerStatefulWidget {
  const LocalFoldersPage({super.key});

  @override
  ConsumerState<LocalFoldersPage> createState() => _LocalFoldersPageState();
}

class _LocalFoldersPageState extends ConsumerState<LocalFoldersPage> {
  bool _scanning = false;
  bool _enriching = false;

  Future<void> _addFolder() async {
    if (PlatformCapabilities.isMobile) {
      await _importMobileFiles();
      return;
    }
    final path = await getDirectoryPath(confirmButtonText: '选择此文件夹');
    if (path == null || !mounted) return;

    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;

    final folders = [...config.selectedFolders];
    if (folders.contains(path)) {
      _showSnack('该目录已添加');
      return;
    }

    folders.add(path);
    await ref
        .read(configProvider.notifier)
        .save(config.copyWith(selectedFolders: folders));
    _showSnack('已添加：$path');
  }

  Future<void> _importMobileFiles() async {
    const videoTypes = XTypeGroup(
      label: '视频',
      extensions: ['mp4', 'mkv', 'avi', 'mov', 'm4v', 'webm', 'ts', 'm2ts'],
    );
    final files = await openFiles(acceptedTypeGroups: const [videoTypes]);
    if (files.isEmpty || !mounted) return;

    setState(() => _scanning = true);
    try {
      final documents = await getApplicationDocumentsDirectory();
      final importDir = Directory(p.join(documents.path, 'ImportedMedia'));
      await importDir.create(recursive: true);

      var imported = 0;
      for (final file in files) {
        final target = File(p.join(importDir.path, p.basename(file.name)));
        await target.writeAsBytes(await file.readAsBytes(), flush: true);
        imported++;
      }

      final config = ref.read(configProvider).asData?.value;
      if (config == null) return;
      final folders = [...config.selectedFolders];
      if (!folders.contains(importDir.path)) folders.add(importDir.path);
      await ref
          .read(configProvider.notifier)
          .save(config.copyWith(selectedFolders: folders));

      final result = await ref.read(libraryScannerProvider).scanFolders([
        importDir.path,
      ]);
      invalidateLibraryViews(ref);
      _showSnack('已导入 $imported 个文件，识别 ${result.importedItems} 项');
    } catch (e) {
      _showSnack('导入本地视频失败：$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _removeFolder(String folder) async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;

    final folders = [...config.selectedFolders]..remove(folder);
    await ref
        .read(configProvider.notifier)
        .save(config.copyWith(selectedFolders: folders));
  }

  /// Re-fetch TMDB metadata for all items (force mode) or only missing ones.
  Future<void> _refreshMetadata({bool forceAll = false}) async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null || config.tmdbApiKey.isEmpty) {
      _showSnack('请先在设置中配置 TMDB API Key');
      return;
    }

    setState(() => _enriching = true);
    try {
      final repo = ref.read(mediaRepositoryProvider);
      final ids = forceAll
          ? await repo.getAllIds()
          : await repo.getIdsWithoutPoster();

      if (ids.isEmpty) {
        _showSnack(forceAll ? '媒体库为空' : '所有媒体都已有元数据，可长按按钮强制刷新全部');
        setState(() => _enriching = false);
        return;
      }

      final result = await ref
          .read(libraryMetadataSyncProvider)
          .enrichByIds(
            mediaIds: ids,
            apiKey: config.tmdbApiKey,
            geminiApiKey: config.geminiApiKey,
          );

      invalidateLibraryViews(ref);

      _showSnack(
        '元数据刷新完成：更新 ${result.updatedItems} 项，失败 ${result.failedItems} 项',
      );
    } catch (e) {
      _showSnack('元数据刷新失败：$e');
    } finally {
      if (mounted) setState(() => _enriching = false);
    }
  }

  Future<void> _scanAll() async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null || config.selectedFolders.isEmpty) {
      _showSnack('请先添加至少一个文件夹');
      return;
    }

    setState(() => _scanning = true);
    try {
      // Clear old library data so stale entries from buggy grouping are removed
      await ref.read(mediaRepositoryProvider).deleteAll();

      final result = await ref
          .read(libraryScannerProvider)
          .scanFolders(config.selectedFolders);

      var metaMsg = '';
      if (config.tmdbApiKey.isNotEmpty && result.mediaIds.isNotEmpty) {
        final metaResult = await ref
            .read(libraryMetadataSyncProvider)
            .enrichByIds(
              mediaIds: result.mediaIds,
              apiKey: config.tmdbApiKey,
              geminiApiKey: config.geminiApiKey,
            );
        metaMsg = '，元数据 ${metaResult.updatedItems} 项已更新';
      }

      invalidateLibraryViews(ref);

      _showSnack(
        '扫描完成：发现 ${result.scannedFiles} 个文件，'
        '导入 ${result.importedItems} 项'
        '（电影 ${result.movieCount} / 剧集 ${result.tvCount}）'
        '$metaMsg',
      );
    } catch (e) {
      _showSnack('扫描失败：$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/sources');
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (config) => _body(context, config.selectedFolders),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<String> folders) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilmlyInlineHeader(
            leading: FilmlyIconButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _goBack(context),
            ),
            title: PlatformCapabilities.isMobile ? '本地视频' : '本地目录',
            subtitle: PlatformCapabilities.isMobile
                ? '已添加 ${folders.length} 个导入目录。'
                : '已添加 ${folders.length} 个文件夹，用于扫描本地影片。',
          ),
          const SizedBox(height: 24),
          Text(
            PlatformCapabilities.isMobile
                ? '从系统文件选择器导入视频，文件会复制到应用目录并加入媒体库。'
                : '选择包含影片的文件夹，系统会递归扫描所有视频文件并导入媒体库。',
            style: TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilmlyGlassButton(
                label: PlatformCapabilities.isMobile ? '导入视频' : '添加文件夹',
                icon: PlatformCapabilities.isMobile
                    ? Icons.video_file_rounded
                    : Icons.create_new_folder_rounded,
                accent: true,
                onTap: _addFolder,
              ),
              FilmlyGlassButton(
                label: _scanning ? '扫描中…' : '扫描全部',
                leading: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                icon: _scanning ? null : Icons.refresh_rounded,
                onTap: _scanning || folders.isEmpty ? null : _scanAll,
              ),
              FilmlyGlassButton(
                label: _enriching ? '抓取中…' : '重新匹配元数据',
                leading: _enriching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                icon: _enriching ? null : Icons.auto_awesome_rounded,
                onTap: _enriching
                    ? null
                    : () => _refreshMetadata(forceAll: true),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (folders.isEmpty)
            _emptyState()
          else
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: folders.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) => _folderTile(folders[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: FilmlyPalette.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 34,
                color: FilmlyPalette.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '还没有添加文件夹',
              style: TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '点击上方“添加文件夹”选择包含影片的目录。',
              style: TextStyle(
                color: FilmlyPalette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderTile(String path) {
    return FilmlyGlassPanel(
      borderRadius: BorderRadius.circular(24),
      color: FilmlyPalette.surface,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF66A3FF).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.folder_rounded,
              color: Color(0xFF66A3FF),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _removeFolder(path),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: FilmlyPalette.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: FilmlyPalette.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
