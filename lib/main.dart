import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:fluent_ui/fluent_ui.dart' as fluent;

import 'local_inventory_store.dart';
import 'packet_catalog.dart';
import 'seed_packet.dart';

void main() => runApp(const SeedStashApp());

class SeedStashApp extends StatelessWidget {
  const SeedStashApp({super.key, this.store});

  final LocalInventoryStore? store;

  @override
  Widget build(BuildContext context) {
    final home = PacketLibrary(store: store ?? LocalInventoryStore());
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoApp(
          title: 'Seed Stash',
          home: CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Seed Stash'),
            ),
            child: SafeArea(child: home),
          ),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return fluent.FluentApp(
          title: 'Seed Stash',
          home: fluent.NavigationView(
            titleBar: const fluent.TitleBar(title: Text('Seed Stash')),
            content: home,
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return material.MaterialApp(
          title: 'Seed Stash',
          theme: material.ThemeData(useMaterial3: true),
          home: material.Scaffold(
            appBar: material.AppBar(title: const Text('Seed Stash')),
            body: home,
          ),
        );
    }
  }
}

class PacketLibrary extends StatefulWidget {
  const PacketLibrary({super.key, required this.store});

  final LocalInventoryStore store;

  @override
  State<PacketLibrary> createState() => _PacketLibraryState();
}

