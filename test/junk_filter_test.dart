import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/services/library/media_library_entry_factory.dart';

void main() {
  group('isImportableVideo skips OS junk', () {
    test('macOS AppleDouble sidecar', () {
      const p = '/m/247.驱魔人/._The.Exorcist.1973.DC.1080p.mkv';
      expect(MediaLibraryEntryFactory.isVideoPath(p), isTrue);
      expect(MediaLibraryEntryFactory.isJunkPath(p), isTrue);
      expect(MediaLibraryEntryFactory.isImportableVideo(p), isFalse);
    });

    test('sample / trailer clips', () {
      expect(
        MediaLibraryEntryFactory.isImportableVideo('/m/Movie/sample.mkv'),
        isFalse,
      );
      expect(
        MediaLibraryEntryFactory.isImportableVideo('/m/Movie-sample.mp4'),
        isFalse,
      );
    });

    test('real video imports', () {
      const p = '/m/The.Exorcist.1973.DC.BluRay.1080p.x265.10bit.MNHD-FRDS.mkv';
      expect(MediaLibraryEntryFactory.isImportableVideo(p), isTrue);
    });
  });

  group('director-cut tags are stripped from titles', () {
    test('DC and codec noise', () {
      final e = MediaLibraryEntryFactory.fromLocalPath(
        '/m/The.Exorcist.1973.DC.BluRay.1080p.x265.10bit.mkv',
      );
      expect(e.media.title, 'The Exorcist');
      expect(e.media.year, '1973');
    });
  });
}
