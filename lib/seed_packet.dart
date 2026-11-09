/// Pure, offline seed-packet inventory rules. Samples measure only seeds tested;
/// they do not predict viability of a whole packet.
class SeedPacket {
  SeedPacket({
    required this.id,
    required this.crop,
    required this.variety,
    required this.supplier,
    required this.location,
    required this.initialCount,
    this.lot,
    this.packedOn,
    this.shopping = false,
    Iterable<CountAdjustment> adjustments = const [],
    Iterable<GerminationSample> samples = const [],
  }) : adjustments = List.unmodifiable(adjustments),
       samples = List.unmodifiable(samples) {
    _required(id, 'id');
    _required(crop, 'crop');
    _required(variety, 'variety');
    _required(supplier, 'supplier');
    _required(location, 'location');
    if (initialCount < 0) {
      throw ArgumentError.value(initialCount, 'initialCount', 'Must be >= 0');
    }
    // Validate history in insertion order; a later refill cannot erase an
    // earlier negative balance.
    var balance = initialCount;
    for (final adjustment in this.adjustments) {
      balance = _apply(balance, adjustment.delta);
    }
  }

  final String id;
  final String crop;
  final String variety;
  final String supplier;
  final String location;
  final int initialCount;
  final String? lot;
  final DateTime? packedOn;
  final bool shopping;
  final List<CountAdjustment> adjustments;
  final List<GerminationSample> samples;

  int get remainingCount {
    var balance = initialCount;
    for (final adjustment in adjustments) {
      balance = _apply(balance, adjustment.delta);
    }
    return balance;
  }

  SeedPacket withAdjustment(CountAdjustment adjustment) =>
      _copy(adjustments: [...adjustments, adjustment]);

  SeedPacket withSample(GerminationSample sample) =>
      _copy(samples: [...samples, sample]);

  SeedPacket withShopping(bool value) => _copy(shopping: value);

  SeedPacket _copy({
    List<CountAdjustment>? adjustments,
    List<GerminationSample>? samples,
    bool? shopping,
  }) => SeedPacket(
    id: id,
    crop: crop,
    variety: variety,
    supplier: supplier,
    location: location,
    initialCount: initialCount,
    lot: lot,
    packedOn: packedOn,
    shopping: shopping ?? this.shopping,
    adjustments: adjustments ?? this.adjustments,
    samples: samples ?? this.samples,
  );
}

class CountAdjustment {
  CountAdjustment({
    required this.date,
    required this.delta,
    required this.reason,
  }) {
    _required(reason, 'reason');
    if (delta == 0) {
      throw ArgumentError.value(delta, 'delta', 'Must be nonzero');
    }
  }

  final DateTime date;
  final int delta; // Negative for sowing; positive for corrected estimates.
  final String reason;
}

class GerminationSample {
  GerminationSample({
    required this.date,
    required this.tested,
    required this.sprouted,
  }) {
    if (tested < 0) {
      throw ArgumentError.value(tested, 'tested', 'Must be >= 0');
    }
    if (sprouted < 0 || sprouted > tested) {
      throw ArgumentError.value(
        sprouted,
        'sprouted',
        'Must be between 0 and tested',
      );
    }
  }

  final DateTime date;
  final int tested;
  final int sprouted;

  /// Null when no seeds were tested; not a prediction of packet viability.
  double? get measuredPercent => tested == 0 ? null : sprouted / tested * 100;
}

void _required(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be blank');
  }
}

int _apply(int balance, int delta) {
  final next = balance + delta;
  if (next < 0) {
    throw StateError('Adjustment would make remaining count negative');
  }
  return next;
}
