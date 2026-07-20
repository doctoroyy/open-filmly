import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class MediaIdentity {
  const MediaIdentity({
    required this.identityKey,
    required this.sourceScope,
    required this.canonicalUri,
    required this.fingerprint,
    this.fileHash,
    this.fileSize,
    this.modifiedAt,
  });

  final String identityKey;
  final String sourceScope;
  final String canonicalUri;
  final String fingerprint;
  final String? fileHash;
  final int? fileSize;
  final DateTime? modifiedAt;
}

class MediaIdentityService {
  const MediaIdentityService();

  static MediaIdentity fromDescriptor({
    required String sourceScope,
    required String canonicalUri,
    String? fileHash,
    int? fileSize,
    DateTime? modifiedAt,
  }) {
    final scope = sourceScope.trim().toLowerCase();
    final uri = _canonicalize(canonicalUri);
    final normalizedHash = fileHash?.trim().toLowerCase();
    final fingerprint = normalizedHash?.isNotEmpty == true
        ? 'hash:$normalizedHash'
        : 'stat:${fileSize ?? -1}:${modifiedAt?.toUtc().toIso8601String() ?? ''}';
    final material = '$scope|$uri|$fingerprint';
    final key = sha256.convert(utf8.encode(material)).toString();
    return MediaIdentity(
      identityKey: key,
      sourceScope: scope,
      canonicalUri: uri,
      fingerprint: fingerprint,
      fileHash: normalizedHash,
      fileSize: fileSize,
      modifiedAt: modifiedAt?.toUtc(),
    );
  }

  static Future<MediaIdentity> fromFile({
    required String path,
    String sourceScope = 'local',
    String? fileHash,
  }) async {
    final file = File(path);
    final stat = await file.stat();
    return fromDescriptor(
      sourceScope: sourceScope,
      canonicalUri: path,
      fileHash: fileHash,
      fileSize: stat.size,
      modifiedAt: stat.modified,
    );
  }

  static String _canonicalize(String raw) {
    final value = raw.trim().replaceAll('\\', '/');
    if (value.isEmpty) return value;
    if (value.contains('://')) {
      final parsed = Uri.tryParse(value);
      if (parsed == null) return value;
      final host = parsed.host.toLowerCase();
      final path = p.posix.normalize(parsed.path.isEmpty ? '/' : parsed.path);
      return parsed.replace(host: host, path: path).toString();
    }
    return p.posix.normalize(value);
  }
}
