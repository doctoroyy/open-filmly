import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/open_player.dart';
import '../../data/models/app_config.dart';
import '../../data/models/resource_source.dart';
import '../../providers/data_providers.dart';
import '../../providers/smb_providers.dart';
import '../../services/library/media_library_entry_factory.dart';
import '../../services/playback/external_subtitle_finder.dart';
import '../../services/playback/playback_source_resolver.dart';
import '../../services/webdav/webdav_service.dart';
import '../../widgets/filmly_design.dart';
import '../player/player_page.dart';

/// Connect to a WebDAV server, browse its folders, and import or play media.
class WebDavBrowserPage extends ConsumerStatefulWidget {
  const WebDavBrowserPage({super.key, this.sourceId});

  final String? sourceId;

  @override
  ConsumerState<WebDavBrowserPage> createState() => _WebDavBrowserPageState();
}

class _SelectionImportPanel extends StatelessWidget {
  const _SelectionImportPanel({
    required this.count,
    required this.importing,
    required this.onImport,
  });

  final int count;
  final bool importing;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '导入后可在 App 内展示和播放，但不会下载这些资源',
          style: TextStyle(color: FilmlyPalette.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              '导入至：',
              style: TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              '媒体库 & 资源库',
              style: TextStyle(
                color: FilmlyPalette.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            FilmlyGlassButton(
              label: importing ? '导入中…' : '导入 $count 项',
              icon: importing ? null : Icons.download_rounded,
              accent: true,
              onTap: importing ? null : onImport,
            ),
          ],
        ),
      ],
    );
    return FilmlyGlassPanel(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(16, 13, 12, 12),
      child: content,
    );
  }
}

