import 'package:flutter/material.dart';

/// A saved file source shown in the mobile/desktop resource library.
///
/// The source model is intentionally transport-oriented rather than tied to a
/// single browser page. This lets the same source appear on iOS and desktop,
/// while each platform can choose its own browsing and import affordances.
enum ResourceSourceType { local, webdav, smb, emby, jellyfin, cloud }

extension ResourceSourceTypePresentation on ResourceSourceType {
  String get label => switch (this) {
    ResourceSourceType.local => '本地下载',
    ResourceSourceType.webdav => 'WebDAV',
    ResourceSourceType.smb => 'SMB',
    ResourceSourceType.emby => 'Emby',
    ResourceSourceType.jellyfin => 'Jellyfin',
    ResourceSourceType.cloud => '云盘',
  };

  IconData get icon => switch (this) {
    ResourceSourceType.local => Icons.folder_copy_rounded,
    ResourceSourceType.webdav => Icons.cloud_queue_rounded,
    ResourceSourceType.smb => Icons.storage_rounded,
    ResourceSourceType.emby => Icons.ondemand_video_rounded,
    ResourceSourceType.jellyfin => Icons.live_tv_rounded,
    ResourceSourceType.cloud => Icons.cloud_rounded,
  };

  String get jsonValue => name;
}

class ResourceSource {
  const ResourceSource({
    required this.id,
    required this.name,
    required this.type,
    this.endpoint = '',
    this.protocol = 'https',
    this.port = '',
    this.username = '',
    this.password = '',
    this.domain = '',
    this.path = '/',
    this.importedPaths = const [],
    this.enabled = true,
  });

  final String id;
  final String name;
  final ResourceSourceType type;
  final String endpoint;
  final String protocol;
  final String port;
  final String username;
  final String password;
  final String domain;
  final String path;
  final List<String> importedPaths;
  final bool enabled;

  String get displayEndpoint {
    if (type == ResourceSourceType.local) {
      return endpoint.isEmpty ? '设备存储' : endpoint;
    }
    final host = endpoint.trim();
    if (host.isEmpty) return type.label;
    return type == ResourceSourceType.webdav && !host.contains('://')
        ? '$protocol://$host'
        : host;
  }

  bool get isConfigured => switch (type) {
    ResourceSourceType.local => endpoint.trim().isNotEmpty,
    ResourceSourceType.cloud => false,
    _ => endpoint.trim().isNotEmpty,
  };

  ResourceSource copyWith({
    String? id,
    String? name,
    ResourceSourceType? type,
    String? endpoint,
    String? protocol,
    String? port,
    String? username,
    String? password,
    String? domain,
    String? path,
    List<String>? importedPaths,
    bool? enabled,
  }) {
    return ResourceSource(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      endpoint: endpoint ?? this.endpoint,
      protocol: protocol ?? this.protocol,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      domain: domain ?? this.domain,
      path: path ?? this.path,
      importedPaths: importedPaths ?? this.importedPaths,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.jsonValue,
    'endpoint': endpoint,
    'protocol': protocol,
    'port': port,
    'username': username,
    'password': password,
    'domain': domain,
    'path': path,
    'importedPaths': importedPaths,
    'enabled': enabled,
  };

  factory ResourceSource.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString() ?? '';
    final type = ResourceSourceType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => ResourceSourceType.webdav,
    );
    final rawPaths = json['importedPaths'];
    return ResourceSource(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : 'source-${DateTime.now().microsecondsSinceEpoch}',
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : type.label,
      type: type,
      endpoint: json['endpoint']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? 'https',
      port: json['port']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      path: json['path']?.toString().isNotEmpty == true
          ? json['path'].toString()
          : '/',
      importedPaths: rawPaths is List
          ? rawPaths.map((value) => value.toString()).toList(growable: false)
          : const [],
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
    );
  }

  static String newId(ResourceSourceType type) =>
      '${type.name}-${DateTime.now().microsecondsSinceEpoch}';
}
