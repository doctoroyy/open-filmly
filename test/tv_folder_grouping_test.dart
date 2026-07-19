import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';

/// Real SMB layouts under /Volumes/wd/电视剧.
void main() {
  group('异星灾变 layout: show/S01E10/file.mkv', () {
    const ep10 =
        '/Volumes/wd/电视剧/异星灾变.第1季/S01E10/'
        'Raised.by.Wolves.2020.S01E10.The.Beginning.1080p.HMAX.WEB-DL.DD5.1.H.264-NTG.mkv';
    const ep01 =
        '/Volumes/wd/电视剧/异星灾变.第1季/S01E01/'
        'Raised.by.Wolves.2020.S01E01.Raised.by.Wolves.1080p.HMAX.WEB-DL.DD5.1.H.264-NTG.mkv';

    test('episode 10 groups under show title 异星灾变, not S01E10', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(ep10);
      expect(e.media.type, MediaType.tv);
      expect(e.hasEpisode, isTrue);
      expect(e.episode!.seasonNumber, 1);
      expect(e.episode!.episodeNumber, 10);
      expect(e.media.title, isNot(equals('S01E10')));
      expect(e.media.title, contains('异星灾变'));
      expect(e.media.fullPath, contains('异星灾变.第1季'));
      expect(e.media.fullPath, isNot(contains('S01E10')));
    });

    test('show fullPath stays at 异星灾变.第1季 pack folder, not 电视剧', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(ep10);
      expect(e.media.fullPath, endsWith('异星灾变.第1季'));
      expect(e.media.fullPath, isNot(endsWith('电视剧')));
    });

    test('episodes 1 and 10 share the same show id', () {
      final a = MediaLibraryEntryFactory.fromLocalPath(ep01);
      final b = MediaLibraryEntryFactory.fromLocalPath(ep10);
      expect(a.media.id, b.media.id);
      expect(a.media.title, b.media.title);
    });
  });

  group('良医 layout: show/S01/S01E01/file.mkv', () {
    const ep =
        '/Volumes/wd/电视剧/良医1-2季/S01/S01E01/'
        'The.Good.Doctor.S01E01.Burnt.Food.1080p.AMZN.WEB-DL.DD5.1.H.264-QOQ.mkv';
    const epS3 =
        '/Volumes/wd/电视剧/良医第3季/S03E01/'
        'The.Good.Doctor.S03E01.Disaster.1080p.AMZN.WEB-DL.DDP5.1.H.264-TOMMY.mkv';

    test('S01 nested episode uses 良医 as show title', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(ep);
      expect(e.media.type, MediaType.tv);
      expect(e.hasEpisode, isTrue);
      expect(e.episode!.seasonNumber, 1);
      expect(e.episode!.episodeNumber, 1);
      expect(e.media.title, isNot(equals('S01')));
      expect(e.media.title, isNot(equals('S01E01')));
      expect(e.media.title, contains('良医'));
    });

    test('S03 pack folder 良医第3季 strips season suffix for show title', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(epS3);
      expect(e.media.type, MediaType.tv);
      expect(e.hasEpisode, isTrue);
      expect(e.episode!.seasonNumber, 3);
      expect(e.episode!.episodeNumber, 1);
      expect(e.media.title, isNot(equals('S03E01')));
      expect(e.media.title, contains('良医'));
      expect(e.media.title, isNot(contains('第3季')));
      expect(e.media.fullPath, endsWith('良医第3季'));
    });
  });

  group('season-only folder detection', () {
    test('S01E10 is treated as an episode container, not the show', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/tv/Show.Name/S01E05/Show.Name.S01E05.Title.mkv',
      );
      expect(e.media.title, isNot(equals('S01E05')));
      expect(e.media.title.toLowerCase(), contains('show'));
    });
  });

  group('权力的游戏 layout: pack/Game.Of.Thrones.S0N.release/file.mkv', () {
    const pack = '/Volumes/wd/电视剧/权力的游戏1080p.Bluray.x265.10bit';
    const s01 =
        '$pack/Game.Of.Thrones.S01.1080p.Bluray.DTS.x265.10bit/'
        'Game.of.Thrones.S01E01.Winter.is.Coming.1080p.Bluray.DTS.x265.10bit.mkv';
    const s05 =
        '$pack/Game.Of.Thrones.S05.1080p.Bluray.AC3.x265.10bit/'
        'Game.of.Thrones.S05E01.The.Wars.to.Come.1080p.Bluray.AC3.x265.10bit.mkv';
    const s07 =
        '$pack/Game.Of.Thrones.S07.1080p.Bluray.AC3.x265.10bit/'
        'Game.of.Thrones.S07E01.Dragonstone.1080p.Bluray.AC3.x265.10bit.mkv';

    test('S01 does not become a separate "Game Of Thrones S01" card', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(s01);
      expect(e.media.type, MediaType.tv);
      expect(e.hasEpisode, isTrue);
      expect(e.episode!.seasonNumber, 1);
      expect(e.episode!.episodeNumber, 1);
      expect(
        e.media.title,
        isNot(contains(RegExp(r'S0?1\b', caseSensitive: false))),
      );
      expect(e.media.title, isNot(equals('Game Of Thrones S01')));
      // Prefer the Chinese show pack name when available.
      expect(e.media.title, contains('权力的游戏'));
    });

    test('all seasons share one show id and pack fullPath', () {
      final a = MediaLibraryEntryFactory.fromLocalPath(s01);
      final b = MediaLibraryEntryFactory.fromLocalPath(s05);
      final c = MediaLibraryEntryFactory.fromLocalPath(s07);
      expect(a.media.id, b.media.id);
      expect(b.media.id, c.media.id);
      expect(a.media.title, b.media.title);
      expect(a.media.fullPath, endsWith('权力的游戏1080p.Bluray.x265.10bit'));
      expect(b.media.fullPath, a.media.fullPath);
      expect(a.media.fullPath, isNot(contains('Game.Of.Thrones.S0')));
    });

    test('season numbers stay correct across release-style folders', () {
      final e5 = MediaLibraryEntryFactory.fromLocalPath(s05);
      final e7 = MediaLibraryEntryFactory.fromLocalPath(s07);
      expect(e5.episode!.seasonNumber, 5);
      expect(e5.episode!.episodeNumber, 1);
      expect(e7.episode!.seasonNumber, 7);
      expect(e7.episode!.episodeNumber, 1);
    });
  });

  group('download dump must not become a TV show', () {
    const genius =
        '/Volumes/wd-downloads/aria2-downloads/'
        'Genius.S01.1080p.AMZN.WEBRip.DDP5.1.x265-SiGMA[rartv]/'
        'Genius.S01E02.Einstein.Chapter.Two.1080p.AMZN.WEB-DL.DD.5.1.H.265-SiGMA.mkv';
    const severance =
        '/Volumes/wd-downloads/aria2-downloads/'
        'severance.s01e01.2160p.web.h265-glhf.mkv';
    const billions =
        '/Volumes/wd-downloads/aria2-downloads/'
        'Billions (2016) Season 1 S01 (1080p BluRay x265 HEVC 10bit AAC 5.1 Vyndros)/'
        'Billions.S01E03.YumTime.1080p.10bit.BluRay.AAC5.1.HEVC-Vyndros.mkv';

    test('Genius under aria2-downloads is Genius, not aria2 downloads', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(genius);
      expect(e.media.type, MediaType.tv);
      expect(e.media.title.toLowerCase(), contains('genius'));
      expect(e.media.title.toLowerCase(), isNot(contains('aria2')));
      expect(e.episode!.seasonNumber, 1);
      expect(e.episode!.episodeNumber, 2);
    });

    test('flat dump file uses filename show title', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(severance);
      expect(e.media.type, MediaType.tv);
      expect(e.media.title.toLowerCase(), contains('severance'));
      expect(e.media.title.toLowerCase(), isNot(contains('aria2')));
    });

    test('unrelated dump shows do not share one id', () {
      final a = MediaLibraryEntryFactory.fromLocalPath(genius);
      final b = MediaLibraryEntryFactory.fromLocalPath(severance);
      final c = MediaLibraryEntryFactory.fromLocalPath(billions);
      expect(a.media.id, isNot(equals(b.media.id)));
      expect(b.media.id, isNot(equals(c.media.id)));
      expect(a.media.id, isNot(equals(c.media.id)));
    });

    test('isDumpOrInboxFolderName covers cleaned titles', () {
      expect(
        MediaLibraryEntryFactory.isDumpOrInboxFolderName('aria2-downloads'),
        isTrue,
      );
      expect(
        MediaLibraryEntryFactory.isDumpOrInboxFolderName('aria2 downloads'),
        isTrue,
      );
      expect(
        MediaLibraryEntryFactory.isDumpOrInboxFolderName('btsync-data'),
        isTrue,
      );
      expect(
        MediaLibraryEntryFactory.isDumpOrInboxFolderName('权力的游戏'),
        isFalse,
      );
    });
  });
}
