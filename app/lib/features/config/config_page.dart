import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_config.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';

/// Apple-styled settings page grouped into: library scan, metadata APIs,
/// network sources, and cache management. Persisted via [configProvider].
class ConfigPage extends ConsumerStatefulWidget {
  const ConfigPage({super.key});

  @override
  ConsumerState<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends ConsumerState<ConfigPage> {
  final _host = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _domain = TextEditingController();
  final _share = TextEditingController();
  final _tmdb = TextEditingController();
  final _gemini = TextEditingController();
  final _folders = TextEditingController();

  bool _filled = false;
  bool _obscurePass = true;
  bool _saving = false;
  bool _scanning = false;
  bool _clearingCache = false;
  bool _autoScan = true;

  @override
  void dispose() {
    for (final c in [
      _host,
      _username,
      _password,
      _domain,
      _share,
      _tmdb,
      _gemini,
      _folders,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(AppConfig c) {
    if (_filled) return;
    _host.text = c.smbHost;
    _username.text = c.smbUsername;
    _password.text = c.smbPassword;
    _domain.text = c.smbDomain;
    _share.text = c.smbShare;
    _tmdb.text = c.tmdbApiKey;
    _gemini.text = c.geminiApiKey;
    _folders.text = c.selectedFolders.join('\n');
    _autoScan = c.autoScanOnStartup;
    _filled = true;
  }

  AppConfig _buildConfig(AppConfig base) {
    final username = _username.text.trim();
    final folders = _folders.text
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);

    return base.copyWith(
      smbHost: _host.text.trim(),
      smbUsername: username.isEmpty ? 'guest' : username,
      smbPassword: _password.text,
      smbDomain: _domain.text.trim(),
      smbShare: _share.text.trim(),
      selectedFolders: folders,
      tmdbApiKey: _tmdb.text.trim(),
      geminiApiKey: _gemini.text.trim(),
      autoScanOnStartup: _autoScan,
    );
  }

  Future<void> _save() async {
    final base = ref.read(configProvider).asData?.value ?? const AppConfig();
    setState(() => _saving = true);
    try {
      await ref.read(configProvider.notifier).save(_buildConfig(base));
      _showSnack('设置已保存');
    } catch (e) {
      _showSnack('保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanLibrary() async {
    final base = ref.read(configProvider).asData?.value ?? const AppConfig();
    final config = _buildConfig(base);
    if (config.selectedFolders.isEmpty) {
      _showSnack('请先填写至少一个扫描目录');
      return;
    }

    setState(() => _scanning = true);
    try {
      await ref.read(configProvider.notifier).save(config);
      final result = await ref
          .read(libraryScannerProvider)
          .scanFolders(config.selectedFolders);
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

      invalidateLibraryViews(ref);

      final folderNote = result.missingFolders == 0
          ? ''
          : '，${result.missingFolders} 个目录不存在';
      _showSnack(
        '扫描完成：导入 ${result.importedItems} 个媒体'
        '（电影 ${result.movieCount} / 剧集 ${result.tvCount}）'
        '$folderNote$metadataMessage',
      );
    } catch (e) {
      _showSnack('扫描失败：$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _clearImageCache() async {
    setState(() => _clearingCache = true);
    try {
      await CachedNetworkImage.evictFromCache('');
      await DefaultCacheManager().emptyCache();
      _showSnack('海报缓存已清除');
    } catch (e) {
      _showSnack('清除缓存失败：$e');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(configProvider);
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              '加载配置失败：$e',
              style: const TextStyle(color: FilmlyPalette.textSecondary),
            ),
          ),
          data: (config) {
            _fill(config);
            return _body(context);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
          children: [
            FilmlyInlineHeader(
              leading: FilmlyIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              title: '设置',
              subtitle: '管理媒体库、元数据来源与缓存。',
            ),
            const SizedBox(height: 28),
            _section(
              title: '媒体库',
              children: [
                _field(
                  _folders,
                  '扫描目录（每行一个）',
                  hint: '/Volumes/Media/Movies\n/Volumes/Media/TV',
                  maxLines: 4,
                ),
                _toggleRow(
                  title: '启动时自动扫描',
                  subtitle: '打开应用时增量扫描已配置目录并补全元数据',
                  value: _autoScan,
                  onChanged: (v) => setState(() => _autoScan = v),
                ),
                const SizedBox(height: 4),
                FilmlyGlassButton(
                  label: _scanning ? '扫描中…' : '保存并扫描目录',
                  icon: _scanning ? null : Icons.manage_search_rounded,
                  accent: true,
                  leading: _scanning ? _spinner() : null,
                  onTap: _scanning ? null : _scanLibrary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _section(
              title: '元数据 API',
              children: [
                _field(_tmdb, 'TMDB API Key', hint: '用于抓取海报、评分、简介'),
                _field(_gemini, 'Gemini API Key（可选）', hint: '用于 AI 智能识别文件名'),
              ],
            ),
            const SizedBox(height: 24),
            _section(
              title: 'NAS / SMB 默认连接',
              children: [
                _field(_host, '主机地址', hint: '192.168.1.100'),
                _field(_username, '用户名'),
                _field(
                  _password,
                  '密码',
                  obscure: _obscurePass,
                  onToggleObscure: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
                _field(_domain, '域 / 工作组（可选）', hint: 'WORKGROUP'),
                _field(_share, '默认共享（可选）'),
              ],
            ),
            const SizedBox(height: 24),
            _section(
              title: '缓存管理',
              children: [
                _actionRow(
                  title: '清除海报缓存',
                  subtitle: '删除本地缓存的海报图片，下次将重新下载',
                  busy: _clearingCache,
                  buttonLabel: '清除',
                  onTap: _clearImageCache,
                ),
              ],
            ),
            const SizedBox(height: 28),
            FilmlyGlassButton(
              label: _saving ? '保存中…' : '保存设置',
              icon: _saving ? null : Icons.check_rounded,
              accent: true,
              leading: _saving ? _spinner() : null,
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: FilmlyPalette.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        FilmlyGlassPanel(
          borderRadius: BorderRadius.circular(22),
          color: FilmlyPalette.surface,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
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
          Container(
            decoration: BoxDecoration(
              color: FilmlyPalette.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: controller,
              obscureText: obscure,
              minLines: maxLines > 1 ? maxLines : null,
              maxLines: maxLines,
              style: const TextStyle(
                color: FilmlyPalette.textPrimary,
                fontSize: 15,
              ),
              cursorColor: FilmlyPalette.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: onToggleObscure == null
                    ? null
                    : IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: FilmlyPalette.textMuted,
                          size: 20,
                        ),
                        onPressed: onToggleObscure,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FilmlyPalette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FilmlyPalette.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: FilmlyPalette.accent,
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String title,
    required String subtitle,
    required bool busy,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FilmlyPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FilmlyPalette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilmlyGlassButton(
          label: busy ? '清除中…' : buttonLabel,
          leading: busy ? _spinner() : null,
          onTap: busy ? null : onTap,
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
