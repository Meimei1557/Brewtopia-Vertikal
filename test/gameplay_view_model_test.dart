import 'dart:math';

import 'package:brewtopia/data/models/customer.dart';
import 'package:brewtopia/data/models/decor.dart';
import 'package:brewtopia/data/models/game_event.dart';
import 'package:brewtopia/data/models/game_snapshot.dart';
import 'package:brewtopia/data/models/mission.dart';
import 'package:brewtopia/data/models/product.dart';
import 'package:brewtopia/data/models/upgrade.dart';
import 'package:brewtopia/data/repositories/auth_repository.dart';
import 'package:brewtopia/data/repositories/cloud_repository.dart';
import 'package:brewtopia/data/repositories/game_repository.dart';
import 'package:brewtopia/viewmodels/gameplay_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGameRepository implements GameRepository {
  FakeGameRepository(this.snapshot, {this.pendingIdle = 0});
  GameSnapshot snapshot;
  int pendingIdle;
  bool dirty = false;
  String? city;

  @override
  Future<GameSnapshot> load() async => snapshot.copy();
  @override
  Future<void> save(GameSnapshot s) async => snapshot = s.copy();
  @override
  Future<int> takePendingIdleIncome() async {
    final v = pendingIdle;
    pendingIdle = 0;
    return v;
  }

  @override
  Future<void> setCloudDirty(bool d, {String? uid, String? name, String? city}) async => dirty = d;
  @override
  Future<void> rememberCity(String c) async => city = c;
  @override
  String? get cachedCity => city;
  bool barista = false;
  @override
  bool get baristaFemale => barista;
  @override
  Future<void> setBaristaFemale(bool v) async => barista = v;
  @override
  Future<void> clear() async => snapshot = GameSnapshot();
}

GameplayViewModel makeVm(FakeGameRepository repo) =>
    GameplayViewModel(repo, NoopCloudRepository(), OfflineAuthRepository(), random: Random(3));

void runUntil(GameplayViewModel vm, bool Function() cond, {int max = 4000}) {
  for (var i = 0; i < max && !cond(); i++) {
    vm.tick(0.05);
  }
}

bool hasWaiting(GameplayViewModel vm) => vm.customers.any((c) => c.state == CustState.waiting);

