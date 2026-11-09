import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seed_stash/local_inventory_store.dart';
import 'package:seed_stash/seed_packet.dart';

void main() {
  late Directory home;
  late LocalInventoryStore store;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('seed-stash-store-');
    store = LocalInventoryStore(directory: home);
  });
  tearDown(() async => home.delete(recursive: true));

  SeedPacket packet(String id) => SeedPacket(
    id: id,
    crop: 'Tomato',
    variety: 'Sungold',
    supplier: 'Farm',
    location: 'Drawer',
    lot: 'A1',
    packedOn: DateTime.utc(2026, 2, 1),
    initialCount: 20,
    adjustments: [
      CountAdjustment(
        date: DateTime.utc(2026, 3, 1),
        delta: -5,
        reason: 'Sown',
      ),
    ],
    samples: [
      GerminationSample(date: DateTime.utc(2026, 3, 5), tested: 4, sprouted: 3),
    ],
  );

  test('round trips complete history, increments revision, and rejects stale edits', () async {
    final first = await store.update(
      (old) =>
          InventorySnapshot(revision: old.revision, packets: [packet('a')]),
      expectedRevision: 0,
    );
    expect(first.revision, 1);
    final loaded = await LocalInventoryStore(directory: home).read();
    expect(loaded.packets.single.remainingCount, 15);
    expect(loaded.packets.single.samples.single.measuredPercent, 75);
    expect(loaded.packets.single.packedOn, DateTime.utc(2026, 2, 1));
    expect(loaded.packets.single.lot, 'A1');
    expect(loaded.packets.single.shopping, isFalse);
    await expectLater(
      store.update((old) => old, expectedRevision: 0),
      throwsA(isA<StaleInventoryException>()),
    );
    expect((await store.read()).revision, 1);
  });

  test(
    'migrates version 2 flags and persists shopping without losing history',
    () async {
      await store.update(
        (s) => InventorySnapshot(revision: s.revision, packets: [packet('a')]),
      );
      final file = File('${home.path}/inventory.json');
      final old = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      old['version'] = 2;
      (old['packets'] as List).single.remove('shopping');
      await file.writeAsString(jsonEncode(old));
      final migrated = await store.read();
      expect(migrated.revision, 1);
      expect(migrated.packets.single.shopping, isFalse);
      expect(migrated.packets.single.samples.single.measuredPercent, 75);
      expect(jsonDecode(await file.readAsString())['version'], 3);
      await store.update(
        (s) => InventorySnapshot(
          revision: s.revision,
          packets: [s.packets.single.withShopping(true)],
        ),
        expectedRevision: 1,
      );
      expect(
        (await LocalInventoryStore(
          directory: home,
        ).read()).packets.single.shopping,
        isTrue,
      );
      final malformed =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      (malformed['packets'] as List).single['shopping'] = 'true';
      await file.writeAsString(jsonEncode(malformed));
      await expectLater(store.read(), throwsFormatException);
      expect(await file.readAsString(), jsonEncode(malformed));
    },
  );

  test('serializes concurrent writers without losing packets', () async {
    final a = LocalInventoryStore(directory: home);
    final b = LocalInventoryStore(directory: home);
    await Future.wait([
      a.update(
        (s) => InventorySnapshot(
          revision: s.revision,
          packets: [...s.packets, packet('a')],
        ),
      ),
      b.update(
        (s) => InventorySnapshot(
          revision: s.revision,
          packets: [...s.packets, packet('b')],
        ),
      ),
    ]);
    final loaded = await store.read();
    expect(loaded.revision, 2);
    expect(loaded.packets.map((p) => p.id).toSet(), {'a', 'b'});
  });

  test(
    'rejects failed writes and corrupt input without replacing saved data',
    () async {
      await store.update(
        (s) => InventorySnapshot(revision: s.revision, packets: [packet('a')]),
      );
      final file = File('${home.path}/inventory.json');
      final before = await file.readAsString();
      await expectLater(
        store.update(
          (s) => InventorySnapshot(
            revision: s.revision,
            packets: [packet('a'), packet('a')],
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        store.update((s) => throw StateError('abort')),
        throwsStateError,
      );
      expect(await file.readAsString(), before);
      await file.writeAsString('{not json');
      await expectLater(store.update((s) => s), throwsFormatException);
      expect(await file.readAsString(), '{not json');
    },
  );

  test(
    'migrates version 1 atomically and blocks unknown future versions',
    () async {
      final file = File('${home.path}/inventory.json');
      final old = jsonDecode(
        await (() async {
          await store.update(
            (s) =>
                InventorySnapshot(revision: s.revision, packets: [packet('a')]),
          );
          return file.readAsString();
        })(),
      ) as Map<String, dynamic>;
      old['version'] = 1;
      old.remove('revision');
      await file.writeAsString(jsonEncode(old));
      expect((await store.read()).revision, 0);
      expect(jsonDecode(await file.readAsString())['version'], 3);
      old['version'] = 99;
      await file.writeAsString(jsonEncode(old));
      await expectLater(store.read(), throwsFormatException);
      expect(jsonDecode(await file.readAsString())['version'], 99);
    },
  );
}
