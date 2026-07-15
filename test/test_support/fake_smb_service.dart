import 'dart:typed_data';

import 'package:open_filmly/services/smb/smb_service.dart';
import 'package:smb_connect/smb_connect.dart';

class FakeSmbService extends SmbService {
  FakeSmbService({
    required SmbConfig initialConfig,
    Map<String, List<SmbFile>> directories = const {},
    Map<String, Uint8List> fileData = const {},
    bool connected = true,
    this.failShares = false,
  }) : _configOverride = connected ? initialConfig : null,
       _connected = connected,
       directories = Map.unmodifiable(directories),
       fileData = Map.unmodifiable(fileData);

  final Map<String, List<SmbFile>> directories;
  final Map<String, Uint8List> fileData;

  /// When true, [listShares] throws, simulating a server without srvsvc share
  /// enumeration (the real-world "cannot find the file specified" case).
  final bool failShares;

  SmbConfig? _configOverride;
  bool _connected;

  @override
  bool get isConnected => _connected;

  @override
  SmbConfig? get config => _configOverride;

  @override
  Future<void> connect(SmbConfig config) async {
    _configOverride = config;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _configOverride = null;
  }

  @override
  Future<List<SmbFile>> listShares() async {
    if (failShares) {
      throw 'The system cannot find the file specified.';
    }
    return directories[_sharesKey] ?? const [];
  }

  @override
  Future<SmbFile> openFolder(String path) async {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (!directories.containsKey(normalized)) {
      throw StateError('Unknown SMB folder: $normalized');
    }
    return smbDir(normalized);
  }

  @override
  Future<List<SmbFile>> listChildren(SmbFile folder) async {
    return directories[folder.path] ?? const [];
  }

  @override
  Future<List<SmbFile>> listChildrenByPath(String path) async {
    final folder = await openFolder(path);
    return listChildren(folder);
  }

  @override
  Future<int> length(String path) async {
    final data = fileData[path];
    if (data == null) {
      throw StateError('Unknown SMB path: $path');
    }
    return data.length;
  }

  @override
  Future<Stream<List<int>>> read(
    String path,
    int start,
    int endInclusive,
  ) async {
    final data = fileData[path];
    if (data == null) {
      throw StateError('Unknown SMB path: $path');
    }
    return Stream.value(data.sublist(start, endInclusive + 1));
  }

  static const _sharesKey = '__shares__';
}

SmbFile smbShare(String name) {
  final sharePath = '/$name';
  return SmbFile(sharePath, _uncPath(sharePath), name, 0, 0, 0, 0x10, 0, true);
}

SmbFile smbDir(String smbPath) {
  return SmbFile(
    smbPath,
    _uncPath(smbPath),
    _shareName(smbPath),
    0,
    0,
    0,
    0x10,
    0,
    true,
  );
}

SmbFile smbFile(String smbPath, {int size = 1}) {
  return SmbFile(
    smbPath,
    _uncPath(smbPath),
    _shareName(smbPath),
    0,
    0,
    0,
    0x20,
    size,
    true,
  );
}

String _shareName(String smbPath) {
  final parts = smbPath.split('/').where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? '' : parts.first;
}

String _uncPath(String smbPath) {
  return '\\\\nas${smbPath.replaceAll('/', '\\')}';
}
