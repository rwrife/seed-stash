import 'package:flutter_test/flutter_test.dart';
import 'package:seed_stash/packet_catalog.dart';
import 'package:seed_stash/seed_packet.dart';

void main() {
  SeedPacket packet(String id, String crop, String variety, int count) =>
      SeedPacket(
        id: id,
        crop: crop,
        variety: variety,
        supplier: 'Farmhouse',
        lot: '2026-A',
        location: 'Cold drawer',
        initialCount: count,
      );

  test('multi-field case-insensitive substring search retains packet IDs', () {
    final packets = [
      packet('b', 'Tomato', 'Sungold', 11),
      packet('a', 'Pea', 'Sugar', 10),
    ];
    expect(searchPackets(packets, 'FARM cold').length, 2);
    expect(searchPackets(packets, 'TOM sun').single.id, 'b');
    expect(searchPackets(packets, '2026-a pea').single.id, 'a');
    expect(searchPackets(packets, '').map((p) => p.id), ['a', 'b']);
    expect(lowStock(packets.last), isTrue);
    expect(lowStock(packets.first), isFalse);
  });

  test('shopping includes flagged or exhausted; CSV escapes fields', () {
    final flagged = SeedPacket(
      id: 'flagged',
      crop: 'Pea',
      variety: 'Sugar, "Snap"',
      supplier: 'Farmhouse',
      location: 'Drawer',
      initialCount: 20,
      shopping: true,
    );
    final exhausted = packet('empty', 'Tomato', 'Roma', 0);
    final stocked = packet('stocked', 'Carrot', 'Nantes', 4);
    expect(shoppingPackets([flagged, exhausted, stocked]).map((p) => p.id), [
      'flagged',
      'empty',
    ]);
    expect(
      shoppingExport([flagged, exhausted, stocked]),
      contains('Pea · Sugar, "Snap"'),
    );
    expect(
      shoppingExport([flagged, exhausted, stocked], csv: true),
      contains('"Sugar, ""Snap"""'),
    );
    expect(flagged.withShopping(false).shopping, isFalse);
    expect(shoppingPackets([flagged.withShopping(false), stocked]), isEmpty);
  });

  test('sowing appends dated count event, prevents negative balance', () {
    final original = packet('a', 'Pea', 'Sugar', 10);
    final event = CountAdjustment(
      date: DateTime.utc(2026, 11, 8),
      delta: -3,
      reason: 'Sown',
    );
    final updated = original.withAdjustment(event);
    expect(updated.remainingCount, 7);
    expect(updated.adjustments.single.date, DateTime.utc(2026, 11, 8));
    expect(original.remainingCount, 10);
    expect(
      () => updated.withAdjustment(
        CountAdjustment(date: event.date, delta: -8, reason: 'Sown'),
      ),
      throwsStateError,
    );
  });
}
