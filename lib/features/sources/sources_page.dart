import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../data/models/app_config.dart';
import '../../data/models/resource_source.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';

/// Resource library: saved storage sources live here, while the media library
/// remains focused on posters, metadata and playback.
class SourcesPage extends ConsumerStatefulWidget {
  const SourcesPage({super.key});

  @override
  ConsumerState<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends ConsumerState<SourcesPage> {
  static const _localSource = ResourceSource(
    id: 'local-downloads',
    name: '本地下载',
    type: ResourceSourceType.local,
    endpoint: '设备存储',
  );

  Future<void> _openSource(ResourceSource source) async {
    switch (source.type) {
      case ResourceSourceType.local:
        context.go('/sources/local');
      case ResourceSourceType.webdav:
        context.go(_sourceLocation('/webdav', source.id));
      case ResourceSourceType.smb:
        context.go(_sourceLocation('/smb', source.id));
      case ResourceSourceType.emby || ResourceSourceType.jellyfin:
        context.go(_sourceLocation('/emby', source.id));
      case ResourceSourceType.cloud:
        _showMessage('该云盘类型暂未开放');
    }
  }

  Future<void> _showSourceActions(ResourceSource source) async {
    final action = await showModalBottomSheet<_SourceAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SourceActionSheet(source: source),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SourceAction.browse:
        await _openSource(source);
      case _SourceAction.importNew:
        await _openSource(source);
      case _SourceAction.edit:
        context.go(_editorLocation(source.type, source.id));
      case _SourceAction.delete:
        await _deleteSource(source);
    }
  }

