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
