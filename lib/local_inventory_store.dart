import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import 'seed_packet.dart';

/// Immutable snapshot. Revision detects stale edits across store instances.
class InventorySnapshot {
  InventorySnapshot({
    required this.revision,
    required Iterable<SeedPacket> packets,
  }) : packets = List.unmodifiable(packets) {
    if (revision < 0) {
      throw const FormatException('Invalid revision');
    }
    final ids = <String>{};
    for (final packet in this.packets) {
      if (!ids.add(packet.id)) {
        throw FormatException('Duplicate packet ID: ${packet.id}');
      }
    }
  }

  final int revision;
  final List<SeedPacket> packets;
}

class StaleInventoryException implements Exception {
  const StaleInventoryException();

  @override
  String toString() => 'Inventory changed; reload before saving';
}

/// App-private storage only. No network APIs or external paths in production.
class LocalInventoryStore {
  LocalInventoryStore({this.directory});

  final Directory? directory;
  static const _filename = 'inventory.json';
  static const _version = 3;
  static Future<void>? _inProcessQueue;

  Future<Directory> _home() async =>
      directory ?? await getApplicationSupportDirectory();

  /// Reads hold same OS file lock as writes, so migration and saves never race.
  Future<InventorySnapshot> read() => _locked((home) async {
    final snapshot = await _read(home);
    return snapshot;
  });

  /// Export complete inventory without exposing app-private file paths.
  Future<String> exportBackup() => _locked((home) async {
    final snapshot = await _read(home);
    return jsonEncode({
      'version': _version,
      'revision': snapshot.revision,
      'packets': snapshot.packets.map(_encodePacket).toList(),
    });
  });

  /// Validate entire backup before returning preview. No disk writes.
  InventorySnapshot previewBackup(String backup) {
    final root = _object(jsonDecode(backup));
    if (_integer(root['version']) != _version) {
      throw const FormatException('Unsupported backup version');
    }
    final raw = root['packets'];
    if (raw is! List) throw const FormatException('Invalid packets');
    return InventorySnapshot(
      revision: _integer(root['revision']),
      packets: raw.map((entry) => _packet(_object(entry), _version)),
    );
  }

  /// Reject stale preview if inventory changed while confirmation was open.
  Future<InventorySnapshot> restoreBackup(
    InventorySnapshot preview, {
    required int expectedRevision,
  }) => update(
    (current) =>
        InventorySnapshot(revision: current.revision, packets: preview.packets),
    expectedRevision: expectedRevision,
  );

