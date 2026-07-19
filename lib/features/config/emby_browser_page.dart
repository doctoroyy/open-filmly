import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_config.dart';
import '../../data/models/resource_source.dart';
import '../../providers/data_providers.dart';
import '../../providers/smb_providers.dart';
import '../../services/emby/emby_service.dart';
import '../../widgets/filmly_design.dart';

/// Connect to an Emby/Jellyfin server and import its library in one step.
/// Emby content is already organised, so there is no folder browsing — just
/// authenticate and import.
class EmbyBrowserPage extends ConsumerStatefulWidget {
  const EmbyBrowserPage({super.key, this.sourceId});

  final String? sourceId;

  @override
  ConsumerState<EmbyBrowserPage> createState() => _EmbyBrowserPageState();
}

class _EmbyBrowserPageState extends ConsumerState<EmbyBrowserPage> {
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _connecting = false;
  bool _connected = false;
  bool _importing = false;
  bool _prefilled = false;
  String? _error;
  String? _status;

  EmbyService get _emby => ref.read(embyServiceProvider);

  ResourceSource? _sourceFromConfig(AppConfig config) {
    final sourceId = widget.sourceId;
    if (sourceId != null) {
      for (final source in config.resourceSources) {
        if (source.id == sourceId) return source;
      }
    }
    for (final source in config.resourceSources) {
      if (source.type == ResourceSourceType.emby ||
          source.type == ResourceSourceType.jellyfin) {
        return source;
      }
    }
    return null;
  }

  Future<void> _saveSource() async {
    final config = ref.read(configProvider).asData?.value;
    if (config == null) return;
    final existing = _sourceFromConfig(config);
    final source = ResourceSource(
      id:
          existing?.id ??
          widget.sourceId ??
          ResourceSource.newId(ResourceSourceType.emby),
      name:
          existing?.name ?? '我的 ${widget.sourceId == null ? 'Emby' : '媒体服务器'}',
      type: existing?.type ?? ResourceSourceType.emby,
      endpoint: _urlCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      importedPaths: existing?.importedPaths ?? const [],
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
            embyUrl: source.endpoint,
            embyUsername: source.username,
            embyPassword: source.password,
            resourceSources: sources,
          ),
        );
  }

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
    if (_urlCtrl.text.isEmpty) _urlCtrl.text = config.embyUrl;
    if (_userCtrl.text.isEmpty) _userCtrl.text = config.embyUsername;
    if (_passCtrl.text.isEmpty) _passCtrl.text = config.embyPassword;
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入服务器地址');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await _emby.connect(
        EmbyConfig(
          url: url,
          username: _userCtrl.text.trim(),
          password: _passCtrl.text,
        ),
      );

      await _saveSource();

      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = '连接成功，可导入媒体库。';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final result = await ref.read(embyLibraryImportProvider).importLibrary();

      final config = ref.read(configProvider).asData?.value;
      var metaMsg = '';
      if (config != null &&
          config.tmdbApiKey.isNotEmpty &&
          result.mediaIds.isNotEmpty) {
        // Emby already supplies posters/overview, so only enrich items that
        // still lack a poster to avoid unnecessary TMDB calls.
        final missing = await ref
            .read(mediaRepositoryProvider)
            .getIdsWithoutPoster();
        final toEnrich = missing.where(result.mediaIds.contains).toList();
        if (toEnrich.isNotEmpty) {
          final meta = await ref
              .read(libraryMetadataSyncProvider)
              .enrichByIds(
                mediaIds: toEnrich,
                apiKey: config.tmdbApiKey,
                geminiApiKey: config.geminiApiKey,
              );
          metaMsg = '，补全元数据 ${meta.updatedItems} 项';
        }
      }

      invalidateLibraryViews(ref);
      if (!mounted) return;
      setState(() {
        _status =
            '导入完成：电影 ${result.movieCount} / 剧集 ${result.tvCount}'
            '（${result.episodeCount} 集）$metaMsg';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
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
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              FilmlyInlineHeader(
                leading: FilmlyIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _goBack,
                ),
                title: 'Emby / Jellyfin',
                subtitle: _connected ? '已连接' : '连接到 Emby 或 Jellyfin 媒体服务器',
              ),
              const SizedBox(height: 24),
              _field(_urlCtrl, '服务器地址', 'http://192.168.1.10:8096'),
              const SizedBox(height: 14),
              _field(_userCtrl, '用户名', 'username'),
              const SizedBox(height: 14),
              _field(_passCtrl, '密码', '••••••', obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B7D),
                    fontSize: 13,
                  ),
                ),
              ],
              if (_status != null) ...[
                const SizedBox(height: 16),
                Text(
                  _status!,
                  style: const TextStyle(
                    color: FilmlyPalette.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilmlyGlassButton(
                    label: _connecting ? '连接中…' : (_connected ? '重新连接' : '连接'),
                    icon: _connecting ? null : Icons.link_rounded,
                    accent: !_connected,
                    leading: _connecting ? _spinner() : null,
                    onTap: _connecting ? null : _connect,
                  ),
                  if (_connected)
                    FilmlyGlassButton(
                      label: _importing ? '导入中…' : '导入媒体库',
                      icon: _importing ? null : Icons.download_rounded,
                      accent: true,
                      leading: _importing ? _spinner() : null,
                      onTap: _importing ? null : _import,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spinner() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

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