  Future<void> _deleteSource(ResourceSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${source.name}」？'),
        content: const Text('只会移除保存的连接信息，不会删除远端文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;
    final sources = config.resourceSources
        .where((item) => item.id != source.id)
        .toList(growable: false);
    await ref
        .read(configProvider.notifier)
        .save(config.copyWith(resourceSources: sources));
    _showMessage('已删除资源源「${source.name}」');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('加载资源库失败：$error')),
          data: (config) => _body(context, config),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppConfig config) {
    final sources = config.resourceSources
        .where((source) => source.enabled)
        .toList(growable: false);
    final webdav = sources
        .where((source) => source.type == ResourceSourceType.webdav)
        .toList(growable: false);
    final smb = sources
        .where((source) => source.type == ResourceSourceType.smb)
        .toList(growable: false);
    final servers = sources
        .where(
          (source) =>
              source.type == ResourceSourceType.emby ||
              source.type == ResourceSourceType.jellyfin,
        )
        .toList(growable: false);
    final isMobile = PlatformCapabilities.isMobile;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 36,
            isMobile ? 18 : 28,
            isMobile ? 20 : 36,
            36,
          ),
          children: [
            _ResourceHeader(
              onBack: () => context.canPop() ? context.pop() : context.go('/'),
              onRefresh: () => setState(() {}),
              onAdd: () => context.go('/sources/add'),
            ),
            SizedBox(height: isMobile ? 24 : 30),
            _ResourceGroup(
              title: '本地存储',
              children: [
                _ResourceTile(
                  key: const Key('source_card_local'),
                  source: _localSource,
                  subtitle: '浏览设备上的本地文件，选择后导入媒体库',
                  onTap: () => _openSource(_localSource),
                ),
              ],
            ),
            if (webdav.isEmpty || smb.isEmpty) ...[
              const SizedBox(height: 22),
              _ResourceGroup(
                title: '快速添加',
                children: [
                  if (webdav.isEmpty)
                    _ResourceTile(
                      key: const Key('source_card_webdav'),
                      source: const ResourceSource(
                        id: 'quick-webdav',
                        name: 'WebDAV',
                        type: ResourceSourceType.webdav,
                      ),
                      subtitle: '添加 WebDAV 文件源',
                      onTap: () => _openSource(
                        const ResourceSource(
                          id: 'quick-webdav',
                          name: 'WebDAV',
                          type: ResourceSourceType.webdav,
                        ),
                      ),
                    ),
                  if (smb.isEmpty)
                    _ResourceTile(
                      key: const Key('source_card_smb'),
                      source: const ResourceSource(
                        id: 'quick-smb',
                        name: 'SMB / NAS',
                        type: ResourceSourceType.smb,
                      ),
                      subtitle: '添加局域网共享文件夹',
                      onTap: () => _openSource(
                        const ResourceSource(
                          id: 'quick-smb',
                          name: 'SMB / NAS',
                          type: ResourceSourceType.smb,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (webdav.isNotEmpty) ...[
              const SizedBox(height: 22),
              _ResourceGroup(
                title: 'WebDAV',
                children: [
                  for (final source in webdav)
                    _ResourceTile(
                      key: Key('resource_source_${source.id}'),
                      source: source,
                      onTap: () => _openSource(source),
                      onMore: () => _showSourceActions(source),
                    ),
                ],
              ),
            ],
            if (smb.isNotEmpty) ...[
              const SizedBox(height: 22),
              _ResourceGroup(
                title: 'SMB / NAS',
                children: [
                  for (final source in smb)
                    _ResourceTile(
                      key: Key('resource_source_${source.id}'),
                      source: source,
                      onTap: () => _openSource(source),
                      onMore: () => _showSourceActions(source),
                    ),
                ],
              ),
            ],
            if (servers.isNotEmpty) ...[
              const SizedBox(height: 22),
              _ResourceGroup(
                title: '媒体服务器',
                children: [
                  for (final source in servers)
                    _ResourceTile(
                      key: Key('resource_source_${source.id}'),
                      source: source,
                      onTap: () => _openSource(source),
                      onMore: () => _showSourceActions(source),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            _AddSourcePrompt(onTap: () => context.go('/sources/add')),
          ],
        ),
      ),
    );
  }

  static String _sourceLocation(String route, String sourceId) =>
      Uri(path: route, queryParameters: {'sourceId': sourceId}).toString();

  static String _editorLocation(ResourceSourceType type, String sourceId) =>
      Uri(
        path: '/sources/edit',
        queryParameters: {'type': type.name, 'sourceId': sourceId},
      ).toString();
}

class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader({
    required this.onBack,
    required this.onRefresh,
    required this.onAdd,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformCapabilities.isMobile;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isMobile && Navigator.of(context).canPop()) ...[
          FilmlyIconButton(
            key: const Key('sources_back_button'),
            icon: Icons.chevron_left_rounded,
            size: 44,
            radius: 22,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '资源库',
                style: TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: isMobile ? 31 : 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isMobile ? '管理你的本地与网络文件源' : '连接、浏览并导入你的网络资源',
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        FilmlyIconButton(
          key: const Key('sources_refresh_button'),
          icon: Icons.download_rounded,
          size: isMobile ? 48 : 42,
          radius: isMobile ? 24 : 14,
          onTap: onRefresh,
        ),
        const SizedBox(width: 10),
        FilmlyIconButton(
          key: const Key('sources_add_button'),
          icon: Icons.add_rounded,
          size: isMobile ? 48 : 42,
          radius: isMobile ? 24 : 14,
          onTap: onAdd,
        ),
      ],
    );
  }
}

class _ResourceGroup extends StatelessWidget {
  const _ResourceGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title,
            style: const TextStyle(
              color: FilmlyPalette.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FilmlyPalette.divider),
          ),
          child: Column(children: _withDividers(children)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        result.add(const Divider(height: 1, indent: 76, endIndent: 16));
      }
      result.add(children[i]);
    }
    return result;
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    super.key,
    required this.source,
    required this.onTap,
    this.onMore,
    this.subtitle,
  });

  final ResourceSource source;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isLocal = source.type == ResourceSourceType.local;
    final imported = source.importedPaths.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isLocal
                    ? const Color(0xFFDCEBFF)
                    : FilmlyPalette.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                source.type.icon,
                color: isLocal ? const Color(0xFF6F9FEA) : FilmlyPalette.accent,
                size: 25,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FilmlyPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? source.displayEndpoint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (imported)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '已导入',
                  style: TextStyle(
                    color: Color(0xFF3A9B5F),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (onMore != null)
              IconButton(
                tooltip: '更多操作',
                icon: const Icon(Icons.more_horiz_rounded),
                color: FilmlyPalette.textSecondary,
                onPressed: onMore,
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: FilmlyPalette.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddSourcePrompt extends StatelessWidget {
  const _AddSourcePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: FilmlyPalette.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: FilmlyPalette.accent.withValues(alpha: 0.18),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: FilmlyPalette.accent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '添加新的文件源',
                style: TextStyle(
                  color: FilmlyPalette.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: FilmlyPalette.accent),
          ],
        ),
      ),
    );
  }
}

enum _SourceAction { browse, importNew, edit, delete }

class _SourceActionSheet extends StatelessWidget {
  const _SourceActionSheet({required this.source});

  final ResourceSource source;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                source.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _action(
              context,
              Icons.folder_open_rounded,
              '管理已导入资源',
              _SourceAction.browse,
            ),
            _action(
              context,
              Icons.download_rounded,
              '导入新资源',
              _SourceAction.importNew,
            ),
            _action(context, Icons.edit_rounded, '编辑文件源', _SourceAction.edit),
            _action(
              context,
              Icons.delete_outline_rounded,
              '删除文件源',
              _SourceAction.delete,
            ),
            const Divider(height: 1),
            _action(context, Icons.close_rounded, '取消', null),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    _SourceAction? action,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: action == _SourceAction.delete ? Colors.red : null,
      ),
      title: Text(label),
      onTap: () => Navigator.pop(context, action),
    );
  }
}
