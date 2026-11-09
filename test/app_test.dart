import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:seed_stash/local_inventory_store.dart';
import 'package:seed_stash/main.dart';
import 'package:seed_stash/seed_packet.dart';

class MemoryStore extends LocalInventoryStore {
  InventorySnapshot data = InventorySnapshot(revision: 0, packets: []);

  @override
  Future<InventorySnapshot> read() async => data;

  @override
  Future<InventorySnapshot> update(
    InventorySnapshot Function(InventorySnapshot) change, {
    int? expectedRevision,
  }) async {
    if (expectedRevision != data.revision) {
      throw const StaleInventoryException();
    }
    final candidate = change(data);
    data = InventorySnapshot(
      revision: data.revision + 1,
      packets: candidate.packets,
    );
    return data;
  }
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.windows,
  ]) {
    testWidgets('native packet catalog on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final store = MemoryStore();
        store.data = InventorySnapshot(
          revision: 0,
          packets: [
            SeedPacket(
              id: 'a',
              crop: 'Pea',
              variety: 'Sugar',
              supplier: 'Farm',
              location: 'Drawer',
              initialCount: 12,
            ),
          ],
        );
        await tester.pumpWidget(SeedStashApp(store: store));
        await tester.pumpAndSettle();
        expect(find.textContaining('Pea · Sugar'), findsOneWidget);
        expect(find.text('Add packet'), findsOneWidget);
        switch (platform) {
          case TargetPlatform.iOS:
            expect(find.byType(CupertinoApp), findsOneWidget);
            expect(find.byType(CupertinoButton), findsWidgets);
            expect(find.byType(MaterialApp), findsNothing);
          case TargetPlatform.windows:
            expect(find.byType(fluent.FluentApp), findsOneWidget);
            expect(find.byType(fluent.Button), findsWidgets);
            expect(find.byType(MaterialApp), findsNothing);
          case TargetPlatform.android:
            expect(find.byType(MaterialApp), findsOneWidget);
            expect(find.byType(TextButton), findsWidgets);
            expect(find.byType(CupertinoApp), findsNothing);
          default:
            fail('unexpected platform');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('packet entry validates and saves to local store', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final store = MemoryStore();
      await tester.pumpWidget(SeedStashApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add packet'));
      await tester.pumpAndSettle();
      for (final entry in <String, String>{
        'Crop': 'Pepper',
        'Variety': 'Shishito',
        'Supplier': 'Farm',
        'Location': 'Drawer',
        'Seed count': '24',
      }.entries) {
        await tester.enterText(
          find.widgetWithText(TextField, entry.key),
          entry.value,
        );
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.data.packets.single.crop, 'Pepper');
      expect(store.data.packets.single.initialCount, 24);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('germination and shopping survive changes on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    try {
      final store = MemoryStore();
      store.data = InventorySnapshot(
        revision: 0,
        packets: [
          SeedPacket(
            id: 'a',
            crop: 'Pea',
            variety: 'Sugar',
            supplier: 'Farm',
            location: 'Drawer',
            initialCount: 12,
          ),
        ],
      );
      await tester.pumpWidget(SeedStashApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pea · Sugar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log germination test'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Seeds tested'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Seeds sprouted'),
        '7',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.data.packets.single.samples.single.measuredPercent, 70);
      expect(find.textContaining('7/10 sprouted · 70.0%'), findsOneWidget);
      await tester.tap(find.text('Add to shopping list'));
      await tester.pumpAndSettle();
      expect(store.data.packets.single.shopping, isTrue);
      await tester.tap(find.text('Back to packets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shopping list'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pea · Sugar · Farm'), findsOneWidget);
      await tester.tap(find.text('Copy shopping CSV'));
      await tester.pump();
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('phone catalog search and dated sowing persist', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final store = MemoryStore();
      store.data = InventorySnapshot(
        revision: 0,
        packets: [
          SeedPacket(
            id: 'a',
            crop: 'Pea',
            variety: 'Sugar',
            supplier: 'Farm',
            location: 'Drawer',
            initialCount: 12,
          ),
          SeedPacket(
            id: 'b',
            crop: 'Tomato',
            variety: 'Roma',
            supplier: 'Seeds',
            location: 'Shelf',
            initialCount: 5,
          ),
        ],
      );
      await tester.pumpWidget(SeedStashApp(store: store));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'pea');
      await tester.pump();
      expect(find.textContaining('Pea · Sugar'), findsOneWidget);
      expect(find.textContaining('Tomato · Roma'), findsNothing);
      await tester.tap(find.text('Sow Sugar'));
      await tester.pumpAndSettle();
      expect(find.text('Log sowing'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Seeds sown'), '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.data.packets.first.remainingCount, 9);
      expect(store.data.packets.first.adjustments.single.reason, 'Sown');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
