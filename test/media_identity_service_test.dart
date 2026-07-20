import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/intelligence/media_identity_service.dart';

void main() {
  test('builds a stable identity from source, URI, and file metadata', () {
    final first = MediaIdentityService.fromDescriptor(
      sourceScope: ' Local ',
      canonicalUri: '/Movies/Example.mkv',
      fileSize: 1024,
      modifiedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    final second = MediaIdentityService.fromDescriptor(
      sourceScope: 'local',
      canonicalUri: r'/Movies/./Example.mkv',
      fileSize: 1024,
      modifiedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );

    expect(first.identityKey, second.identityKey);
    expect(first.canonicalUri, '/Movies/Example.mkv');
  });

  test('content hash wins over changing filesystem metadata', () {
    final first = MediaIdentityService.fromDescriptor(
      sourceScope: 'local',
      canonicalUri: '/Movies/Example.mkv',
      fileHash: 'sha256:abc',
      fileSize: 1024,
      modifiedAt: DateTime.utc(2026, 1, 2),
    );
    final second = MediaIdentityService.fromDescriptor(
      sourceScope: 'local',
      canonicalUri: '/Movies/Example.mkv',
      fileHash: 'sha256:abc',
      fileSize: 2048,
      modifiedAt: DateTime.utc(2027, 1, 2),
    );

    expect(first.identityKey, second.identityKey);
  });
}
