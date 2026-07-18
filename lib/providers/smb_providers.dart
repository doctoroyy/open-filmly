import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:http/http.dart' as http;

import 'data_providers.dart';
import '../services/emby/emby_service.dart';
import '../services/library/emby_library_import_service.dart';
import '../services/library/smb_library_import_service.dart';
import '../services/library/webdav_library_import_service.dart';
import '../services/playback/playback_source_resolver.dart';
import '../services/smb/smb_proxy_server.dart';
import '../services/smb/smb_service.dart';
import '../services/webdav/webdav_service.dart';

/// App-lifetime SMB session. Shared by the browser UI and the proxy server.
final smbServiceProvider = Provider<SmbService>((ref) {
  final service = SmbService();
  ref.onDispose(service.disconnect);
  return service;
});

/// App-lifetime local HTTP proxy that streams the SMB session to the player.
final smbProxyProvider = Provider<SmbProxyServer>((ref) {
  final proxy = SmbProxyServer(ref.watch(smbServiceProvider));
  ref.onDispose(proxy.stop);
  return proxy;
});

/// App-lifetime WebDAV session, shared by the browser UI and playback resolver.
final webDavServiceProvider = Provider<WebDavService>((ref) {
  final service = WebDavService();
  ref.onDispose(service.disconnect);
  return service;
});

/// App-lifetime Emby/Jellyfin session, shared by the browser UI and resolver.
final embyServiceProvider = Provider<EmbyService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return EmbyService(client);
});

/// Imports the currently browsed SMB folder into the library database.
final smbLibraryImportProvider = Provider<SmbLibraryImportService>((ref) {
  return SmbLibraryImportService(
    ref.watch(smbServiceProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(episodeRepositoryProvider),
  );
});

/// Imports a browsed WebDAV folder into the library database.
final webDavLibraryImportProvider = Provider<WebDavLibraryImportService>((ref) {
  return WebDavLibraryImportService(
    ref.watch(webDavServiceProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(episodeRepositoryProvider),
  );
});

/// Imports an Emby/Jellyfin library into the database.
final embyLibraryImportProvider = Provider<EmbyLibraryImportService>((ref) {
  return EmbyLibraryImportService(
    ref.watch(embyServiceProvider),
    ref.watch(mediaRepositoryProvider),
    ref.watch(episodeRepositoryProvider),
  );
});

/// Resolves local, SMB, WebDAV, or Emby items into player-ready sources.
final playbackSourceResolverProvider = Provider<PlaybackSourceResolver>((ref) {
  return PlaybackSourceResolver(
    ref.watch(smbServiceProvider),
    ref.watch(smbProxyProvider),
    emby: ref.watch(embyServiceProvider),
    webDav: ref.watch(webDavServiceProvider),
    smbConfig: () {
      final config = ref.read(configProvider).asData?.value;
      if (config == null || config.smbHost.trim().isEmpty) return null;
      return SmbConfig(
        host: config.smbHost.trim(),
        username: config.smbUsername,
        password: config.smbPassword,
        domain: config.smbDomain,
      );
    },
    webDavConfig: () {
      final config = ref.read(configProvider).asData?.value;
      if (config == null || config.webdavUrl.isEmpty) return null;
      return WebDavConfig(
        url: config.webdavUrl,
        username: config.webdavUsername,
        password: config.webdavPassword,
      );
    },
    embyConfig: () {
      final config = ref.read(configProvider).asData?.value;
      if (config == null || config.embyUrl.isEmpty) return null;
      return EmbyConfig(
        url: config.embyUrl,
        username: config.embyUsername,
        password: config.embyPassword,
      );
    },
  );
});
