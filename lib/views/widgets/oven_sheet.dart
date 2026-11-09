import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/product.dart';
import '../../viewmodels/gameplay_view_model.dart';
import 'craft_sheet.dart';
import 'product_icon.dart';

/// Panel oven: pilih roti + jumlah loyang, mini-game adonan, panggang beberapa roti sekaligus.
class OvenSheet extends StatefulWidget {
  const OvenSheet({super.key});

  @override
  State<OvenSheet> createState() => _OvenSheetState();
}

class _OvenSheetState extends State<OvenSheet> {
  String? _msg;
  Product? _food;
  int _trays = 1;

  Future<void> _bake(GameplayViewModel vm, int slot, Product food) async {
    if (vm.flour < _trays) {
      setState(() => _msg = 'Tepung kurang (butuh $_trays, punya ${vm.flour}). Beli di Toko > Stok.');
      return;
    }
    final q = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF34231A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => CraftSheet(product: food, machineLevel: vm.machineBonus),
    );
    if (q == null || !mounted) return; // dibatalkan: tepung tidak terpakai
    setState(() => _msg = vm.startBake(slot, food, trays: _trays, doughQuality: q));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GameplayViewModel>();
    final foods = vm.availableProducts.where((p) => p.isFood).toList();
    _food ??= foods.isEmpty ? null : foods.first;
    final food = _food;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🔥 Oven & Etalase', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            const Icon(Icons.bakery_dining, size: 16, color: Colors.white70),
            Text(' ${vm.flour}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          const Text('Cara: ① pilih roti & jumlah loyang → ② mini-game adonan → ③ tunggu matang → ④ ANGKAT → ⑤ ketuk roti di bar bawah untuk menyajikan.',
              style: TextStyle(fontSize: 11.5, color: Colors.white60, height: 1.3)),
          const SizedBox(height: 10),
          Text('Etalase: ${vm.displayCount}/${vm.displayCapacity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFFD54F))),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            for (final f in foods)
              Chip(
                avatar: ProductIcon(f, size: 22),
                label: Text('${f.label} x${vm.stockOf(f)}', style: const TextStyle(fontSize: 11.5)),
                visualDensity: VisualDensity.compact,
              ),
          ]),
          const Divider(height: 22),
          const Text('1. Pilih roti', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final f in foods)
              ChoiceChip(
                avatar: ProductIcon(f, size: 24),
                label: Text('${f.label} (${f.bakeSeconds.toInt()} dtk)', style: const TextStyle(fontSize: 12)),
                selected: _food == f,
                onSelected: (_) => setState(() => _food = f),
              ),
          ]),
          const SizedBox(height: 10),
          const Text('2. Jumlah loyang (1 loyang = 3 roti)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [for (final n in [1, 2, 3]) ButtonSegment(value: n, label: Text('$n loyang\n${n * 3} roti', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)))],
            selected: {_trays},
            onSelectionChanged: (s) => setState(() => _trays = s.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Memakai $_trays tepung • waktu panggang +${((_trays - 1) * 2.5).toStringAsFixed(1)} dtk', style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_msg!, style: const TextStyle(fontSize: 12.5, color: Colors.amberAccent)),
            ),
          const Divider(height: 22),
          for (var i = 0; i < vm.ovens.length; i++) _slot(vm, i, food),
        ]),
      ),
    );
  }

  Widget _slot(GameplayViewModel vm, int i, Product? food) {
    final o = vm.ovens[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
      child: switch (o.state) {
        OvenState.idle => Row(children: [
            Expanded(child: Text('Slot ${i + 1}: kosong', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            FilledButton.icon(
              onPressed: food == null ? null : () => _bake(vm, i, food),
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: Text('Panggang ${food?.label ?? ''} x$_trays', style: const TextStyle(fontSize: 12)),
            ),
          ]),
        OvenState.baking => Row(children: [
            ProductIcon(o.item!, size: 28),
            const SizedBox(width: 8),
            Text('Slot ${i + 1}: ${o.item!.label} x${o.trays * 3}  ', style: const TextStyle(fontSize: 12.5)),
            Expanded(
              child: AnimatedBuilder(
                animation: vm.frame,
                builder: (_, __) => LinearProgressIndicator(value: o.progress, minHeight: 8, color: Colors.orangeAccent, backgroundColor: Colors.white12),
              ),
            ),
          ]),
        OvenState.ready => Row(children: [
            ProductIcon(o.item!, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text('Slot ${i + 1}: ${o.item!.label} x${o.trays * 3} matang! Angkat sebelum gosong.', style: const TextStyle(fontSize: 12.5))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () => setState(() => _msg = vm.collectOven(i)),
              child: const Text('ANGKAT'),
            ),
          ]),
        OvenState.burnt => Row(children: [
            const Text('💨', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(child: Text('Slot ${i + 1}: roti gosong!', style: const TextStyle(fontSize: 12.5))),
            OutlinedButton(onPressed: () => setState(() => _msg = vm.collectOven(i)), child: const Text('Buang')),
          ]),
      },
    );
  }
}
