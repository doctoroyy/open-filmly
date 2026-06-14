import 'package:smb_connect/smb_connect.dart';

import '../streaming/range_source.dart';

/// SMB/CIFS connection parameters. Port is fixed to the SMB default (445)
/// because smb_connect 0.0.9 does not expose a custom port.
class SmbConfig {
  const SmbConfig({
    required this.host,
    this.username = 'guest',
    this.password = '',
    this.domain = '',
  });

  final String host;
  final String username;
  final String password;
  final String domain;
}

/// Wraps a single [SmbConnect] session: share/dir browsing plus the ranged
/// reads the proxy needs. Implements [RangeSource] so the proxy can stay
/// storage-agnostic.
class SmbService implements RangeSource {
  SmbConnect? _connect;
  SmbConfig? _config;

  bool get isConnected => _connect != null;
  SmbConfig? get config => _config;

  Future<void> connect(SmbConfig config) async {
    await disconnect();
    _connect = await SmbConnect.connectAuth(
      host: config.host,
      username: config.username,
      password: config.password,
      domain: config.domain,
    );
    _config = config;
  }

  Future<List<SmbFile>> listShares() => _conn.listShares();

  Future<List<SmbFile>> listChildren(SmbFile folder) => _conn.listFiles(folder);

  /// Lists children of a folder by its server path.
  /// Useful as a fallback when a folder's SmbFile instance is missing the
  /// DIRECTORY attribute due to server quirks (e.g. some Samba setups), preventing
  /// normal traversal.
  Future<List<SmbFile>> listChildrenByPath(String path) async {
    final folder = await openFolder(path);
    return _conn.listFiles(folder);
  }

  /// Opens a folder by its server path (e.g. `/Media` or `/Media/Movies`).
  ///
  /// Used to browse directly into a known share when share enumeration via
  /// srvsvc isn't available on the server (common on some NAS configs).
  Future<SmbFile> openFolder(String path) {
    var cleanPath = path;
    if (cleanPath.startsWith('smb://')) {
      try {
        final uri = Uri.parse(cleanPath);
        cleanPath = uri.path;
      } catch (_) {
        final stripped = cleanPath.replaceFirst(RegExp(r'^smb://[^/]+'), '');
        cleanPath = stripped.isEmpty ? '/' : stripped;
      }
    }
    final normalized = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    return _conn.file(normalized);
  }

  /// Common NAS share names probed when srvsvc enumeration is unavailable,
  /// ordered by how likely they are to hold media. Synology/QNAP/generic mix.
  static const commonShareNames = <String>[
    'Media',
    'media',
    'Movies',
    'movies',
    'Movie',
    'Video',
    'video',
    'Videos',
    'videos',
    'TV',
    'TVShows',
    'Series',
    'multimedia',
    'Multimedia',
    'Music',
    'music',
    'Photo',
    'Photos',
    'photo',
    'Public',
    'public',
    'share',
    'Share',
    'shared',
    'Shared',
    'Downloads',
    'Download',
    'download',
    'Data',
    'data',
    'Files',
    'files',
    'NAS',
    'storage',
    'Volume1',
    'volume1',
    'home',
    'homes',
    'web',
    'www',
    'docker',
  ];

  /// Discovers accessible shares by probing [extra] names first, then a
  /// curated list of common NAS share names. Returns the ones that open.
  ///
  /// This makes browsing "just work" on servers that don't expose share
  /// enumeration, mirroring the Electron app's common-share auto-discovery.
  Future<List<SmbFile>> discoverShares({List<String> extra = const []}) async {
    final seen = <String>{};
    final names = <String>[
      for (final n in extra) n.trim(),
      ...commonShareNames,
    ].where((n) => n.isNotEmpty && seen.add(n.toLowerCase()));

    final found = <SmbFile>[];
    // Sequential probing: smb_connect multiplexes one socket, and each probe
    // is a single fast round-trip that fails closed for missing shares.
    // Filter on `isExists` (not isDirectory) — a share root opened via file()
    // reports as existing but may not carry the DIRECTORY attribute flag.
    for (final name in names) {
      try {
        final folder = await openFolder('/$name');
        if (folder.isExists) found.add(folder);
      } catch (_) {
        // Share doesn't exist or isn't accessible — skip.
      }
    }
    return found;
  }

  @override
  Future<int> length(String path) async {
    final file = await _conn.file(path);
    return file.size;
  }

  /// smb_connect treats `end` as exclusive, hence the +1 over our inclusive end.
  @override
  Future<Stream<List<int>>> read(
    String path,
    int start,
    int endInclusive,
  ) async {
    final file = await _conn.file(path);
    final stream = await _conn.openRead(file, start, endInclusive + 1);
    return stream;
  }

  Future<void> disconnect() async {
    final connection = _connect;
    _connect = null;
    _config = null;
    await connection?.close();
  }

  SmbConnect get _conn {
    final connection = _connect;
    if (connection == null) {
      throw StateError('SMB connection not established');
    }
    return connection;
  }
}
