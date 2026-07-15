import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filmly/data/database/database.dart';
import 'package:open_filmly/data/models/media.dart';
import 'package:open_filmly/data/repositories/media_repository.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(String id, String title) => repo.upsert(
    Media(
      id: id,
      title: title,
      year: '2020',
      type: MediaType.movie,
      path: '/m/$id.mkv',
    ),
  );

  test('items are not favorited by default', () async {
    await seed('m1', 'A');
    final media = await repo.getById('m1');
    expect(media!.isFavorite, isFalse);
    expect(await repo.getFavorites(), isEmpty);
  });

  test('setFavorite toggles and getFavorites reflects it', () async {
    await seed('m1', 'A');
    await seed('m2', 'B');

    await repo.setFavorite('m1', true);
    expect((await repo.getById('m1'))!.isFavorite, isTrue);

    final favs = await repo.getFavorites();
    expect(favs.map((m) => m.id), ['m1']);

    await repo.setFavorite('m1', false);
    expect(await repo.getFavorites(), isEmpty);
  });

  test('re-upsert (e.g. rescan) preserves the favorite flag', () async {
    await seed('m1', 'A');
    await repo.setFavorite('m1', true);

    // Simulate a rescan / metadata refresh upserting the same item.
    await repo.upsert(
      (await repo.getById('m1'))!.copyWith(title: 'A (updated)'),
    );

    final media = await repo.getById('m1');
    expect(media!.title, 'A (updated)');
    expect(media.isFavorite, isTrue, reason: 'favorite must survive re-upsert');
  });
}
