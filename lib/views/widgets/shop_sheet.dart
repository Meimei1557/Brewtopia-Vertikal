import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/decor.dart';
import '../../data/models/upgrade.dart';
import '../../viewmodels/gameplay_view_model.dart';
import 'product_icon.dart';

/// Toko: Upgrade, Dekor (estetika), Stok bahan (bergambar), dan Misi harian.
class ShopSheet extends StatelessWidget {
  const ShopSheet({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GameplayViewModel>();
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.66,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                const Text('🏪 Toko Kafe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 18),
                    const SizedBox(width: 4),
                    Text('${vm.money}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
            TabBar(
              labelPadding: EdgeInsets.zero,
              indicatorColor: const Color(0xFFFFD54F),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              tabs: [
                const Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Upgrade', height: 46),
                const Tab(icon: Icon(Icons.chair_alt, size: 18), text: 'Dekor', height: 46),
                const Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Stok', height: 46),
                Tab(
                  height: 46,
                  child: Stack(clipBehavior: Clip.none, children: [
                    const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.flag, size: 18), Text('Misi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
                    if (vm.missionClaimable) Positioned(right: -8, top: 0, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))),
                  ]),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(children: [
                _UpgradeTab(vm: vm),
                _DecorTab(vm: vm),
                _StockTab(vm: vm),
                _MissionTab(vm: vm),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.leading, required this.title, required this.subtitle, required this.action, this.badge});
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget action;
  final String? badge;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(14)),
            child: Center(child: leading),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              if (badge != null) Text(badge!, style: const TextStyle(fontSize: 10.5, color: Color(0xFFFFD54F), fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white60, height: 1.25)),
            ]),
          ),
          const SizedBox(width: 8),
          action,
        ]),
      );
}

ButtonStyle _buy(bool ok) => FilledButton.styleFrom(
      minimumSize: const Size(64, 38),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      backgroundColor: ok ? const Color(0xFF8B6239) : Colors.grey.shade700,
    );

class _UpgradeTab extends StatelessWidget {
  const _UpgradeTab({required this.vm});
  final GameplayViewModel vm;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        for (final t in UpgradeType.values)
          Builder(builder: (_) {
            final lvl = vm.upgradeLevel(t);
            final maxed = lvl >= t.maxLevel;
            final cost = t.costForLevel(lvl);
            return _Card(
              leading: Icon(t.icon, color: const Color(0xFFFFD54F), size: 28),
              title: t.title,
              badge: 'Level $lvl / ${t.maxLevel}',
              subtitle: t.description,
              action: FilledButton(
                onPressed: maxed ? null : () => vm.buyUpgrade(t),
                style: _buy(vm.money >= cost),
                child: Text(maxed ? 'MAX' : '🪙 $cost'),
              ),
            );
          }),
      ]);
}

class _DecorTab extends StatelessWidget {
  const _DecorTab({required this.vm});
  final GameplayViewModel vm;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF6D4C41).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
          child: Text('✨ Estetika kafe: ${vm.aesthetic}\nLebih estetik = pelanggan lebih sering datang, tip lebih besar, dan mereka betah nongkrong.',
              style: const TextStyle(fontSize: 12, height: 1.3)),
        ),
        for (final d in Decor.values)
          Builder(builder: (_) {
            final owned = vm.hasDecor(d);
            final locked = vm.level < d.levelNeeded;
            return _Card(
              leading: Text(d.emoji, style: const TextStyle(fontSize: 28)),
              title: d.title,
              badge: '+${d.aesthetic} estetika${locked ? '  •  butuh Lv ${d.levelNeeded}' : ''}',
              subtitle: d.desc,
              action: owned
                  ? const Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 28)
                  : FilledButton(
                      onPressed: locked ? null : () => vm.buyDecor(d),
                      style: _buy(vm.money >= d.cost),
                      child: Text(locked ? '🔒' : '🪙 ${d.cost}'),
                    ),
            );
          }),
      ]);
}

class _StockTab extends StatelessWidget {
  const _StockTab({required this.vm});
  final GameplayViewModel vm;

  int _have(StockItem i) => switch (i) {
        StockItem.beans => vm.beans,
        StockItem.milk => vm.milk,
        StockItem.flour => vm.flour,
      };

  String _usage(StockItem i) => switch (i) {
        StockItem.beans => 'Dipakai 1 untuk setiap kopi yang kamu racik.',
        StockItem.milk => 'Macchiato 1, cappuccino 1, latte 2.',
        StockItem.flour => '1 tepung = 1 loyang = 3 roti.',
      };

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF6D4C41).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
          child: const Text('Bahan habis = tidak bisa membuat pesanan. Isi stok sebelum kehabisan!', style: TextStyle(fontSize: 12, height: 1.3)),
        ),
        for (final i in StockItem.values)
          _Card(
            leading: StockIcon(i, size: 42),
            title: '${i.label}: ${_have(i)}',
            badge: '+${i.packSize} per pembelian',
            subtitle: _usage(i),
            action: FilledButton(
              onPressed: () => vm.buyStock(i),
              style: _buy(vm.money >= i.packCost),
              child: Text('🪙 ${i.packCost}'),
            ),
          ),
      ]);
}

class _MissionTab extends StatelessWidget {
  const _MissionTab({required this.vm});
  final GameplayViewModel vm;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF6D4C41).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
          child: Text('🎯 Misi harian (ganti tiap hari)\nStreak login: ${vm.snapshot.streak} hari 🔥  •  Target hari ini: ${vm.dayEarned}/${vm.dayTarget} koin',
              style: const TextStyle(fontSize: 12, height: 1.3)),
        ),
        for (var i = 0; i < vm.missions.length; i++)
          Builder(builder: (_) {
            final m = vm.missions[i];
            return _Card(
              leading: Text(m.def.icon, style: const TextStyle(fontSize: 28)),
              title: m.def.label,
              badge: '${m.progress}/${m.def.target}',
              subtitle: m.claimed ? 'Sudah diambil' : (m.done ? 'Selesai! Ambil hadiahmu.' : 'Hadiah: ${m.def.reward} koin'),
              action: m.claimed
                  ? const Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 28)
                  : FilledButton(
                      onPressed: m.done ? () => vm.claimMission(i) : null,
                      style: FilledButton.styleFrom(minimumSize: const Size(64, 38), backgroundColor: Colors.green.shade700),
                      child: Text('+${m.def.reward}'),
                    ),
            );
          }),
      ]);
}
