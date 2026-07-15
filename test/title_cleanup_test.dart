import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';

void main() {
  // Real-world dirty release names (as seen in the user's library) must clean
  // up into readable titles for the poster wall and TMDB search.
  group('title cleanup strips release-name noise', () {
    test('codec/bit-depth/group tags', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/m/Drishyam.2015.1080p.10bit.MNHD.FRDS.mkv',
      );
      expect(e.media.title, 'Drishyam');
      expect(e.media.year, '2015');
    });

    test('HEVC/HDR/audio tags', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/m/Akira.1988.2160p.UHD.BluRay.HEVC.HDR10.TrueHD.Atmos.mkv',
      );
      expect(e.media.title, 'Akira');
      expect(e.media.year, '1988');
    });

    test('CJK release tags', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/m/寄生虫.2019.1080p.国语中字.mkv',
      );
      expect(e.media.title, '寄生虫');
      expect(e.media.year, '2019');
    });

    test('keeps legitimate words intact', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/m/Dog Day Afternoon (1975).mkv',
      );
      expect(e.media.title, 'Dog Day Afternoon');
      expect(e.media.year, '1975');
    });
  });
}
