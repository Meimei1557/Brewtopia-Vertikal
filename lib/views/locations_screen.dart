import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/location_service.dart';
import '../data/models/game_snapshot.dart';
import '../viewmodels/locations_view_model.dart';

/// Banyak lokasi kafe favorit: simpan tempat nongkrongmu, check-in harian di tiap titik.
class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  Future<void> _addDialog(BuildContext context, LocationsViewModel vm) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan lokasi ini'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama tempat', hintText: 'mis. Kopi Kenangan, Kampus'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Simpan')),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null) await vm.addSpotHere(name);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LocationsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOKASI KAFE'),
        actions: [
          IconButton(
            tooltip: 'Perbarui lokasi',
            onPressed: vm.locating ? null : vm.refreshLocation,
            icon: vm.locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.locating ? null : () => _addDialog(context, vm),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Simpan di sini'),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 90), children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.place, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text(vm.city != null ? 'Kotamu: ${vm.city}' : 'Lokasi belum diketahui', style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Simpan tempat nongkrong favoritmu (maks. ${LocationsViewModel.maxSpots}). Datangi dan check-in tiap hari: dapat koin + bonus pendapatan x1.5 selama 30 menit.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (vm.bonusActive)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('⚡ Bonus pendapatan x1.5 sedang aktif!', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              if (vm.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(vm.message!, style: const TextStyle(color: Colors.amberAccent, fontSize: 12.5)),
                ),
              if (vm.status == LocationStatus.deniedForever)
                TextButton(onPressed: () => context.read<LocationsViewModel>().openSettings(), child: const Text('Buka pengaturan aplikasi')),
              const SizedBox(height: 10),
              if (vm.spots.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(children: [
                    Icon(Icons.map_outlined, size: 54, color: Colors.white38),
                    SizedBox(height: 10),
                    Text('Belum ada lokasi tersimpan.\nPergi ke kafe favoritmu lalu tekan "Simpan di sini".', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  ]),
                ),
              for (var i = 0; i < vm.spots.length; i++) _SpotCard(vm: vm, index: i, spot: vm.spots[i]),
            ]),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.vm, required this.index, required this.spot});
  final LocationsViewModel vm;
  final int index;
  final CafeSpot spot;

  @override
  Widget build(BuildContext context) {
    final d = vm.distanceTo(spot);
    final done = vm.checkedToday(spot);
    final near = d != null && d <= LocationsViewModel.radiusMeters;
    final status = done ? '✅ Sudah check-in hari ini' : (d == null ? 'Tekan 🎯 untuk cek jarak' : (near ? '📍 Dalam jangkauan!' : '${d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m'} dari sini'));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: near && !done ? Border.all(color: Colors.lightGreenAccent) : null,
      ),
      child: Row(children: [
        const Text('☕', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(spot.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text(status, style: TextStyle(fontSize: 11.5, color: near && !done ? Colors.lightGreenAccent : Colors.white60)),
          ]),
        ),
        FilledButton(
          onPressed: done || vm.locating ? null : () => vm.checkIn(index),
          style: FilledButton.styleFrom(minimumSize: const Size(72, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text(done ? 'Selesai' : 'Check-in', style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          tooltip: 'Hapus',
          visualDensity: VisualDensity.compact,
          onPressed: () => vm.removeSpot(index),
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      ]),
    );
  }
}
