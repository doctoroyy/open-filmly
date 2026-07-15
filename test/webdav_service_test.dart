import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/episode.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';
import 'package:open_filmly/services/webdav/webdav_service.dart';

void main() {
  group('WebDavService.buildFileUrl', () {
    test('joins base and path, percent-encoding segments', () {
      final url = WebDavService.buildFileUrl(
        'https://dav.example.com/dav',
        '/Movies/Dune 2021.mkv',
      );
      expect(url, 'https://dav.example.com/dav/Movies/Dune%202021.mkv');
    });

    test('handles trailing slash on base and CJK characters', () {
      final url = WebDavService.buildFileUrl(
        'https://dav.example.com/dav/',
        '/电影/沙丘.mkv',
      );
      expect(
        url,
        'https://dav.example.com/dav/${Uri.encodeComponent('电影')}/'
        '${Uri.encodeComponent('沙丘.mkv')}',
      );
    });

    test('prepends https:// when scheme is missing', () {
      final url = WebDavService.buildFileUrl('dav.example.com', '/a.mkv');
      expect(url, 'https://dav.example.com/a.mkv');
    });
  });

  group('WebDavConfig', () {
    test('builds a Basic auth header from credentials', () {
      const config = WebDavConfig(
        url: 'https://x',
        username: 'user',
        password: 'pass',
      );
      expect(config.basicAuthHeader, startsWith('Basic '));
      expect(config.authHeaders['Authorization'], config.basicAuthHeader);
    });

    test('omits auth header when no credentials', () {
      const config = WebDavConfig(url: 'https://x');
      expect(config.basicAuthHeader, isNull);
      expect(config.authHeaders, isEmpty);
    });
  });

  group('MediaLibraryEntryFactory WebDAV', () {
    test('parses a movie file into a webdav-sourced media item', () {
      final entry = MediaLibraryEntryFactory.fromWebDavFile(
        baseUrl: 'https://dav.example.com/dav',
        relativePath: '/Movies/The.Matrix.1999.1080p.mkv',
      );

      expect(entry.media.type, MediaType.movie);
      expect(entry.media.title, 'The Matrix');
      expect(entry.media.year, '1999');

      final source = MediaLibraryEntryFactory.webDavSourceFor(entry.media);
      expect(source, isNotNull);
      expect(source!.baseUrl, 'https://dav.example.com/dav');
      expect(source.path, '/Movies/The.Matrix.1999.1080p.mkv');
    });

    test('parses a TV episode into show + episode with shared source', () {
      final entry = MediaLibraryEntryFactory.fromWebDavFile(
        baseUrl: 'https://dav.example.com/dav',
        relativePath: '/TV/Breaking Bad/Season 01/Breaking.Bad.S01E01.mkv',
      );

      expect(entry.media.type, MediaType.tv);
      expect(entry.hasEpisode, isTrue);
      expect(entry.episode!.seasonNumber, 1);
      expect(entry.episode!.episodeNumber, 1);

      final source = MediaLibraryEntryFactory.webDavSourceFor(entry.media);
      expect(source, isNotNull);
    });

    test('episodePlayableMedia carries the episode file path as the source', () {
      final show = MediaLibraryEntryFactory.fromWebDavFile(
        baseUrl: 'https://dav.example.com/dav',
        relativePath: '/TV/Show/Season 01/Show.S01E02.mkv',
      ).media;
      const episode = Episode(
        id: 'ep',
        showId: 'show',
        seasonNumber: 1,
        episodeNumber: 2,
        path:
            'webdav|https://dav.example.com/dav|/TV/Show/Season 01/Show.S01E02.mkv',
        fullPath: '/TV/Show/Season 01/Show.S01E02.mkv',
      );

      final playable = MediaLibraryEntryFactory.episodePlayableMedia(
        episode,
        show,
      );
      final source = MediaLibraryEntryFactory.webDavSourceFor(playable);

      expect(source, isNotNull);
      expect(source!.path, '/TV/Show/Season 01/Show.S01E02.mkv');
    });
  });
}
