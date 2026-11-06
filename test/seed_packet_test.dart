import 'package:flutter_test/flutter_test.dart';
import 'package:seed_stash/seed_packet.dart';

void main() {
  final today = DateTime.utc(2026, 11, 6);
  SeedPacket packet({
    String id = 'lot-1',
    String crop = 'Tomato',
    String variety = 'Roma',
    String supplier = 'Local seeds',
    String location = 'Tin',
    int initialCount = 10,
    String? lot,
    DateTime? packedOn,
    Iterable<CountAdjustment> adjustments = const [],
    Iterable<GerminationSample> samples = const [],
  }) => SeedPacket(
    id: id,
    crop: crop,
    variety: variety,
    supplier: supplier,
    location: location,
    initialCount: initialCount,
    lot: lot,
    packedOn: packedOn,
    adjustments: adjustments,
    samples: samples,
  );
  CountAdjustment change(int delta, {String reason = 'Sowing'}) =>
      CountAdjustment(date: today, delta: delta, reason: reason);

  group('packet creation', () {
    test('retains identifiers, optional lot/date, and baseline count', () {
      final p = packet(lot: 'ABC', packedOn: today);
      expect(p.id, 'lot-1');
      expect(p.crop, 'Tomato');
      expect(p.variety, 'Roma');
      expect(p.supplier, 'Local seeds');
      expect(p.location, 'Tin');
      expect(p.lot, 'ABC');
      expect(p.packedOn, today);
      expect(p.initialCount, 10);
      expect(p.remainingCount, 10);
      expect(packet().lot, isNull);
      expect(packet().packedOn, isNull);
    });

    test('rejects blank required fields and negative baseline', () {
      for (final invalid in [
        () => packet(id: '  '),
        () => packet(crop: ''),
        () => packet(variety: '\n'),
        () => packet(supplier: ' '),
        () => packet(location: ' '),
        () => packet(initialCount: -1),
      ]) {
        expect(invalid, throwsArgumentError);
      }
      expect(packet(initialCount: 0).remainingCount, 0);
    });
  });

  group('dated count adjustments', () {
    test('calculates sowing and refill from immutable event log', () {
      final original = packet();
      final sown = original.withAdjustment(change(-4));
      final corrected = sown.withAdjustment(change(2, reason: 'Recount'));
      expect(original.remainingCount, 10);
      expect(original.adjustments, isEmpty);
      expect(sown.remainingCount, 6);
      expect(corrected.remainingCount, 8);
      expect(corrected.adjustments.map((e) => e.delta), [-4, 2]);
      expect(corrected.adjustments.last.reason, 'Recount');
      expect(corrected.adjustments.last.date, today);
      expect(() => corrected.adjustments.clear(), throwsUnsupportedError);
    });

    test('snapshots caller-owned history', () {
      final input = [change(-1)];
      final p = packet(adjustments: input);
      input.add(change(-2));
      expect(p.remainingCount, 9);
      expect(p.adjustments, hasLength(1));
    });

    test(
      'rejects zero, blank reason, overdrafts, and intermediate overdraft',
      () {
        expect(() => change(0), throwsArgumentError);
        expect(() => change(1, reason: '  '), throwsArgumentError);
        expect(() => packet().withAdjustment(change(-11)), throwsStateError);
        expect(
          () => packet(adjustments: [change(-11), change(11)]),
          throwsStateError,
        );
        expect(
          packet(initialCount: 0).withAdjustment(change(1)).remainingCount,
          1,
        );
      },
    );
  });

  group('germination sample', () {
    test('calculates measured percentage, including zero sprouted', () {
      final sample = GerminationSample(date: today, tested: 8, sprouted: 3);
      expect(sample.measuredPercent, 37.5);
      expect(sample.date, today);
      expect(
        GerminationSample(date: today, tested: 4, sprouted: 0).measuredPercent,
        0,
      );
      expect(
        GerminationSample(date: today, tested: 1, sprouted: 1).measuredPercent,
        100,
      );
    });

    test('zero tested is unknown, not 0 percent', () {
      expect(
        GerminationSample(date: today, tested: 0, sprouted: 0).measuredPercent,
        isNull,
      );
    });

    test('rejects negative and impossible sample counts', () {
      for (final counts in [(-1, 0), (1, -1), (1, 2), (0, 1)]) {
        expect(
          () => GerminationSample(
            date: today,
            tested: counts.$1,
            sprouted: counts.$2,
          ),
          throwsArgumentError,
        );
      }
    });

    test('samples are immutable and do not alter packet count', () {
      final samples = [GerminationSample(date: today, tested: 5, sprouted: 2)];
      final original = packet();
      final p = original.withSample(samples.single);
      samples.add(GerminationSample(date: today, tested: 0, sprouted: 0));
      expect(original.samples, isEmpty);
      expect(p.samples, hasLength(1));
      expect(() => p.samples.add(samples.last), throwsUnsupportedError);
      expect(p.remainingCount, 10);
      final withAdjustment = p.withAdjustment(change(-1));
      expect(withAdjustment.samples, hasLength(1));
      expect(withAdjustment.remainingCount, 9);
    });
  });
}
