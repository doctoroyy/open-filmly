import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart';
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
  final subtitleBytes = Uint8List.fromList(gbk.encode('中文字幕'));

  setUp(() async {
    smb = FakeSmbService(
      initialConfig: const SmbConfig(host: 'nas', username: 'guest'),
      directories: {
        '/Media/Movies': [
          smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: bytes.length),
          smbFile(
            '/Media/Movies/Dune.2021.1080p.zh-CN.srt',
            size: subtitleBytes.length,
          ),
        ],
      },
      fileData: {
        '/Media/Movies/Dune.2021.1080p.mkv': bytes,
        '/Media/Movies/Dune.2021.1080p.zh-CN.srt': subtitleBytes,
      },
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
    expect(source.subtitles, hasLength(1));
    expect(source.subtitles.single.language, 'zh-cn');

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

    final subtitleRequest = await client.getUrl(
      Uri.parse(source.subtitles.single.uri),
    );
    final subtitleResponse = await subtitleRequest.close();
    final subtitleBody = BytesBuilder();
    await for (final chunk in subtitleResponse) {
      subtitleBody.add(chunk);
    }
    expect(utf8.decode(subtitleBody.takeBytes()), '中文字幕');
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

  test('throws when SMB media is not connected and no credentials saved', () async {
    final entry = MediaLibraryEntryFactory.fromSmbFile(
      config: const SmbConfig(host: 'nas', username: 'guest'),
      file: smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: bytes.length),
    );
    await smb.disconnect();

    // No smbConfig callback — cannot recover the session.
    await expectLater(
      resolver.resolve(entry.media),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SMB source is not connected'),
        ),
      ),
    );
  });

  test('auto-reconnects SMB from saved credentials after disconnect', () async {
    final entry = MediaLibraryEntryFactory.fromSmbFile(
      config: const SmbConfig(host: 'nas', username: 'guest'),
      file: smbFile('/Media/Movies/Dune.2021.1080p.mkv', size: bytes.length),
    );
    await smb.disconnect();

    final reconnecting = PlaybackSourceResolver(
      smb,
      proxy,
      smbConfig: () =>
          const SmbConfig(host: 'nas', username: 'guest', password: 'secret'),
    );

    final source = await reconnecting.resolve(entry.media);
    expect(smb.isConnected, isTrue);
    expect(source.uri, startsWith('http://127.0.0.1:'));
  });

  test('smb:// paths with CJK keep decoded characters (no percent-encoding)', () {
    // Regression: Uri.parse used to turn 生活大爆炸 into %E7%94%9F… which made
    // both /Volumes mounts and smb_connect miss the file.
    const raw =
        'smb://192.168.31.252/wd-downloads/btsync-data/生活大爆炸 1-10 季/S01.第一季/S01E01.Pilot.mkv';
    // Access via resolve path: build a media item and inspect proxy token path
    // through the public resolver when no local mount exists.
    final media = Media(
      id: 'cjk',
      title: 'Pilot',
      year: '',
      type: MediaType.unknown,
      path: raw,
      fullPath: raw,
      detailsJson:
          '{"source":{"kind":"smb","host":"nas","path":"$raw","share":"wd-downloads","username":"guest"}}',
    );
    // Ensure the factory still surfaces an SMB source with the raw path.
    final source = MediaLibraryEntryFactory.smbSourceFor(media);
    expect(source, isNotNull);
    expect(source!.path, contains('生活大爆炸'));
    expect(source.path, isNot(contains('%E7')));
  });

  test('resolves WebDAV media into an authed HTTP URL', () async {
    final dav = _FakeWebDavService(
      const [
        WebDavEntry(
          name: 'Dune 2021.zh-CN.srt',
          path: '/Movies/Dune 2021.zh-CN.srt',
          isDir: false,
        ),
      ],
      fileData: {'/Movies/Dune 2021.zh-CN.srt': gbk.encode('WebDAV 中文字幕')},
    );
    final resolverWithDav = PlaybackSourceResolver(
      smb,
      proxy,
      webDav: dav,
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
    expect(source.subtitles, hasLength(1));
    expect(source.subtitles.single.uri, startsWith('http://127.0.0.1:'));
    final client = HttpClient();
    final subtitleRequest = await client.getUrl(
      Uri.parse(source.subtitles.single.uri),
    );
    final subtitleResponse = await subtitleRequest.close();
    final subtitleBody = BytesBuilder();
    await for (final chunk in subtitleResponse) {
      subtitleBody.add(chunk);
    }
    expect(utf8.decode(subtitleBody.takeBytes()), 'WebDAV 中文字幕');
    client.close(force: true);
  });
}

class _FakeWebDavService extends WebDavService {
  _FakeWebDavService(this.entries, {this.fileData = const {}});

  final List<WebDavEntry> entries;
  final Map<String, List<int>> fileData;
  WebDavConfig? _activeConfig;

  @override
  bool get isConnected => _activeConfig != null;

  @override
  WebDavConfig? get config => _activeConfig;

  @override
  Future<void> connect(WebDavConfig config) async {
    _activeConfig = config;
  }

  @override
  Future<List<WebDavEntry>> listDir([String dirPath = '/']) async => entries;

  @override
  Future<List<int>> readBytes(String path) async => fileData[path] ?? const [];
}