  Future<String> exportCsv() async {
    final snapshot = await read();
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      [
        'id',
        'crop',
        'variety',
        'supplier',
        'lot',
        'packedOn',
        'location',
        'remainingCount',
        'shopping',
      ],
      for (final p in snapshot.packets)
        [
          p.id,
          p.crop,
          p.variety,
          p.supplier,
          p.lot,
          p.packedOn?.toIso8601String(),
          p.location,
          p.remainingCount,
          p.shopping,
        ],
    ];
    return '${rows.map((row) => row.map(cell).join(',')).join('\r\n')}\r\n';
  }

  /// Synchronous mutation runs under cross-process lock; never await in [change].
  /// Pass expectedRevision for user edits to reject stale forms rather than
  /// silently applying them to an inventory updated elsewhere.
  Future<InventorySnapshot> update(
    InventorySnapshot Function(InventorySnapshot) change, {
    int? expectedRevision,
  }) => _locked((home) async {
    final previous = await _read(home);
    if (expectedRevision != null && expectedRevision != previous.revision) {
      throw const StaleInventoryException();
    }
    final candidate = change(previous);
    if (candidate.revision != previous.revision) {
      throw const FormatException('Mutation must retain current revision');
    }
    if (previous.revision == 0x7fffffffffffffff) {
      throw const FormatException('Revision overflow');
    }
    final next = InventorySnapshot(
      revision: previous.revision + 1,
      packets: candidate.packets,
    );
    await _save(home, next);
    return next;
  });

  Future<T> _locked<T>(Future<T> Function(Directory) action) async {
    // Dart file locks may succeed twice within one process. Serialize those
    // callers before taking OS lock, which coordinates other processes.
    final prior = _inProcessQueue;
    final done = Completer<void>();
    _inProcessQueue = done.future;
    if (prior != null) await prior;
    try {
      final home = await _home();
      await home.create(recursive: true);
      final lock = await File('${home.path}/inventory.lock')
          .open(mode: FileMode.append);
      try {
        await lock.lock(FileLock.exclusive);
        return await action(home);
      } finally {
        await lock.unlock();
        await lock.close();
      }
    } finally {
      done.complete();
    }
  }

  Future<InventorySnapshot> _read(Directory home) async {
    final file = File('${home.path}/$_filename');
    if (!await file.exists()) {
      return InventorySnapshot(revision: 0, packets: []);
    }
    // Never overwrite corrupt/unsupported data. Errors propagate to caller.
    final root = _object(jsonDecode(await file.readAsString()));
    final version = _integer(root['version']);
    if (version != 1 && version != 2 && version != _version) {
      throw FormatException('Unsupported inventory version: $version');
    }
    final raw = root['packets'];
    if (raw is! List) throw const FormatException('Invalid packets');
    final snapshot = InventorySnapshot(
      revision: version == 1 ? 0 : _integer(root['revision']),
      packets: raw.map((entry) => _packet(_object(entry), version)),
    );
    if (version != _version) await _save(home, snapshot);
    return snapshot;
  }

  Future<void> _save(Directory home, InventorySnapshot snapshot) async {
    final target = File('${home.path}/$_filename');
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final temporary = File('${target.path}.$suffix.tmp');
    try {
      // Same-directory rename replaces prior file atomically on supported
      // platforms. Flush bytes before rename; never truncate old inventory.
      await temporary.writeAsString(
        jsonEncode({
          'version': _version,
          'revision': snapshot.revision,
          'packets': snapshot.packets.map(_encodePacket).toList(),
        }),
        flush: true,
      );
      await temporary.rename(target.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid object');
  }
  return value;
}

String _string(Object? value) {
  if (value is! String) throw const FormatException('Invalid string');
  return value;
}

int _integer(Object? value) {
  if (value is! int) throw const FormatException('Invalid integer');
  return value;
}

bool _boolean(Object? value) {
  if (value is! bool) throw const FormatException('Invalid boolean');
  return value;
}

String? _optionalString(Object? value) => value == null ? null : _string(value);

DateTime _date(Object? value) {
  final raw = _string(value);
  final date = DateTime.tryParse(raw);
  if (date == null || date.toIso8601String() != raw) {
    throw const FormatException('Invalid date');
  }
  return date;
}

SeedPacket _packet(Map<String, Object?> data, int version) {
  final adjustments = data['adjustments'];
  final samples = data['samples'];
  if (adjustments is! List || samples is! List) {
    throw const FormatException('Invalid packet history');
  }
  return SeedPacket(
    id: _string(data['id']),
    crop: _string(data['crop']),
    variety: _string(data['variety']),
    supplier: _string(data['supplier']),
    location: _string(data['location']),
    lot: _optionalString(data['lot']),
    packedOn: data['packedOn'] == null ? null : _date(data['packedOn']),
    shopping: version < 3 ? false : _boolean(data['shopping']),
    initialCount: _integer(data['initialCount']),
    adjustments: adjustments.map((item) {
      final entry = _object(item);
      return CountAdjustment(
        date: _date(entry['date']),
        delta: _integer(entry['delta']),
        reason: _string(entry['reason']),
      );
    }),
    samples: samples.map((item) {
      final entry = _object(item);
      return GerminationSample(
        date: _date(entry['date']),
        tested: _integer(entry['tested']),
        sprouted: _integer(entry['sprouted']),
      );
    }),
  );
}

Map<String, Object?> _encodePacket(SeedPacket packet) => {
  'id': packet.id,
  'crop': packet.crop,
  'variety': packet.variety,
  'supplier': packet.supplier,
  'location': packet.location,
  'lot': packet.lot,
  'packedOn': packet.packedOn?.toIso8601String(),
  'shopping': packet.shopping,
  'initialCount': packet.initialCount,
  'adjustments': [
    for (final item in packet.adjustments)
      {
        'date': item.date.toIso8601String(),
        'delta': item.delta,
        'reason': item.reason,
      },
  ],
  'samples': [
    for (final item in packet.samples)
      {
        'date': item.date.toIso8601String(),
        'tested': item.tested,
        'sprouted': item.sprouted,
      },
  ],
};
