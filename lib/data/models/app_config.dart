import 'resource_source.dart';

/// Persisted application configuration, serialized as JSON under the
/// `app_config` config key. [fromJson] accepts both the new field names and the
/// Electron-era aliases so an exported old config can be imported as-is.

class AppConfig {
  const AppConfig({
    this.smbHost = '',
    this.smbUsername = 'guest',
    this.smbPassword = '',
    this.smbDomain = '',
    this.smbShare = '',
    this.selectedFolders = const [],
    this.tmdbApiKey = '',
    this.geminiApiKey = '',
    this.autoScanOnStartup = true,
    this.webdavUrl = '',
    this.webdavUsername = '',
    this.webdavPassword = '',
    this.embyUrl = '',
    this.embyUsername = '',
    this.embyPassword = '',
    this.resourceSources = const [],
  });

  final String smbHost;
  final String smbUsername;
  final String smbPassword;
  final String smbDomain;
  final String smbShare;
  final List<String> selectedFolders;
  final String tmdbApiKey;
  final String geminiApiKey;
  final bool autoScanOnStartup;
  final String webdavUrl;
  final String webdavUsername;
  final String webdavPassword;
  final String embyUrl;
  final String embyUsername;
  final String embyPassword;
  final List<ResourceSource> resourceSources;

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    final folders = json['selectedFolders'];
    final autoScan = json['autoScanOnStartup'];
    final rawSources = json['resourceSources'];
    final sources = rawSources is List
        ? rawSources
              .whereType<Map>()
              .map(
                (value) =>
                    ResourceSource.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(growable: false)
        : <ResourceSource>[];
    final migratedSources = [...sources];
    if (migratedSources.isEmpty) {
      final webdav = pick(['webdavUrl', 'webdavHost']);
      if (webdav.isNotEmpty) {
        migratedSources.add(
          ResourceSource(
            id: 'legacy-webdav',
            name: '我的 WebDAV',
            type: ResourceSourceType.webdav,
            endpoint: webdav,
            username: pick(['webdavUsername']),
            password: pick(['webdavPassword']),
          ),
        );
      }
      final smb = pick(['smbHost', 'host', 'ip']);
      if (smb.isNotEmpty) {
        migratedSources.add(
          ResourceSource(
            id: 'legacy-smb',
            name: '我的 SMB',
            type: ResourceSourceType.smb,
            endpoint: smb,
            port: '445',
            username: pick(['smbUsername', 'username']),
            password: pick(['smbPassword', 'password']),
            domain: pick(['smbDomain', 'domain']),
            path: pick(['smbShare', 'sharePath', 'share']),
          ),
        );
      }
    }
    return AppConfig(
      smbHost: pick(['smbHost', 'host', 'ip']),
      smbUsername: pick(['smbUsername', 'username']).isEmpty
          ? 'guest'
          : pick(['smbUsername', 'username']),
      smbPassword: pick(['smbPassword', 'password']),
      smbDomain: pick(['smbDomain', 'domain']),
      smbShare: pick(['smbShare', 'sharePath', 'share']),
      selectedFolders: folders is List
          ? folders.map((e) => e.toString()).toList(growable: false)
          : const [],
      tmdbApiKey: pick(['tmdbApiKey', 'tmdbApi']),
      geminiApiKey: pick(['geminiApiKey', 'geminiApi']),
      autoScanOnStartup: autoScan is bool ? autoScan : true,
      webdavUrl: pick(['webdavUrl', 'webdavHost']),
      webdavUsername: pick(['webdavUsername']),
      webdavPassword: pick(['webdavPassword']),
      embyUrl: pick(['embyUrl', 'embyHost']),
      embyUsername: pick(['embyUsername']),
      embyPassword: pick(['embyPassword']),
      resourceSources: migratedSources,
    );
  }

  Map<String, dynamic> toJson() => {
    'smbHost': smbHost,
    'smbUsername': smbUsername,
    'smbPassword': smbPassword,
    'smbDomain': smbDomain,
    'smbShare': smbShare,
    'selectedFolders': selectedFolders,
    'tmdbApiKey': tmdbApiKey,
    'geminiApiKey': geminiApiKey,
    'autoScanOnStartup': autoScanOnStartup,
    'webdavUrl': webdavUrl,
    'webdavUsername': webdavUsername,
    'webdavPassword': webdavPassword,
    'embyUrl': embyUrl,
    'embyUsername': embyUsername,
    'embyPassword': embyPassword,
    'resourceSources': resourceSources
        .map((source) => source.toJson())
        .toList(),
  };

  AppConfig copyWith({
    String? smbHost,
    String? smbUsername,
    String? smbPassword,
    String? smbDomain,
    String? smbShare,
    List<String>? selectedFolders,
    String? tmdbApiKey,
    String? geminiApiKey,
    bool? autoScanOnStartup,
    String? webdavUrl,
    String? webdavUsername,
    String? webdavPassword,
    String? embyUrl,
    String? embyUsername,
    String? embyPassword,
    List<ResourceSource>? resourceSources,
  }) {
    return AppConfig(
      smbHost: smbHost ?? this.smbHost,
      smbUsername: smbUsername ?? this.smbUsername,
      smbPassword: smbPassword ?? this.smbPassword,
      smbDomain: smbDomain ?? this.smbDomain,
      smbShare: smbShare ?? this.smbShare,
      selectedFolders: selectedFolders ?? this.selectedFolders,
      tmdbApiKey: tmdbApiKey ?? this.tmdbApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      autoScanOnStartup: autoScanOnStartup ?? this.autoScanOnStartup,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      webdavUsername: webdavUsername ?? this.webdavUsername,
      webdavPassword: webdavPassword ?? this.webdavPassword,
      embyUrl: embyUrl ?? this.embyUrl,
      embyUsername: embyUsername ?? this.embyUsername,
      embyPassword: embyPassword ?? this.embyPassword,
      resourceSources: resourceSources ?? this.resourceSources,
    );
  }
}