class _WebDavBrowserPageState extends ConsumerState<WebDavBrowserPage> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _connecting = false;
  bool _connected = false;
  bool _prefilled = false;
  bool _loading = false;
  bool _importing = false;
  String? _error;

  /// Directory stack; empty means the server root ('/').
  final List<String> _stack = [];
  List<WebDavEntry> _entries = [];
  final Set<String> _selectedPaths = {};

  WebDavService get _dav => ref.read(webDavServiceProvider);
  String get _currentPath => _stack.isEmpty ? '/' : _stack.last;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _prefillFromConfig() {
    if (_prefilled) return;
    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;
    _prefilled = true;
    final source = _sourceFromConfig(config);
    if (source != null) {
      if (_urlCtrl.text.isEmpty) _urlCtrl.text = source.endpoint;
      if (_userCtrl.text.isEmpty) _userCtrl.text = source.username;
      if (_passCtrl.text.isEmpty) _passCtrl.text = source.password;
      return;
    }
    if (_urlCtrl.text.isEmpty) _urlCtrl.text = config.webdavUrl;
    if (_userCtrl.text.isEmpty) _userCtrl.text = config.webdavUsername;
    if (_passCtrl.text.isEmpty) _passCtrl.text = config.webdavPassword;
  }

  ResourceSource? _sourceFromConfig(AppConfig config) {
    final sourceId = widget.sourceId;
    if (sourceId != null) {
      for (final source in config.resourceSources) {
        if (source.id == sourceId) return source;
      }
    }
    for (final source in config.resourceSources) {
      if (source.type == ResourceSourceType.webdav) return source;
    }
    return null;
  }

  Future<void> _saveSource({String? importedPath}) async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;
    final url = _urlCtrl.text.trim();
    final existing = _sourceFromConfig(config);
    final paths = {...?existing?.importedPaths};
    if (importedPath != null && importedPath.isNotEmpty) {
      paths.add(importedPath);
    }
    final source = ResourceSource(
      id:
          existing?.id ??
          widget.sourceId ??
          ResourceSource.newId(ResourceSourceType.webdav),
      name: existing?.name ?? '我的 WebDAV',
      type: ResourceSourceType.webdav,
      endpoint: url,
      protocol: url.startsWith('http://') ? 'http' : 'https',
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      path: _currentPath,
      importedPaths: paths.toList(growable: false),
    );
    final sources = [...config.resourceSources];
    final index = sources.indexWhere((item) => item.id == source.id);
    if (index >= 0) {
      sources[index] = source;
    } else {
      sources.add(source);
    }
    await ref
        .read(configProvider.notifier)
        .save(
          config.copyWith(
            webdavUrl: url,
            webdavUsername: source.username,
            webdavPassword: source.password,
            resourceSources: sources,
          ),
        );
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入 WebDAV 地址');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _dav.connect(
        WebDavConfig(
          url: url,
          username: _userCtrl.text.trim(),
          password: _passCtrl.text,
        ),
      );

      // Persist both the legacy resolver fields and the selected source.
      await _saveSource();

      if (!mounted) return;
      setState(() => _connected = true);
      await _loadDir('/');
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    _dav.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _entries = [];
      _stack.clear();
      _selectedPaths.clear();
      _error = null;
    });
  }

  Future<void> _loadDir(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _dav.listDir(path);
      entries.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (e) {
      if (mounted) setState(() => _error = '读取目录失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter(WebDavEntry dir) async {
    setState(() {
      _selectedPaths.clear();
      _stack.add(dir.path);
    });
    await _loadDir(dir.path);
  }

  Future<void> _goUp() async {
    if (_stack.isEmpty) return;
    setState(() {
      _selectedPaths.clear();
      _stack.removeLast();
    });
    await _loadDir(_currentPath);
  }

  void _toggleSelection(WebDavEntry entry, bool selected) {
    setState(() {
      if (selected) {
        _selectedPaths.add(entry.path);
      } else {
        _selectedPaths.remove(entry.path);
      }
    });
  }

  bool get _allDirectoriesSelected {
    final directories = _entries.where((entry) => entry.isDir).toList();
    return directories.isNotEmpty &&
        directories.every((entry) => _selectedPaths.contains(entry.path));
  }

  void _toggleSelectAll() {
    final directories = _entries.where((entry) => entry.isDir).toList();
    setState(() {
      if (_allDirectoriesSelected) {
        _selectedPaths.clear();
      } else {
        _selectedPaths
          ..clear()
          ..addAll(directories.map((entry) => entry.path));
      }
    });
  }

  Future<void> _onTapEntry(WebDavEntry entry) async {
    if (entry.isDir) {
      await _enter(entry);
      return;
    }
    if (!_isVideo(entry.name)) return;

    final url = _dav.fileUrl(entry.path);
    final headers = _dav.config?.authHeaders;
    final subtitles =
        ExternalSubtitleFinder.findAmongSiblings(
              entry.path,
              _entries.where((item) => !item.isDir).map((item) => item.path),
            )
            .map(
              (subtitle) => PlaybackSubtitleSource(
                uri: _dav.fileUrl(subtitle.path),
                title: subtitle.label,
                language: subtitle.languageHint,
              ),
            )
            .toList(growable: false);
    await openPlayer(
      context,
      PlayerArgs(
        uri: url,
        title: entry.name,
        httpHeaders: (headers != null && headers.isNotEmpty) ? headers : null,
        subtitles: subtitles,
      ),
    );
  }

  Future<void> _importCurrentFolder() => _importFolders([_currentPath]);

  Future<void> _importSelected() => _importFolders(_selectedPaths.toList());

  Future<void> _importFolders(List<String> paths) async {
    if (paths.isEmpty) return;
    setState(() => _importing = true);
    try {
      var importedItems = 0;
      var movieCount = 0;
      var tvCount = 0;
      final mediaIds = <String>[];
      for (final path in paths) {
        final result = await ref
            .read(webDavLibraryImportProvider)
            .importFolder(path);
        importedItems += result.importedItems;
        movieCount += result.movieCount;
        tvCount += result.tvCount;
        mediaIds.addAll(result.mediaIds);
        await _saveSource(importedPath: path);
      }

      final config = ref.read(configProvider).asData?.value;
      var metaMsg = '';
      if (config != null &&
          config.tmdbApiKey.isNotEmpty &&
          mediaIds.isNotEmpty) {
        final meta = await ref
            .read(libraryMetadataSyncProvider)
            .enrichByIds(
              mediaIds: mediaIds,
              apiKey: config.tmdbApiKey,
              geminiApiKey: config.geminiApiKey,
            );
        metaMsg = '，元数据 ${meta.updatedItems} 项已更新';
      }

      invalidateLibraryViews(ref);
      _selectedPaths.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：$importedItems 项'
            '（电影 $movieCount / 剧集 $tvCount）$metaMsg',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败：$e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  bool _isVideo(String name) {
    return MediaLibraryEntryFactory.isVideoPath(name);
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    context.go('/sources');
  }

  @override
  Widget build(BuildContext context) {
    _prefillFromConfig();
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilmlyInlineHeader(
                leading: FilmlyIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _goBack,
                ),
                title: 'WebDAV',
                subtitle: _connected
                    ? '已连接 · ${_currentPath == '/' ? '根目录' : _currentPath}'
                    : '连接到 WebDAV 兼容的云存储或 NAS',
              ),
              const SizedBox(height: 24),
              if (!_connected) _connectForm() else _browser(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectForm() {
    return Expanded(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_urlCtrl, 'WebDAV 地址', 'https://dav.example.com/dav'),
            const SizedBox(height: 14),
            _field(_userCtrl, '用户名（可选）', 'username'),
            const SizedBox(height: 14),
            _field(_passCtrl, '密码（可选）', '••••••', obscure: true),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF6B7D), fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            FilmlyGlassButton(
              label: _connecting ? '连接中…' : '连接',
              icon: _connecting ? null : Icons.link_rounded,
              accent: true,
              leading: _connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _connecting ? null : _connect,
            ),
          ],
        ),
      ),
    );
  }

  Widget _browser() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_stack.isNotEmpty)
                FilmlyGlassButton(
                  label: '上级目录',
                  icon: Icons.arrow_upward_rounded,
                  onTap: _loading ? null : _goUp,
                ),
              FilmlyGlassButton(
                label: _importing ? '导入中…' : '导入此文件夹',
                icon: _importing ? null : Icons.download_rounded,
                accent: true,
                leading: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _importing ? null : _importCurrentFolder,
              ),
              FilmlyGlassButton(
                label: _allDirectoriesSelected ? '取消全选' : '全选',
                icon: _allDirectoriesSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                onTap: _loading ? null : _toggleSelectAll,
              ),
              FilmlyGlassButton(
                label: '断开',
                icon: Icons.link_off_rounded,
                onTap: _disconnect,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF6B7D), fontSize: 13),
            ),
          if (_selectedPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SelectionImportPanel(
              count: _selectedPaths.length,
              importing: _importing,
              onImport: _importSelected,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                ? const Center(
                    child: Text(
                      '此目录为空',
                      style: TextStyle(color: FilmlyPalette.textMuted),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _entryTile(_entries[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(WebDavEntry entry) {
    final isVideo = !entry.isDir && _isVideo(entry.name);
    final tappable = entry.isDir || isVideo;
    final icon = entry.isDir
        ? Icons.folder_rounded
        : (isVideo ? Icons.movie_rounded : Icons.insert_drive_file_rounded);
    final color = entry.isDir
        ? const Color(0xFF9D8CFF)
        : (isVideo ? const Color(0xFF66A3FF) : FilmlyPalette.textMuted);

    return Opacity(
      opacity: tappable ? 1 : 0.5,
      child: GestureDetector(
        onTap: tappable ? () => _onTapEntry(entry) : null,
        child: FilmlyGlassPanel(
          borderRadius: BorderRadius.circular(18),
          color: FilmlyPalette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FilmlyPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (entry.isDir)
                Checkbox.adaptive(
                  value: _selectedPaths.contains(entry.path),
                  onChanged: (value) => _toggleSelection(entry, value == true),
                  activeColor: FilmlyPalette.accent,
                )
              else if (isVideo)
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: FilmlyPalette.textSecondary,
                  size: 20,
                ),
              if (entry.isDir)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FilmlyPalette.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FilmlyPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        FilmlyGlassPanel(
          borderRadius: BorderRadius.circular(14),
          color: FilmlyPalette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 15,
            ),
            cursorColor: FilmlyPalette.accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 15,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