class _PacketLibraryState extends State<PacketLibrary> {
  InventorySnapshot? snapshot;
  String? error;
  String query = '';
  String? selectedId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final loaded = await widget.store.read();
      if (mounted) {
        setState(() {
          snapshot = loaded;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Cannot read inventory: $e');
    }
  }

  Future<void> _update(
    InventorySnapshot Function(InventorySnapshot) change,
  ) async {
    try {
      final next = await widget.store.update(
        change,
        expectedRevision: snapshot?.revision,
      );
      if (mounted) {
        setState(() {
          snapshot = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Save failed: $e');
      await _reload();
      if (mounted) setState(() => error = 'Save failed: $e');
    }
  }

  SeedPacket? get selected {
    for (final packet in snapshot?.packets ?? <SeedPacket>[]) {
      if (packet.id == selectedId) return packet;
    }
    return null;
  }

  Future<void> _add() async {
    final crop = TextEditingController();
    final variety = TextEditingController();
    final supplier = TextEditingController();
    final location = TextEditingController();
    final lot = TextEditingController();
    final count = TextEditingController();
    final result = await _formDialog(
      context,
      'New packet',
      [crop, variety, supplier, location, lot, count],
      [
        _field('Crop', crop),
        _field('Variety', variety),
        _field('Supplier', supplier),
        _field('Location', location),
        _field('Lot (optional)', lot),
        _field('Seed count', count),
      ],
    );
    if (result != true || !mounted) return;
    final number = int.tryParse(count.text.trim());
    if ([crop, variety, supplier, location].any((c) => c.text.trim().isEmpty) ||
        number == null ||
        number < 0) {
      setState(
        () => error = 'Enter crop, variety, supplier, location, and a nonnegative seed count.',
      );
      return;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final packet = SeedPacket(
      id: id,
      crop: crop.text.trim(),
      variety: variety.text.trim(),
      supplier: supplier.text.trim(),
      location: location.text.trim(),
      lot: lot.text.trim().isEmpty ? null : lot.text.trim(),
      initialCount: number,
    );
    await _update(
      (old) => InventorySnapshot(
        revision: old.revision,
        packets: [...old.packets, packet],
      ),
    );
    if (mounted && error == null) {
      setState(() => selectedId = packet.id);
    }
  }

  Future<void> _sow(SeedPacket packet) async {
    final amount = TextEditingController(text: '1');
    final date = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final result = await _formDialog(
      context,
      'Log sowing',
      [amount, date],
      [_field('Seeds sown', amount), _field('Date (YYYY-MM-DD)', date)],
    );
    if (result != true || !mounted) return;
    final number = int.tryParse(amount.text.trim());
    final day = DateTime.tryParse(date.text.trim());
    if (number == null ||
        number <= 0 ||
        number > packet.remainingCount ||
        day == null ||
        day.toIso8601String().substring(0, 10) != date.text.trim() ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date.text.trim())) {
      setState(
        () => error =
            'Enter a positive amount at most ${packet.remainingCount} and a valid YYYY-MM-DD date.',
      );
      return;
    }
    await _update(
      (old) => InventorySnapshot(
        revision: old.revision,
        packets: [
          for (final current in old.packets)
            if (current.id == packet.id)
              current.withAdjustment(
                CountAdjustment(date: day, delta: -number, reason: 'Sown'),
              )
            else
              current,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            label: label,
            child: CupertinoTextField(
              controller: controller,
              placeholder: label,
              padding: const EdgeInsets.all(12),
            ),
          ),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: fluent.TextBox(controller: controller, placeholder: label),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: material.TextField(
            controller: controller,
            decoration: material.InputDecoration(labelText: label),
          ),
        );
    }
  }

  Future<bool?> _formDialog(
    BuildContext context,
    String title,
    List<TextEditingController> controllers,
    List<Widget> fields,
  ) {
    final result = _showFormDialog(context, title, fields);
    // Dialog field elements unmount at next frame, after route pop completes.
    result.whenComplete(
      () => WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers) {
          controller.dispose();
        }
      }),
    );
    return result;
  }

  Future<bool?> _showFormDialog(
    BuildContext context,
    String title,
    List<Widget> fields,
  ) {
    final form = SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: fields),
      ),
    );
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(title),
            content: form,
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return fluent.showDialog<bool>(
          context: context,
          builder: (context) => fluent.ContentDialog(
            title: Text(title),
            content: form,
            actions: [
              fluent.Button(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              fluent.FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return material.showDialog<bool>(
          context: context,
          builder: (context) => material.AlertDialog(
            title: Text(title),
            content: form,
            actions: [
              material.TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              material.FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        );
    }
  }

  Widget _button(String label, VoidCallback action) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoButton(onPressed: action, child: Text(label));
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return fluent.Button(onPressed: action, child: Text(label));
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return material.TextButton(onPressed: action, child: Text(label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final packets = searchPackets(snapshot?.packets ?? [], query);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final current = selected;
    final list = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _field(
                'Search crop, variety, supplier, lot, location',
                _searchController,
              ),
              _button('Add packet', _add),
              if (error != null)
                Text(error!, key: const Key('inventory-error')),
            ],
          ),
        ),
        Expanded(
          child: packets.isEmpty
              ? Center(
                  child: Text(
                    snapshot == null && error == null
                        ? 'Loading packets…'
                        : query.isEmpty
                        ? 'Your packet library starts here.'
                        : 'No matching packets.',
                  ),
                )
              : ListView.builder(
                  itemCount: packets.length,
                  itemBuilder: (context, index) {
                    final packet = packets[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _button(
                              '${packet.crop} · ${packet.variety} — ${packet.remainingCount} seeds${lowStock(packet) ? ' · Low stock' : ''}',
                              () {
                                setState(() => selectedId = packet.id);
                              },
                            ),
                          ),
                          _button('Sow ${packet.variety}', () => _sow(packet)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    final detail = current == null
        ? const Center(child: Text('Select a packet.'))
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!wide)
                    _button(
                      'Back to packets',
                      () => setState(() => selectedId = null),
                    ),
                  Text(
                    '${current.crop} · ${current.variety}',
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  Text('Supplier: ${current.supplier}'),
                  Text('Lot: ${current.lot ?? "Unknown"}'),
                  Text('Location: ${current.location}'),
                  Text(
                    'Remaining: ${current.remainingCount} seeds${lowStock(current) ? " · Low stock" : ""}',
                  ),
                  _button('Log sowing', () => _sow(current)),
                  const Text('Count history'),
                  for (final event in current.adjustments)
                    Text(
                      '${event.date.toIso8601String().substring(0, 10)} · ${event.reason}: ${event.delta}',
                    ),
                ],
              ),
            ),
          );
    return wide
        ? Row(
            children: [
              Expanded(flex: 3, child: list),
              Expanded(flex: 2, child: detail),
            ],
          )
        : current == null
        ? list
        : detail;
  }

  final _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchController.removeListener(_searchChanged);
    _searchController.addListener(_searchChanged);
  }

  void _searchChanged() => setState(() => query = _searchController.text);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
