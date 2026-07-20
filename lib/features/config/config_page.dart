import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/image/filmly_image_cache.dart';
import '../../data/models/app_config.dart';
import '../../providers/data_providers.dart';
import '../../services/data/database_transfer_service.dart';
import '../../data/intelligence/intelligence_models.dart';
import '../../providers/intelligence_providers.dart';
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
  final _aiWorker = TextEditingController();
  final _aiModelDirectory = TextEditingController();
  final _aiIndexDirectory = TextEditingController();
  final _aiModel = TextEditingController();
  final _aiTargetLanguage = TextEditingController();

  bool _filled = false;
  bool _obscurePass = true;
  bool _saving = false;
  bool _scanning = false;
  bool _clearingCache = false;
  bool _transferring = false;
  bool _aiWorking = false;
  bool _autoScan = true;
  bool _aiAllowRemoteText = false;
  bool _aiMemoryEnabled = true;

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
      _aiWorker,
      _aiModelDirectory,
      _aiIndexDirectory,
      _aiModel,
      _aiTargetLanguage,
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
    _aiWorker.text = c.aiWorkerPath;
    _aiModelDirectory.text = c.aiModelDirectory;
    _aiIndexDirectory.text = c.aiIndexDirectory;
    _aiModel.text = c.aiModel;
    _aiTargetLanguage.text = c.aiTargetLanguage;
    _aiAllowRemoteText = c.aiAllowRemoteText;
    _aiMemoryEnabled = c.aiMemoryEnabled;
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
      aiWorkerPath: _aiWorker.text.trim(),
      aiModelDirectory: _aiModelDirectory.text.trim(),
      aiIndexDirectory: _aiIndexDirectory.text.trim(),
      aiModel: _aiModel.text.trim().isEmpty ? 'tiny' : _aiModel.text.trim(),
      aiTargetLanguage: _aiTargetLanguage.text.trim().isEmpty
          ? 'zh-CN'
          : _aiTargetLanguage.text.trim(),
      aiAllowRemoteText: _aiAllowRemoteText,
      aiMemoryEnabled: _aiMemoryEnabled,
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
      await FilmlyImageCache.emptyCache();
      _showSnack('海报缓存已清除');
    } catch (e) {
      _showSnack('清除缓存失败：$e');
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _generateAiSubtitle() async {
    if (_aiWorking) return;
    const videoGroup = XTypeGroup(
      label: '视频文件',
      extensions: ['mkv', 'mp4', 'mov', 'm4v', 'avi', 'webm', 'ts', 'm2ts'],
    );
    final selected = await openFile(acceptedTypeGroups: const [videoGroup]);
    if (selected == null || !mounted) return;
    final config = ref.read(configProvider).asData?.value ?? const AppConfig();
    if (config.aiWorkerPath.trim().isEmpty) {
      _showSnack('请先填写本地 Worker 路径');
      return;
    }

    setState(() => _aiWorking = true);
    try {
      final service = await ref.read(mediaIntelligenceServiceProvider.future);
      if (service == null) throw StateError('本地 AI Worker 未配置');
      final result = await service.generateSubtitlesForLocalFile(
        path: selected.path,
        model: config.aiModel,
        sourceLanguage: 'auto',
        targetLanguage: config.aiTargetLanguage,
        outputDirectory: config.aiIndexDirectory.trim().isEmpty
            ? null
            : Directory(p.join(config.aiIndexDirectory.trim(), 'subtitles')),
        force: true,
      );
      _showSnack(
        result.translationJob?.status == AiJobStatus.failed
            ? 'AI 转录完成，翻译不可用，已生成原语言 SRT/VTT 字幕'
            : result.translated
            ? 'AI 字幕已生成（SRT/VTT），可在播放器字幕菜单中选择'
            : 'AI 转录完成，已生成原语言 SRT/VTT 字幕',
      );
    } catch (error) {
      _showSnack('AI 转录失败：$error');
    } finally {
      if (mounted) setState(() => _aiWorking = false);
    }
  }

  Future<void> _exportDatabase() async {
    if (_transferring) return;
    final location = await getSaveLocation(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Open Filmly 数据库', extensions: ['sqlite']),
      ],
      suggestedName: 'open_filmly-backup.sqlite',
      confirmButtonText: '导出',
    );
    final path = location?.path;
    if (path == null || path.isEmpty || !mounted) return;

    setState(() => _transferring = true);
    try {
      final file = await DatabaseTransferService(
        ref.read(databaseProvider),
      ).exportToPath(path);
      _showSnack('已导出数据库：${p.basename(file.path)}');
    } catch (e) {
      _showSnack('导出失败：$e');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importDatabase() async {
    if (_transferring) return;
    final stagedPath = await _stagedMigrationPath();
    final selected = stagedPath == null
        ? await openFile(
            acceptedTypeGroups: const [
              XTypeGroup(
                label: 'Open Filmly 数据库',
                extensions: ['sqlite', 'db'],
              ),
            ],
            confirmButtonText: '选择',
          )
        : null;
    final path = stagedPath ?? selected?.path;
    if (path == null || path.isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入媒体库数据？'),
        content: Text(
          stagedPath == null
              ? '将把 ${p.basename(path)} 合并到当前设备。当前数据不会被删除，同一媒体的收藏会保留，播放进度取较新的记录。'
              : '检测到从电脑放入的 Open Filmly 数据库，将合并导入当前设备。当前数据不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('开始导入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _transferring = true);
    try {
      final documents = await getApplicationDocumentsDirectory();
      final backupPath = p.join(
        documents.path,
        'open_filmly-before-import-${DateTime.now().millisecondsSinceEpoch}.sqlite',
      );
      final transfer = DatabaseTransferService(ref.read(databaseProvider));
      await transfer.exportToPath(backupPath);
      final result = await transfer.importFromPath(path);
      if (stagedPath != null) await File(stagedPath).delete();

      _filled = false;
      ref.invalidate(configProvider);
      invalidateLibraryViews(ref);
      _showSnack(
        '导入完成：媒体 ${result.mediaRows} 条，剧集 ${result.episodeRows} 条；当前数据备份已保存在 App 文档目录。',
      );
    } catch (e) {
      _showSnack('导入失败：$e');
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<String?> _stagedMigrationPath() async {
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, 'open_filmly-macos.sqlite'));
    return await file.exists() ? file.path : null;
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'API 设置可以单独保存，不需要先填写扫描目录。',
                    style: TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
                FilmlyGlassButton(
                  label: _saving ? '保存中…' : '保存元数据设置',
                  icon: _saving ? null : Icons.save_outlined,
                  leading: _saving ? _spinner() : null,
                  onTap: _saving ? null : _save,
                ),
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
              title: 'AI 媒体理解',
              children: [
                _field(
                  _aiWorker,
                  '本地 Worker 路径（可选）',
                  hint: '/Applications/Open Filmly.app/.../ai-worker',
                ),
                _field(
                  _aiModelDirectory,
                  '本地模型目录（可选）',
                  hint: '/Users/你/Models',
                ),
                _field(_aiModel, '默认模型', hint: 'tiny'),
                _field(_aiTargetLanguage, '字幕目标语言', hint: 'zh-CN'),
                _field(_aiIndexDirectory, 'AI 索引目录（可选）', hint: '留空使用应用支持目录'),
                _toggleRow(
                  title: '允许云端处理文本片段',
                  subtitle: '默认关闭；不会自动上传视频文件',
                  value: _aiAllowRemoteText,
                  onChanged: (value) =>
                      setState(() => _aiAllowRemoteText = value),
                ),
                _toggleRow(
                  title: '记录本地观看记忆',
                  subtitle: '用于观看回顾和本地推荐；关闭后不再写入观看事件',
                  value: _aiMemoryEnabled,
                  onChanged: (value) =>
                      setState(() => _aiMemoryEnabled = value),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    'AI 索引与媒体库数据库分开保存，删除或重建 AI 索引不会影响媒体、收藏和播放进度。',
                    style: TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
                FilmlyGlassButton(
                  label: _saving ? '保存中…' : '保存 AI 设置',
                  icon: _saving ? null : Icons.auto_awesome_outlined,
                  leading: _saving ? _spinner() : null,
                  onTap: _saving ? null : _save,
                ),
                const SizedBox(height: 10),
                FilmlyGlassButton(
                  label: _aiWorking ? 'AI 转录中…' : '选择视频生成 AI 字幕',
                  icon: _aiWorking ? null : Icons.subtitles_outlined,
                  leading: _aiWorking ? _spinner() : null,
                  onTap: _aiWorking ? null : _generateAiSubtitle,
                ),
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
            const SizedBox(height: 24),
            _section(
              title: '数据迁移',
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    '覆盖安装不会自动复制其他设备的数据。导出数据库后，可通过 AirDrop、文件共享或“文件”App 放到另一台设备再导入。导入前会自动备份当前设备数据。',
                    style: TextStyle(
                      color: FilmlyPalette.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                FilmlyGlassButton(
                  label: _transferring ? '处理中…' : '导入数据库',
                  icon: _transferring ? null : Icons.file_download_outlined,
                  leading: _transferring ? _spinner() : null,
                  onTap: _transferring ? null : _importDatabase,
                ),
                const SizedBox(height: 10),
                FilmlyGlassButton(
                  label: _transferring ? '处理中…' : '导出数据库',
                  icon: _transferring ? null : Icons.file_upload_outlined,
                  leading: _transferring ? _spinner() : null,
                  onTap: _transferring ? null : _exportDatabase,
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
