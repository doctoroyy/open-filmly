import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smb_connect/smb_connect.dart';

import '../../data/models/app_config.dart';
import '../../data/models/media.dart';
import '../../providers/data_providers.dart';
import '../../providers/smb_providers.dart';
import '../../services/playback/external_subtitle_finder.dart';
import '../../services/playback/playback_source_resolver.dart';
import '../../services/smb/smb_proxy_server.dart';
import '../../services/smb/smb_service.dart';
import '../../widgets/filmly_design.dart';
import '../player/player_page.dart';

/// M2 developer-facing SMB browser: connect to a NAS, walk shares and folders,
/// and tap a video to stream it through the local proxy into the player.
///
/// This is the validation surface for the most critical migration risk —
/// SMB random-read → HTTP Range proxy → libmpv seekable playback. It is
/// replaced by the proper config + library flow in M3.
class SmbBrowserPage extends ConsumerStatefulWidget {
  const SmbBrowserPage({super.key});

  @override
  ConsumerState<SmbBrowserPage> createState() => _SmbBrowserPageState();
}

class _SmbBrowserPageState extends ConsumerState<SmbBrowserPage> {
  static const _videoExts = {
    '.mkv',
    '.mp4',
    '.avi',
    '.mov',
    '.wmv',
    '.flv',
    '.webm',
    '.m4v',
    '.mpg',
    '.mpeg',
    '.ts',
    '.m2ts',
    '.rmvb',
    '.rm',
    '.vob',
    '.iso',
  };

  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'guest');
  final _passCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _shareCtrl = TextEditingController();

  bool _connecting = false;
  bool _connected = false;
  bool _prefilled = false;
  bool _loading = false;
  bool _importing = false;
  String? _error;

  /// Current directory path as a stack of folders; empty means the share list.
  final List<SmbFile> _stack = [];
  List<SmbFile> _entries = [];

  SmbService get _smb => ref.read(smbServiceProvider);
  SmbProxyServer get _proxy => ref.read(smbProxyProvider);
  SmbFile? get _currentFolder => _stack.isEmpty ? null : _stack.last;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _domainCtrl.dispose();
    _shareCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = '请输入 NAS 主机地址');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final user = _userCtrl.text.trim();
      await _smb.connect(
        SmbConfig(
          host: host,
          username: user.isEmpty ? 'guest' : user,
          password: _passCtrl.text,
          domain: _domainCtrl.text.trim(),
        ),
      );
      await _proxy.start();
      if (!mounted) return;
      setState(() => _connected = true);

      // Auto-persist connection details to local database configuration
      final currentConfig = ref.read(configProvider).value ?? const AppConfig();
      final newConfig = currentConfig.copyWith(
        smbHost: host,
        smbUsername: user.isEmpty ? 'guest' : user,
        smbPassword: _passCtrl.text,
        smbDomain: _domainCtrl.text.trim(),
        smbShare: _shareCtrl.text.trim(),
      );
      // Persist credentials best-effort; connection already succeeded.
      try {
        await ref.read(configProvider.notifier).save(newConfig);
      } catch (_) {
        // ignore persistence failures
      }
      // If the user configured a share, open it directly (avoids relying on
      // srvsvc share enumeration, which some NAS servers don't expose).
      final share = _shareCtrl.text.trim();
      if (share.isNotEmpty) {
        await _openShareByName(share);
      } else {
        await _loadShares();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await _smb.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _entries = [];
      _stack.clear();
      _error = null;
    });
  }

  Future<void> _importCurrentFolder() async {
    final folder = _currentFolder;
    if (folder == null) return;

    setState(() => _importing = true);
    try {
      final result = await ref
          .read(smbLibraryImportProvider)
          .importFolder(folder);
      final config = await ref.read(configProvider.future);
      var metadataMessage = '';
      if (config.tmdbApiKey.isNotEmpty && result.mediaIds.isNotEmpty) {
        final metadataResult = await ref
            .read(libraryMetadataSyncProvider)
            .enrichByIds(
              mediaIds: result.mediaIds,
              apiKey: config.tmdbApiKey,
              geminiApiKey: config.geminiApiKey,
            );
        metadataMessage =
            '，元数据更新 ${metadataResult.updatedItems}/${metadataResult.requestedItems}';
      }
      ref.invalidate(libraryCountsProvider);
      ref.invalidate(recentMediaProvider);
      for (final type in MediaType.values) {
        ref.invalidate(mediaLibraryProvider(type));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导入 ${result.importedItems} 个媒体（电影 ${result.movieCount} / 剧集 ${result.tvCount}）$metadataMessage',
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

  /// Loads the share list: tries srvsvc enumeration, and if that's empty or
  /// unsupported, auto-probes common NAS share names so browsing just works.
  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var shares = <SmbFile>[];
      try {
        shares = await _smb.listShares();
      } catch (e) {
        // Enumeration unsupported on this server — fall through to discovery.
      }
      if (shares.isEmpty) {
        shares = await _smb.discoverShares(extra: [_shareCtrl.text]);
      }
      if (!mounted) return;
      setState(() {
        _stack.clear();
        _entries = _sorted(shares);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '读取共享失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens a share (or sub-path) by name directly, bypassing srvsvc share
  /// enumeration — which many NAS servers don't expose. The opened folder
  /// becomes the new browse root.
  Future<void> _openShareByName(String raw) async {
    final name = raw.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    if (name.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folder = await _smb.openFolder('/$name');
      final children = await _smb.listChildren(folder);
      if (!mounted) return;
      setState(() {
        _stack
          ..clear()
          ..add(folder);
        _entries = _sorted(children);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '打开共享失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enter(SmbFile folder) =>
      _load(() => _smb.listChildrenByPath(folder.path), push: folder);

  Future<void> _up() {
    if (_stack.isEmpty) return Future.value();
    _stack.removeLast();
    return _stack.isEmpty
        ? _loadShares()
        : _load(() => _smb.listChildrenByPath(_stack.last.path));
  }

  /// Shared loader: runs [fetch], sorts results, and manages loading/error.
  Future<void> _load(
    Future<List<SmbFile>> Function() fetch, {
    SmbFile? push,
    bool resetStack = false,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await fetch();
      if (!mounted) return;
      setState(() {
        if (resetStack) _stack.clear();
        if (push != null) _stack.add(push);
        _entries = _sorted(entries);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '读取目录失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onTap(SmbFile entry) {
    // At the share-list level, every entry is a share (its DIRECTORY attribute
    // may be unset when opened via file()), so always enter it.
    // Also, due to Samba quirks, some actual directories may be missing the
    // DIRECTORY attribute. If it's not a recognized video, try treating it as a directory.
    final isVideoFile = _isVideo(entry.name) && entry.size > 0;
    if (_stack.isEmpty || entry.isDirectory() || !isVideoFile) {
      _enter(entry);
    } else if (isVideoFile) {
      final url = _proxy.urlFor(entry.path, displayName: entry.name);
      final subtitles =
          ExternalSubtitleFinder.findAmongSiblings(
                entry.path,
                _entries
                    .where((item) => !item.isDirectory())
                    .map((item) => item.path),
              )
              .map(
                (subtitle) => PlaybackSubtitleSource(
                  uri: _proxy.urlFor(
                    subtitle.path,
                    displayName: subtitle.path.split('/').last,
                  ),
                  title: subtitle.label,
                  language: subtitle.languageHint,
                ),
              )
              .toList(growable: false);
      context.push(
        '/player',
        extra: PlayerArgs(uri: url, title: entry.name, subtitles: subtitles),
      );
    }
  }

  List<SmbFile> _sorted(List<SmbFile> files) {
    final copy = [...files];
    copy.sort((a, b) {
      final aVideo = _isVideo(a.name) && a.size > 0;
      final bVideo = _isVideo(b.name) && b.size > 0;
      final ad = _stack.isEmpty || a.isDirectory() || !aVideo;
      final bd = _stack.isEmpty || b.isDirectory() || !bVideo;
      if (ad != bd) return ad ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  bool _isVideo(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _videoExts.contains(name.substring(dot).toLowerCase());
  }

  String _fmtSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    // Listen to config changes to prefill fields with state update
    ref.listen<AsyncValue<AppConfig>>(configProvider, (previous, next) {
      if (next.hasValue && !_prefilled && !_connected) {
        final config = next.value!;
        setState(() {
          _hostCtrl.text = config.smbHost;
          if (config.smbUsername.isNotEmpty) {
            _userCtrl.text = config.smbUsername;
          }
          _passCtrl.text = config.smbPassword;
          _domainCtrl.text = config.smbDomain;
          if (config.smbShare.isNotEmpty) _shareCtrl.text = config.smbShare;
          _prefilled = true;
        });
      }
    });

    // Synchronously prefill if the provider is already resolved
    if (!_prefilled && !_connected) {
      final configAsync = ref.watch(configProvider);
      if (configAsync.hasValue) {
        final config = configAsync.value!;
        _hostCtrl.text = config.smbHost;
        if (config.smbUsername.isNotEmpty) _userCtrl.text = config.smbUsername;
        _passCtrl.text = config.smbPassword;
        _domainCtrl.text = config.smbDomain;
        if (config.smbShare.isNotEmpty) _shareCtrl.text = config.smbShare;
        _prefilled = true;
      }
    }

    final crumb = _stack.isEmpty
        ? '共享列表'
        : _stack.map((e) => e.name).join(' / ');

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
                  key: const Key('smb_back_button'),
                  icon: Icons.chevron_left_rounded,
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/sources'),
                ),
                title: 'SMB / NAS',
                subtitle: _connected ? '已连接 · $crumb' : '连接局域网内的 NAS 存储',
                trailing: _connected
                    ? FilmlyIconButton(
                        key: const Key('smb_disconnect_button'),
                        icon: Icons.link_off_rounded,
                        onTap: _disconnect,
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _connected ? _buildBrowser() : _buildConnectForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(
            _hostCtrl,
            '主机地址',
            '192.168.1.100',
            key: const Key('smb_host_input'),
            onSubmit: _connect,
          ),
          const SizedBox(height: 14),
          _field(
            _shareCtrl,
            '共享名（选填，留空自动发现）',
            'Media',
            key: const Key('smb_share_input'),
            onSubmit: _connect,
          ),
          const SizedBox(height: 14),
          _field(
            _userCtrl,
            '用户名',
            'guest',
            key: const Key('smb_user_input'),
            onSubmit: _connect,
          ),
          const SizedBox(height: 14),
          _field(
            _passCtrl,
            '密码',
            '••••••',
            key: const Key('smb_pass_input'),
            obscure: true,
            onSubmit: _connect,
          ),
          const SizedBox(height: 14),
          _field(
            _domainCtrl,
            '域 / 工作组（可选）',
            'WORKGROUP',
            key: const Key('smb_domain_input'),
            onSubmit: _connect,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              key: const Key('smb_error_text'),
              _error!,
              style: const TextStyle(color: Color(0xFFFF6B7D), fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          FilmlyGlassButton(
            key: const Key('smb_connect_button'),
            label: _connecting ? '连接中…' : '连接',
            icon: _connecting ? null : Icons.link_rounded,
            accent: true,
            leading: _connecting ? _spinner() : null,
            onTap: _connecting ? null : _connect,
          ),
        ],
      ),
    );
  }

  Widget _buildBrowser() {
    return Column(
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
                onTap: _loading ? null : _up,
              ),
            if (_currentFolder != null)
              FilmlyGlassButton(
                label: _importing ? '导入中…' : '导入此文件夹',
                icon: _importing ? null : Icons.download_rounded,
                accent: true,
                leading: _importing ? _spinner() : null,
                onTap: _loading || _importing ? null : _importCurrentFolder,
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (_error != null && _stack.isNotEmpty) ...[
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFFF6B7D), fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: _buildEntries()),
      ],
    );
  }

  Widget _buildEntries() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      // Discovery found nothing (or empty folder) — offer direct share entry.
      if (_stack.isEmpty) return _manualShareEntry();
      return const Center(
        child: Text('空目录', style: TextStyle(color: FilmlyPalette.textMuted)),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _entryTile(_entries[index]),
    );
  }

  Widget _entryTile(SmbFile entry) {
    // At the share-list level treat entries as shares (folders).
    // For unknown attributes, if it's not a video, allow tapping it as a potential directory.
    final isVideo = _isVideo(entry.name) && entry.size > 0;
    final isDir = _stack.isEmpty || entry.isDirectory() || !isVideo;
    final tappable = isDir || isVideo;
    final icon = isDir
        ? Icons.folder_rounded
        : (isVideo ? Icons.movie_rounded : Icons.insert_drive_file_rounded);
    final color = isDir
        ? const Color(0xFF62D6B4)
        : (isVideo ? const Color(0xFF66A3FF) : FilmlyPalette.textMuted);

    return Opacity(
      opacity: tappable ? 1 : 0.5,
      child: GestureDetector(
        key: Key('entry_${entry.name}'),
        onTap: tappable ? () => _onTap(entry) : null,
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
                  ),
                ),
              ),
              if (!isDir && entry.size > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _fmtSize(entry.size),
                    style: const TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (isDir)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FilmlyPalette.textSecondary,
                  size: 20,
                )
              else if (isVideo)
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: FilmlyPalette.textSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Last-resort manual share entry, shown only when auto-discovery turns up
  /// nothing (e.g. a custom share name on a server without enumeration).
  Widget _manualShareEntry() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.dns_rounded,
              size: 40,
              color: FilmlyPalette.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              '未自动发现共享',
              style: TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '输入共享名直接打开（在 NAS 设置里可查到，如 Media）。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FilmlyPalette.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _shareCtrl,
                    '',
                    '共享名 / 路径，如 Media',
                    onSubmit: () => _openShareByName(_shareCtrl.text),
                  ),
                ),
                const SizedBox(width: 10),
                FilmlyGlassButton(
                  label: '打开',
                  accent: true,
                  onTap: _loading
                      ? null
                      : () => _openShareByName(_shareCtrl.text),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF6B7D), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    Key? key,
    bool obscure = false,
    VoidCallback? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              color: FilmlyPalette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilmlyGlassPanel(
          borderRadius: BorderRadius.circular(14),
          color: FilmlyPalette.surface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            key: key,
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: 15,
            ),
            cursorColor: FilmlyPalette.accent,
            onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: FilmlyPalette.textMuted,
                fontSize: 15,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
