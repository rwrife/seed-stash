import 'seed_packet.dart';

/// Case-insensitive substring search across packet identity, provenance, and
/// location/lot tags. Space-separated terms may match different fields.
List<SeedPacket> searchPackets(Iterable<SeedPacket> packets, String query) {
  final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
  final matches = [
    for (final packet in packets)
      if (terms.every(
        (term) => [
          packet.crop,
          packet.variety,
          packet.supplier,
          packet.lot ?? '',
          packet.location,
          packet.id,
        ].any((field) => field.toLowerCase().contains(term)),
      ))
        packet,
  ];
  matches.sort((a, b) {
    final crop = a.crop.toLowerCase().compareTo(b.crop.toLowerCase());
    return crop != 0
        ? crop
        : a.variety.toLowerCase().compareTo(b.variety.toLowerCase());
  });
  return matches;
}

/// Fixed UI warning threshold, not an estimate of packet viability.
bool lowStock(SeedPacket packet) => packet.remainingCount <= 10;

List<SeedPacket> shoppingPackets(Iterable<SeedPacket> packets) => [
  for (final packet in packets)
    if (packet.shopping || packet.remainingCount == 0) packet,
];

String shoppingExport(Iterable<SeedPacket> packets, {bool csv = false}) {
  final selected = shoppingPackets(packets);
  if (!csv) {
    return selected
        .map(
          (p) =>
              '${p.crop} · ${p.variety} (${p.supplier}, ${p.lot ?? "lot unknown"})',
        )
        .join('\n');
  }
  String cell(String value) => '"${value.replaceAll('"', '""')}"';
  return [
    'Crop,Variety,Supplier,Lot,Remaining',
    for (final p in selected)
      [
        p.crop,
        p.variety,
        p.supplier,
        p.lot ?? '',
        '${p.remainingCount}',
      ].map(cell).join(','),
  ].join('\r\n');
}
