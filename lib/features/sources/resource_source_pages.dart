import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../data/models/app_config.dart';
import '../../data/models/resource_source.dart';
import '../../providers/data_providers.dart';
import '../../widgets/filmly_design.dart';

/// The source picker deliberately separates available integrations from the
/// saved sources shown on [SourcesPage]. It gives mobile users the same clear
/// grouped flow as the reference app, while desktop keeps the form centered.
class AddResourceSourcePage extends StatelessWidget {
  const AddResourceSourcePage({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sources');
    }
  }

  void _openEditor(BuildContext context, ResourceSourceType type) {
    context.go(
      Uri(
        path: '/sources/edit',
        queryParameters: {'type': type.name},
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformCapabilities.isMobile;
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isMobile ? 20 : 36,
                isMobile ? 18 : 28,
                isMobile ? 20 : 36,
                40,
              ),
              children: [
                _PageHeader(title: '添加新文件源', onBack: () => _back(context)),
                const SizedBox(height: 28),
                _SourceSection(
                  title: '发现可用资源',
                  children: [
                    _SourceOptionTile(
                      icon: Icons.cloud_download_rounded,
                      title: '中国移动云盘',
                      badge: '领流量',
                      enabled: false,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SourceSection(
                  title: '本地存储',
                  children: [
                    _SourceOptionTile(
                      icon: Icons.folder_copy_rounded,
                      title: '本地目录',
                      subtitle: '浏览设备或电脑上的文件夹',
                      onTap: () => context.go('/sources/local'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SourceSection(
                  title: '网络存储',
                  children: [
                    _SourceOptionTile(
                      key: const Key('source_card_webdav'),
                      icon: Icons.cloud_queue_rounded,
                      title: 'WebDAV',
                      subtitle: '连接 WebDAV 服务或 NAS',
                      onTap: () =>
                          _openEditor(context, ResourceSourceType.webdav),
                    ),
                    _SourceOptionTile(
                      key: const Key('source_card_smb'),
                      icon: Icons.storage_rounded,
                      title: 'SMB',
                      subtitle: '连接局域网共享文件夹',
                      onTap: () => _openEditor(context, ResourceSourceType.smb),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SourceSection(
                  title: '媒体服务器',
                  children: [
                    _SourceOptionTile(
                      key: const Key('source_card_emby'),
                      icon: Icons.ondemand_video_rounded,
                      title: 'Emby',
                      subtitle: '同步媒体服务器中的影片',
                      onTap: () =>
                          _openEditor(context, ResourceSourceType.emby),
                    ),
                    _SourceOptionTile(
                      key: const Key('source_card_jellyfin'),
                      icon: Icons.live_tv_rounded,
                      title: 'Jellyfin',
                      subtitle: '兼容 Jellyfin 服务',
                      onTap: () =>
                          _openEditor(context, ResourceSourceType.jellyfin),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SourceSection(
                  title: '云盘',
                  children: [
                    for (final item in const [
                      ('百度网盘', ''),
                      ('115 网盘', '超高清'),
                      ('光鸣云盘', 'New'),
                      ('天翼云盘', '领会员'),
                      ('阿里云盘', ''),
                      ('123 云盘', '不限速'),
                    ])
                      _SourceOptionTile(
                        icon: Icons.cloud_rounded,
                        title: item.$1,
                        badge: item.$2.isEmpty ? null : item.$2,
                        enabled: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared editor for the connection types that use the same small set of
/// fields. The browser pages remain the actual connection/test surface; this
/// page only persists a source so it can be reused from either platform.
class ResourceSourceEditorPage extends ConsumerStatefulWidget {
  const ResourceSourceEditorPage({
    super.key,
    required this.type,
    this.sourceId,
  });

  final ResourceSourceType type;
  final String? sourceId;

  @override
  ConsumerState<ResourceSourceEditorPage> createState() =>
      _ResourceSourceEditorPageState();
}

class _ResourceSourceEditorPageState
    extends ConsumerState<ResourceSourceEditorPage> {
  final _nameCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pathCtrl = TextEditingController();

  String _protocol = 'https';
  bool _prefilled = false;
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  bool get _isWebDav => widget.type == ResourceSourceType.webdav;
  bool get _isNetwork => _isWebDav || widget.type == ResourceSourceType.smb;
  bool get _isServer =>
      widget.type == ResourceSourceType.emby ||
      widget.type == ResourceSourceType.jellyfin;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _endpointCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  ResourceSource? _sourceFromConfig(AppConfig config) {
    final sourceId = widget.sourceId;
    if (sourceId == null) return null;
    for (final source in config.resourceSources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }

  void _prefill(AppConfig config) {
    if (_prefilled) return;
    _prefilled = true;
    final source = _sourceFromConfig(config);
    if (source != null) {
      _nameCtrl.text = source.name;
      _endpointCtrl.text = source.endpoint;
      _portCtrl.text = source.port;
      _userCtrl.text = source.username;
      _passCtrl.text = source.password;
      _pathCtrl.text = source.path == '/' ? '' : source.path;
      _protocol = source.protocol.isEmpty ? 'https' : source.protocol;
      return;
    }

    _nameCtrl.text = widget.type.label == 'SMB'
        ? '我的 SMB'
        : '我的 ${widget.type.label}';
    if (_isWebDav) {
      _protocol = 'http';
      _portCtrl.text = '80';
      _endpointCtrl.text = config.webdavUrl;
      _userCtrl.text = config.webdavUsername;
      _passCtrl.text = config.webdavPassword;
    } else if (widget.type == ResourceSourceType.smb) {
      _portCtrl.text = '445';
      _endpointCtrl.text = config.smbHost;
      _userCtrl.text = config.smbUsername;
      _passCtrl.text = config.smbPassword;
      _pathCtrl.text = config.smbShare;
    } else {
      _endpointCtrl.text = config.embyUrl;
      _userCtrl.text = config.embyUsername;
      _passCtrl.text = config.embyPassword;
    }
  }

  Future<void> _smartPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final uri = Uri.tryParse(text);
    setState(() {
      if (_isWebDav && uri != null && uri.hasScheme) {
        _protocol = uri.scheme;
        _endpointCtrl.text = uri.host.isEmpty ? text : uri.host;
        if (uri.hasPort) _portCtrl.text = uri.port.toString();
        _pathCtrl.text = uri.path == '/' ? '' : uri.path;
      } else {
        _endpointCtrl.text = text;
      }
    });
  }

  String _webDavUrl() {
    var value = _endpointCtrl.text.trim();
    if (value.isEmpty) return '';
    if (!value.contains('://')) value = '$_protocol://$value';
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    final port = int.tryParse(_portCtrl.text.trim());
    var next = uri;
    if (port != null && port > 0 && !uri.hasPort) {
      next = next.replace(port: port);
    }
    final path = _pathCtrl.text.trim();
    if (path.isNotEmpty && path != '/' && next.path == '/') {
      next = next.replace(path: path.startsWith('/') ? path : '/$path');
    }
    return next.toString();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final endpoint = _isWebDav ? _webDavUrl() : _endpointCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入文件源名称');
      return;
    }
    if (endpoint.isEmpty) {
      setState(() => _error = '请输入地址');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final config = await ref.read(configProvider.future);
      final existing = _sourceFromConfig(config);
      final source = ResourceSource(
        id: existing?.id ?? ResourceSource.newId(widget.type),
        name: name,
        type: widget.type,
        endpoint: endpoint,
        protocol: _isWebDav ? _protocol : 'https',
        port: _portCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        path: _pathCtrl.text.trim().isEmpty ? '/' : _pathCtrl.text.trim(),
        importedPaths: existing?.importedPaths ?? const [],
      );
      final sources = [...config.resourceSources];
      final index = sources.indexWhere((item) => item.id == source.id);
      if (index >= 0) {
        sources[index] = source;
      } else {
        sources.add(source);
      }

      var next = config.copyWith(resourceSources: sources);
      if (_isWebDav) {
        next = next.copyWith(
          webdavUrl: endpoint,
          webdavUsername: source.username,
          webdavPassword: source.password,
        );
      } else if (widget.type == ResourceSourceType.smb) {
        next = next.copyWith(
          smbHost: source.endpoint,
          smbUsername: source.username.isEmpty ? 'guest' : source.username,
          smbPassword: source.password,
          smbShare: source.path == '/' ? '' : source.path,
        );
      } else {
        next = next.copyWith(
          embyUrl: endpoint,
          embyUsername: source.username,
          embyPassword: source.password,
        );
      }
      await ref.read(configProvider.notifier).save(next);
      if (!mounted) return;
      context.go('/sources');
    } catch (e) {
      if (mounted) setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/sources/add');
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);
    if (configAsync.hasValue) _prefill(configAsync.value!);
    final isMobile = PlatformCapabilities.isMobile;
    final title = '添加 ${widget.type.label}';
    return Scaffold(
      backgroundColor: FilmlyPalette.background,
      body: SafeArea(
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('加载配置失败：$error')),
          data: (_) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 20 : 36,
                  isMobile ? 18 : 28,
                  isMobile ? 20 : 36,
                  36,
                ),
                children: [
                  _PageHeader(title: title, onBack: _back),
                  const SizedBox(height: 26),
                  _editorCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilmlyGlassButton(
                    key: const Key('resource_source_save_button'),
                    label: _saving ? '保存中…' : '确认添加',
                    icon: _saving ? null : Icons.check_rounded,
                    accent: true,
                    leading: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : null,
                    onTap: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editorCard() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FilmlyPalette.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          children: [
            _ResourceField(
              key: const Key('resource_source_name_input'),
              label: '名称',
              controller: _nameCtrl,
              hint: '例如：我的 NAS',
            ),
            if (_isWebDav) ...[const SizedBox(height: 14), _protocolField()],
            const SizedBox(height: 14),
            _ResourceField(
              key: ValueKey(
                _isWebDav ? 'webdav_address_input' : 'smb_host_input',
              ),
              label: '地址',
              controller: _endpointCtrl,
              hint: _isWebDav ? '请输入 IP 或域名' : '请输入 NAS IP 或域名',
            ),
            if (_isWebDav || _isNetwork) ...[
              const SizedBox(height: 14),
              _ResourceField(
                key: ValueKey(
                  _isWebDav ? 'webdav_port_input' : 'smb_port_input',
                ),
                label: '端口',
                controller: _portCtrl,
                hint: _isWebDav ? '80' : '445',
                keyboardType: TextInputType.number,
              ),
            ],
            if (_isNetwork || _isServer) ...[
              const SizedBox(height: 14),
              _ResourceField(label: '用户名', controller: _userCtrl, hint: '选填'),
              const SizedBox(height: 14),
              _ResourceField(
                label: '密码',
                controller: _passCtrl,
                hint: '选填',
                obscureText: _obscure,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: FilmlyPalette.textMuted,
                  ),
                ),
              ),
            ],
            if (_isNetwork) ...[
              const SizedBox(height: 14),
              _ResourceField(
                key: const Key('resource_source_path_input'),
                label: '路径',
                controller: _pathCtrl,
                hint: _isWebDav ? '选填，例如：/dav' : '选填，例如：/media',
              ),
            ],
            if (_isNetwork) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _smartPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('智能粘贴'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _protocolField() {
    return InputDecorator(
      decoration: _inputDecoration('协议'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _protocol,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'http', child: Text('HTTP')),
            DropdownMenuItem(value: 'https', child: Text('HTTPS')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _protocol = value);
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: const TextStyle(
      color: FilmlyPalette.textSecondary,
      fontSize: 13,
    ),
    filled: true,
    fillColor: FilmlyPalette.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.fromLTRB(14, 19, 14, 12),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformCapabilities.isMobile;
    return Row(
      children: [
        FilmlyIconButton(
          key: const Key('resource_page_back_button'),
          icon: Icons.chevron_left_rounded,
          size: isMobile ? 44 : 40,
          radius: isMobile ? 22 : 13,
          onTap: onBack,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FilmlyPalette.textPrimary,
              fontSize: isMobile ? 22 : 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(width: isMobile ? 44 : 40),
      ],
    );
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) result.add(const Divider(height: 1, indent: 72));
      result.add(children[index]);
    }
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
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FilmlyPalette.divider),
          ),
          child: Column(children: result),
        ),
      ],
    );
  }
}

class _SourceOptionTile extends StatelessWidget {
  const _SourceOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 13, 14, 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEBFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FilmlyPalette.accent, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FilmlyPalette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          _Badge(text: badge!),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: FilmlyPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                active
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: FilmlyPalette.textMuted,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceField extends StatelessWidget {
  const _ResourceField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: FilmlyPalette.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: FilmlyPalette.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: FilmlyPalette.textMuted,
          fontSize: 15,
        ),
        filled: true,
        fillColor: FilmlyPalette.background,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.fromLTRB(14, 19, 14, 12),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0DF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE69748),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
