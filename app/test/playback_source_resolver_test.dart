import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';
import 'package:open_filmly/services/playback/playback_source_resolver.dart';
import 'package:open_filmly/services/smb/smb_proxy_server.dart';
import 'package:open_filmly/services/smb/smb_service.dart';
import 'package:open_filmly/services/webdav/webdav_service.dart';

import 'test_support/fake_smb_service.dart';

void main() {
  late FakeSmbService smb;
  late SmbProxyServer proxy;
  late PlaybackSourceResolver resolver;
  final bytes = Uint8List.fromList(List<int>.generate(256, (i) => i));

  setUp(() async {
    smb = FakeSmbService(
      initialConfig: const SmbConfig(host: 'nas', username: 'guest'),
      fileData: {'/Media/Movies/Dune.2021.1080p.mkv': bytes},
    );
    proxy = SmbProxyServer(smb);
    resolver = PlaybackSourceResolver(smb, proxy);
  });

  tearDown(() async {
    await proxy.stop();
  });

  test('resolves SMB media into a loopback proxy URL', () async {
    final entry = MediaLibraryEntryFactory.fromSmbFile(
      config: const SmbConfig(host: 'nas', username: 'guest'),
      file: smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: bytes.length),
    );

    final source = await resolver.resolve(entry.media);
    expect(source.uri, startsWith('http://127.0.0.1:'));

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(source.uri));
    final response = await request.close();
    final bodyBuilder = BytesBuilder();
    await for (final chunk in response) {
      bodyBuilder.add(chunk);
    }
    final body = bodyBuilder.takeBytes();

    expect(response.statusCode, 200);
    expect(body, bytes);
    client.close(force: true);
  });

  test('returns local file paths unchanged', () async {
    final media = const Media(
      id: '/movies/dune.mkv',
      title: 'Dune',
      year: '2021',
      type: MediaType.movie,
      path: '/movies/dune.mkv',
      fullPath: '/movies/dune.mkv',
    );

    final source = await resolver.resolve(media);
    expect(source.uri, '/movies/dune.mkv');
    expect(source.httpHeaders, isNull);
  });

  test('throws when SMB media is not connected', () async {
    final entry = MediaLibraryEntryFactory.fromSmbFile(
      config: const SmbConfig(host: 'nas', username: 'guest'),
      file: smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: bytes.length),
    );
    await smb.disconnect();

    await expectLater(
      resolver.resolve(entry.media),
      throwsA(isA<StateError>()),
    );
  });

  test('resolves WebDAV media into an authed HTTP URL', () async {
    final resolverWithDav = PlaybackSourceResolver(
      smb,
      proxy,
      webDavConfig: () => const WebDavConfig(
        url: 'https://dav.example.com/dav',
        username: 'user',
        password: 'pass',
      ),
    );
    final entry = MediaLibraryEntryFactory.fromWebDavFile(
      baseUrl: 'https://dav.example.com/dav',
      relativePath: '/Movies/Dune 2021.mkv',
    );

    final source = await resolverWithDav.resolve(entry.media);

    expect(source.uri, 'https://dav.example.com/dav/Movies/Dune%202021.mkv');
    expect(source.httpHeaders, isNotNull);
    expect(source.httpHeaders!['Authorization'], startsWith('Basic '));
  });
}