void main() {
  test('model: produk terbuka sesuai level', () {
    expect(ProductX.availableAt(1), [Product.espresso, Product.americano, Product.doughnut]);
    expect(ProductX.availableAt(4).length, Product.values.length);
  });

  test('model: snapshot toJson/fromJson bolak-balik', () {
    final s = GameSnapshot(money: 321, level: 3, xp: 12, totalEarned: 999, day: 4, reputation: 4.2)
      ..upgrades['machine'] = 2
      ..decor.add('rug')
      ..display['doughnut'] = 3
      ..spots.add(CafeSpot(name: 'Kampus', lat: -2.99, lng: 104.75));
    final r = GameSnapshot.fromJson(s.toJson());
    expect(r.money, 321);
    expect(r.day, 4);
    expect(r.upgradeLevel(UpgradeType.machine), 2);
    expect(r.hasDecor('rug'), isTrue);
    expect(r.display['doughnut'], 3);
    expect(r.spots.single.name, 'Kampus');
  });

  test('misi harian konsisten untuk tanggal yang sama dan unik per jenis', () {
    final a = generateMissions('2026-11-04', 1);
    final b = generateMissions('2026-11-04', 1);
    expect(a.map((e) => e.kind), b.map((e) => e.kind));
    expect(a.map((e) => e.kind).toSet().length, 3);
  });

  test('pelanggan masuk lewat pintu, berjalan, memesan, lalu menunggu', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    runUntil(vm, () => vm.customers.isNotEmpty);
    final c = vm.customers.first;
    expect(c.state, CustState.arriving);
    final x0 = c.x;
    for (var i = 0; i < 6; i++) {
      vm.tick(0.05);
    }
    expect((c.x - x0).abs() + (c.y - 584).abs(), greaterThan(20)); // benar-benar bergerak
    runUntil(vm, () => c.state == CustState.waiting);
    expect(c.state, CustState.waiting);
    expect(c.items, isNotEmpty);
    vm.dispose();
  });

  test('melayani seluruh pesanan memberi koin & pelanggan pergi/duduk', () async {
    final repo = FakeGameRepository(GameSnapshot(display: {'doughnut': 5, 'croissant': 5, 'cheesecake': 5}));
    final vm = makeVm(repo);
    await vm.init();
    runUntil(vm, () => hasWaiting(vm));
    final c = vm.customers.firstWhere((e) => e.state == CustState.waiting);
    final before = vm.money;
    for (final item in List.of(c.items)) {
      if (item.product.isFood) {
        expect(vm.serveFood(item.product), isTrue);
      } else {
        expect(vm.startCraft(item.product), isNull);
        vm.finishCraft(item.product, 0.9);
      }
    }
    expect(c.allDone, isTrue);
    expect(vm.money, greaterThan(before));
    expect(vm.served, 1);
    expect(c.state == CustState.toTable || c.state == CustState.leaving, isTrue);
    vm.dispose();
  });

  test('meracik memakai bahan; hasil gagal masuk tempat sampah', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    final events = <GameEvent>[];
    vm.events.listen(events.add);
    await vm.init();
    final beans = vm.beans;
    expect(vm.startCraft(Product.espresso), isNull);
    expect(vm.beans, beans - 1);
    vm.finishCraft(Product.espresso, 0.1);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<Trashed>(), isNotEmpty);
    expect(vm.flyers.any((f) => f.trash), isTrue);
    vm.dispose();
  });

  test('bahan habis menolak meracik', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot(beans: 0)));
    await vm.init();
    expect(vm.startCraft(Product.espresso), isNotNull);
    vm.dispose();
  });

  test('oven: panggang, matang, angkat masuk etalase', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    final flour = vm.flour;
    expect(vm.startBake(0, Product.doughnut), isNull);
    expect(vm.flour, flour - 1);
    runUntil(vm, () => vm.ovens.first.state == OvenState.ready);
    expect(vm.ovens.first.state, OvenState.ready);

    final message = vm.collectOven(0);
    expect(message, isNotNull);
    expect(message, contains('etalase'));
    
    expect(vm.stockOf(Product.doughnut), 3);
    vm.dispose();
  });

  test('oven bisa memanggang beberapa loyang sekaligus', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot(flour: 5)));
    await vm.init();
    expect(vm.ovens.length, greaterThanOrEqualTo(2));
    expect(vm.startBake(0, Product.doughnut, trays: 2), isNull);
    expect(vm.flour, 3);
    runUntil(vm, () => vm.ovens.first.state == OvenState.ready);
    vm.collectOven(0);
    expect(vm.stockOf(Product.doughnut), 6); // 2 loyang x 3 roti
    vm.dispose();
  });

  test('adonan gagal membuang tepung & tidak memulai oven', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    final flour = vm.flour;
    expect(vm.startBake(0, Product.doughnut, doughQuality: 0.1), isNotNull);
    expect(vm.flour, flour - 1);
    expect(vm.ovens.first.state, OvenState.idle);
    vm.dispose();
  });

  test('petunjuk langkah berikutnya selalu ada & barista bisa diganti', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    expect(vm.coachHint, isNotNull);
    expect(vm.baristaFemale, isFalse);
    await vm.toggleBarista();
    expect(vm.baristaFemale, isTrue);
    vm.dispose();
  });

  test('target hari & bintang dihitung dari pendapatan', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    expect(vm.dayTarget, greaterThan(0));
    expect(vm.dayStars, 0);
    vm.dispose();
  });

  test('roti dibiarkan terlalu lama menjadi gosong', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    vm.startBake(0, Product.doughnut);
    runUntil(vm, () => vm.ovens.first.state == OvenState.burnt);
    expect(vm.ovens.first.state, OvenState.burnt);
    vm.dispose();
  });

  test('pelanggan yang kehabisan sabar pergi dengan marah', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    await vm.init();
    runUntil(vm, () => vm.customers.any((c) => c.angry), max: 6000);
    expect(vm.customers.any((c) => c.angry), isTrue);
    vm.dispose();
  });

  test('toko: upgrade, dekor, stok', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot(money: 1500)));
    await vm.init();
    final start = vm.money; // sudah termasuk hadiah login harian
    final cost = UpgradeType.machine.costForLevel(0);
    expect(vm.buyUpgrade(UpgradeType.machine), isTrue);
    expect(vm.money, start - cost);
    expect(vm.upgradeLevel(UpgradeType.machine), 1);
    expect(vm.buyDecor(Decor.plantSmall), isTrue);
    expect(vm.hasDecor(Decor.plantSmall), isTrue);
    expect(vm.aesthetic, Decor.plantSmall.aesthetic);
    expect(vm.buyDecor(Decor.table4), isFalse); // meja ke-3 dulu & butuh level
    final beans = vm.beans;
    expect(vm.buyStock(StockItem.beans), isTrue);
    expect(vm.beans, beans + StockItem.beans.packSize);
    final poor = makeVm(FakeGameRepository(GameSnapshot(money: 1)));
    await poor.init();
    expect(poor.buyUpgrade(UpgradeType.machine), isFalse);
    vm.dispose();
    poor.dispose();
  });

  test('pendapatan pasif dari background task diambil saat init', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot(money: 100), pendingIdle: 250));
    await vm.init();
    expect(vm.takeOfflineEarnings(), 250);
    expect(vm.money, greaterThanOrEqualTo(350)); // + hadiah login harian
    vm.dispose();
  });

  test('hari berakhir memunculkan ringkasan lalu bisa lanjut hari berikutnya', () async {
    final vm = makeVm(FakeGameRepository(GameSnapshot()));
    final events = <GameEvent>[];
    vm.events.listen(events.add);
    await vm.init();
    runUntil(vm, () => vm.phase == DayPhase.summary, max: 20000);
    expect(vm.phase, DayPhase.summary);
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<DayEnded>(), isNotEmpty);
    vm.startNextDay();
    expect(vm.day, 2);
    expect(vm.phase, DayPhase.open);
    vm.dispose();
  });
}
