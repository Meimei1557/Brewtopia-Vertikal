import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app/di.dart';
import '../app/router.dart';
import '../core/audio_service.dart';
import '../core/background_service.dart';
import '../core/voice_service.dart';
import '../data/models/customer.dart';
import '../data/models/game_event.dart';
import '../data/models/product.dart';
import '../viewmodels/gameplay_view_model.dart';
import 'widgets/cafe_scene.dart';
import 'widgets/craft_sheet.dart';
import 'widgets/oven_sheet.dart';
import 'widgets/product_icon.dart';
import 'widgets/shop_sheet.dart';

const _sheetColor = Color(0xFF34231A);

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameplayViewModel _vm;
  final AudioService _audio = getIt<AudioService>();
  final VoiceService _voice = getIt<VoiceService>();
  StreamSubscription<GameEvent>? _sub;
  Timer? _popTimer;
  bool _crafting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vm = context.read<GameplayViewModel>();
    _sub = _vm.events.listen(_onEvent);
    _audio.startMusic();
    _vm.init().then((_) {
      if (!mounted) return;
      final earned = _vm.takeOfflineEarnings();
      if (earned > 0) _showOffline(earned);
    });
  }

  /// Musik/suara dihentikan oleh pengawas lifecycle di level app; di sini hanya jeda simulasi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _vm.resume();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _vm.pause();
      BackgroundService.scheduleCloudSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _popTimer?.cancel();
    _voice.stop();
    super.dispose();
  }

  void _later(int ms, VoidCallback fn) => Future.delayed(Duration(milliseconds: ms), () {
        if (mounted) fn();
      });

  void _onEvent(GameEvent e) {
    switch (e) {
      case DoorOpened():
        _audio.play(Sfx.doorOpen, gain: 0.85);
      case OrderTaken():
        _audio.play(Sfx.ding, gain: 0.8);
      case ItemDelivered():
        // bunyi 'pop' hanya bila pesanan belum lengkap (bila lengkap, bunyi koin yang dipakai)
        _popTimer?.cancel();
        _popTimer = Timer(const Duration(milliseconds: 140), () => _audio.play(Sfx.pop));
      case OrderServed(:final combo, :final quality):
        _popTimer?.cancel();
        if (combo >= 3) {
          _audio.play(Sfx.combo);
          _toast('🔥 Combo x$combo!');
        } else if (quality >= 0.85) {
          _audio.play(Sfx.perfect);
        } else {
          _audio.play(Sfx.coin);
        }
      case Trashed(:final reason):
        _audio.play(Sfx.trash);
        _toast('🗑️ Dibuang ke tempat sampah ($reason)');
      case CustomerAngry():
        _audio.play(Sfx.error, gain: 0.7);
      case HangoutDone():
        _audio.play(Sfx.coin, gain: 0.5);
      case OvenReady():
        _audio.play(Sfx.ovenDing);
        _toast('🔥 Roti matang! Ketuk oven untuk mengangkat.');
      case OvenBurnt():
        _audio.play(Sfx.error);
        _toast('💨 Roti gosong!');
      case BakeStarted():
        _audio.play(Sfx.pop);
      case BakeCollected(:final perfect):
        _audio.play(perfect ? Sfx.perfect : Sfx.pop, gain: 0.8);
      case LevelUp(:final level, :final bonus, :final unlocked):
        _audio.play(Sfx.levelup);
        _toast('⭐ LEVEL $level! +$bonus koin${unlocked.isEmpty ? '' : '\n$unlocked'}', ms: 3200);
      case UpgradeBought():
        _audio.play(Sfx.levelup, gain: 0.6);
      case Purchased(:final what):
        _audio.play(Sfx.coin);
        _toast('Dibeli: $what');
      case NotEnoughCoins():
        _audio.play(Sfx.error);
        _toast('Koin tidak cukup');
      case ToastEvent(:final text):
        _toast(text, ms: 2600);
      case EventBanner():
        _audio.play(Sfx.event);
      case MissionDone(:final label):
        _audio.play(Sfx.perfect);
        _toast('🎯 Misi selesai: $label');
      case DayEnded(:final summary):
        _audio.play(Sfx.dayEnd);
        _later(600, () => _showSummary(summary));
      case DailyReward(:final coins, :final streak):
        _showDaily(coins, streak);
      case Speak(:final text, :final gender, :final priority):
        _voice.speak(text, gender, priority: priority);
    }
  }

  void _toast(String msg, {int ms = 1700}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      duration: Duration(milliseconds: ms),
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 250, left: 28, right: 28),
    ));
  }

  void _showOffline(int earned) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selamat datang kembali!'),
        content: Text('Kafemu tetap berjalan saat kamu pergi dan menghasilkan $earned koin.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ambil'))],
      ),
    );
  }

  void _showDaily(int coins, int streak) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎁 Hadiah login harian'),
        content: Text('Hari ke-$streak berturut-turut!\nKamu mendapat $coins koin.\n(Makin lama streak, makin besar hadiah sampai 7 hari.)'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Mantap!'))],
      ),
    );
  }

  void _showSummary(DaySummary s) {
    if (!mounted) return;
    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Expanded(child: Text(l)), Text(v, style: const TextStyle(fontWeight: FontWeight.w800))]),
        );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('🌙 Hari ke-${s.day} selesai'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${'⭐' * s.stars}${'☆' * (3 - s.stars)}', style: const TextStyle(fontSize: 30)),
            Text(s.stars == 0 ? 'Target belum tercapai (${s.earned}/${s.target})' : 'Target ${s.target} tercapai! Bonus +${s.bonus} koin',
                style: TextStyle(color: s.stars == 0 ? Colors.orangeAccent : const Color(0xFFFFD54F), fontWeight: FontWeight.w700)),
            if (s.bestDay) const Text('🏆 Rekor pendapatan harian!', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            row('Pendapatan', '🪙 ${s.earned}'),
            row('Pelanggan dilayani', '${s.customers}'),
            row('Pesanan sempurna', '⭐ ${s.perfect}'),
            row('Nongkrong di meja', '🪑 ${s.hangout}'),
            row('Pelanggan kecewa', '😠 ${s.angry}'),
            row('Terbuang ke sampah', '🗑️ ${s.trashed}'),
            row('Reputasi', '⭐ ${s.reputation.toStringAsFixed(1)}'),
            const SizedBox(height: 6),
            const Text('Tips: 1 bintang = capai target, 2 bintang = 1.5x, 3 bintang = 2x target.', style: TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Ke lobby'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _vm.startNextDay();
            },
            child: const Text('Hari berikutnya ▶'),
          ),
        ],
      ),
    );
  }

  void _openSheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => ChangeNotifierProvider<GameplayViewModel>.value(value: _vm, child: child),
    );
  }

  void _openShop([int tab = 0]) => _openSheet(ShopSheet(initialTab: tab));
  void _openOven() => _openSheet(const OvenSheet());

  Future<void> _craft(Product p) async {
    if (_crafting) return;
    _audio.play(Sfx.tap);
    final err = _vm.startCraft(p);
    if (err != null) {
      _audio.play(Sfx.error);
      _toast(err);
      return;
    }
    _crafting = true;
    final q = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _sheetColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => CraftSheet(product: p, machineLevel: _vm.machineBonus),
    );
    _crafting = false;
    _vm.finishCraft(p, q ?? 0); // dibatalkan = bahan terbuang
  }

  void _onProduct(Product p) {
    if (p.unlockLevel > _vm.level) {
      _toast('${p.label} terbuka di level ${p.unlockLevel}');
      return;
    }
    if (p.isFood) {
      _audio.play(Sfx.tap);
      _vm.serveFood(p);
    } else {
      _craft(p);
    }
  }

  /// Ketuk item di tiket pesanan: roti disajikan langsung ke pelanggan itu, kopi mulai diracik.
  void _onTicketItem(Customer c, OrderItem it) {
    if (it.done || c.state != CustState.waiting) return;
    _vm.focusCustomer(c.id);
    if (it.product.isFood) {
      _audio.play(Sfx.tap);
      _vm.serveFood(it.product, customerId: c.id);
    } else {
      _craft(it.product);
    }
  }

  void _jukebox() {
    _audio.nextTrack();
    _audio.play(Sfx.pop);
    _toast('🎵 Lagu: ${AudioService.trackNames[(_audio.track + 1) % AudioService.tracks.length]}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: CafeScene(vm: _vm, onOvenTap: _openOven, onJukeboxTap: _jukebox)),
        SafeArea(
          child: Consumer<GameplayViewModel>(
            builder: (context, vm, _) => Column(children: [
              _TopBar(vm: vm, onShop: _openShop, onOven: _openOven),
              _OrdersStrip(vm: vm, onItem: _onTicketItem),
              const Spacer(),
              _CoachBar(vm: vm),
              _BottomBar(vm: vm, onProduct: _onProduct, onShop: _openShop, onOven: _openOven),
            ]),
          ),
        ),
        Consumer<GameplayViewModel>(
          builder: (context, vm, _) => vm.bannerText == null
              ? const SizedBox.shrink()
              : Positioned(
                  top: MediaQuery.of(context).padding.top + 130,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFD54F)),
                      ),
                      child: Text(vm.bannerText!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFFFFD54F))),
                    ),
                  ),
                ),
        ),
        Consumer<GameplayViewModel>(
          builder: (context, vm, _) => (!vm.tutorialSeen && vm.isReady) ? _Tutorial(vm: vm) : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

// =====================================================================================
class _Chip extends StatelessWidget {
  const _Chip({required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: (color ?? Colors.black).withValues(alpha: 0.62), borderRadius: BorderRadius.circular(13)),
        child: child,
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.vm, required this.onShop, required this.onOven});
  final GameplayViewModel vm;
  final void Function([int]) onShop;
  final VoidCallback onOven;

  @override
  Widget build(BuildContext context) {
    final xp = vm.xpTarget == 0 ? 0.0 : (vm.xp / vm.xpTarget).clamp(0.0, 1.0).toDouble();
    const w = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white);
    final target = vm.dayTarget;
    final tProg = (vm.dayEarned / target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
      child: Column(children: [
        Row(children: [
          _Chip(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text('LV ${vm.level}', style: w)),
              const SizedBox(height: 2),
              SizedBox(
                width: 38,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: xp, minHeight: 4, color: const Color(0xFF81C784), backgroundColor: Colors.white24),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 4),
          _Chip(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.monetization_on, color: Color(0xFFFFD54F), size: 14),
            const SizedBox(width: 2),
            Text('${vm.money}', style: w),
          ])),
          const SizedBox(width: 4),
          Expanded(
            child: _Chip(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: vm.frame,
                  builder: (_, __) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(vm.phase == DayPhase.open ? 'Hari ${vm.day} • ${vm.dayLeft.ceil()}s' : 'Hari ${vm.day} • TUTUP', style: w),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedBuilder(
                  animation: vm.frame,
                  builder: (_, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: vm.dayFraction, minHeight: 4, color: const Color(0xFFFFB300), backgroundColor: Colors.white24),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 4),
          _Chip(child: Text('⭐${vm.reputation.toStringAsFixed(1)}', style: w)),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF4A3426),
            onSelected: (v) {
              switch (v) {
                case 'shop':
                  onShop(0);
                case 'mission':
                  onShop(3);
                case 'oven':
                  onOven();
                case 'barista':
                  vm.toggleBarista();
                case 'rank':
                  context.push(Routes.leaderboard);
                case 'settings':
                  context.push(Routes.settings);
                case 'lobby':
                  context.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'shop', child: _MenuRow(Icons.storefront, 'Toko & Dekor')),
              const PopupMenuItem(value: 'mission', child: _MenuRow(Icons.flag, 'Misi Harian')),
              const PopupMenuItem(value: 'oven', child: _MenuRow(Icons.local_fire_department, 'Oven & Etalase')),
              PopupMenuItem(value: 'barista', child: _MenuRow(Icons.swap_horiz, vm.baristaFemale ? 'Ganti ke barista pria' : 'Ganti ke barista wanita')),
              const PopupMenuItem(value: 'rank', child: _MenuRow(Icons.emoji_events, 'Peringkat')),
              const PopupMenuItem(value: 'settings', child: _MenuRow(Icons.settings, 'Pengaturan')),
              const PopupMenuItem(value: 'lobby', child: _MenuRow(Icons.home, 'Ke Lobby')),
            ],
          ),
        ]),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(
              child: _Chip(
                child: Row(children: [
                  Text(vm.dayStars >= 3 ? '⭐⭐⭐' : (vm.dayStars == 2 ? '⭐⭐' : (vm.dayStars == 1 ? '⭐' : '🎯')), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: tProg, minHeight: 6, color: Colors.lightGreenAccent, backgroundColor: Colors.white24),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text('${vm.dayEarned}/$target', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 4, runSpacing: 3, children: [
            if (vm.fever) const _Chip(color: Colors.redAccent, child: Text('🔥 FEVER x1.5', style: w)),
            if (vm.combo >= 2) _Chip(color: Colors.deepOrange, child: Text('Combo x${vm.combo}', style: w)),
            if (vm.bonusActive) const _Chip(color: Color(0xFFF9A825), child: Text('⚡ x1.5', style: w)),
            if (vm.raining) const _Chip(color: Color(0xFF455A64), child: Text('🌧️ Hujan', style: w)),
            _Chip(child: Text('✨ ${vm.aesthetic}', style: w)),
          ]),
        ),
      ]),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]);
}

/// Tiket pesanan bergambar & bernama. Ketuk item untuk langsung mengerjakannya.
class _OrdersStrip extends StatelessWidget {
  const _OrdersStrip({required this.vm, required this.onItem});
  final GameplayViewModel vm;
  final void Function(Customer, OrderItem) onItem;

  @override
  Widget build(BuildContext context) {
    final orders = vm.orders;
    if (orders.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 84,
      child: AnimatedBuilder(
        animation: vm.frame,
        builder: (_, __) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          scrollDirection: Axis.horizontal,
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final c = orders[i];
            final sel = vm.selectedId == c.id;
            return GestureDetector(
              onTap: () => vm.selectCustomer(c.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.66),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? const Color(0xFFFFB300) : Colors.white24, width: sel ? 2 : 1),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${c.gender == Gender.male ? '🧑' : '👩'} ${c.name}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final it in c.items)
                      GestureDetector(
                        onTap: () => onItem(c, it),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Stack(alignment: Alignment.center, children: [
                              ProductIcon(it.product, size: 26, dim: it.done),
                              if (it.done) const Icon(Icons.check_circle, color: Colors.lightGreenAccent, size: 18),
                            ]),
                            Text(it.product.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: it.done ? Colors.white38 : Colors.white)),
                          ]),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 56,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: c.patienceFraction,
                        minHeight: 4,
                        color: Color.lerp(Colors.redAccent, Colors.lightGreenAccent, c.patienceFraction),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Petunjuk langkah berikutnya.
class _CoachBar extends StatelessWidget {
  const _CoachBar({required this.vm});
  final GameplayViewModel vm;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: vm.frame,
        builder: (_, __) {
          final h = vm.coachHint;
          if (h == null) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text(h, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w700, color: Colors.brown.shade900)),
          );
        },
      );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.vm, required this.onProduct, required this.onShop, required this.onOven});
  final GameplayViewModel vm;
  final void Function(Product) onProduct;
  final void Function([int]) onShop;
  final VoidCallback onOven;

  @override
  Widget build(BuildContext context) {
    final wanted = <Product>{
      for (final c in vm.orders)
        for (final i in c.items)
          if (!i.done) i.product,
    };
    final readyOven = vm.ovens.where((o) => o.state == OvenState.ready).length;
    Widget res(IconData icon, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: n <= 2 ? Colors.redAccent : Colors.white70),
          const SizedBox(width: 2),
          Text('$n', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: n <= 2 ? Colors.redAccent : Colors.white)),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.76),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 4,
          children: [
            GestureDetector(
              onTap: () => onShop(0),
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF8B6239), borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.storefront, size: 15, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Toko', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ]),
                ),
                if (vm.missionClaimable)
                  Positioned(right: -2, top: -3, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))),
              ]),
            ),
            res(Icons.grain, vm.beans),
            res(Icons.water_drop, vm.milk),
            res(Icons.bakery_dining, vm.flour),
            Text('🥐 ${vm.displayCount}/${vm.displayCapacity}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: onOven,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: readyOven > 0 ? Colors.green.shade700 : const Color(0xFF6D4C41), borderRadius: BorderRadius.circular(12)),
                child: Text(readyOven > 0 ? '🔥 SIAP!' : '🔥 Oven', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Product.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final p = Product.values[i];
              final locked = p.unlockLevel > vm.level;
              final out = !p.isFood && (vm.beans < 1 || vm.milk < p.milkNeed);
              final noStock = p.isFood && vm.stockOf(p) == 0;
              final want = wanted.contains(p);
              final dim = locked || out;
              final sub = locked ? 'Lv ${p.unlockLevel}' : (out ? 'habis' : (p.isFood ? (noStock ? 'kosong' : 'stok ${vm.stockOf(p)}') : '🪙${p.price}'));
              return GestureDetector(
                onTap: () => onProduct(p),
                child: Container(
                  width: 76,
                  padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dim ? [Colors.grey.shade800, Colors.grey.shade900] : [const Color(0xFF6D4C41), const Color(0xFF4E342E)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: want && !dim ? const Color(0xFFFFB300) : Colors.white24, width: want && !dim ? 2.2 : 1),
                    boxShadow: want && !dim ? [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.35), blurRadius: 8)] : null,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    locked ? const SizedBox(height: 34, child: Center(child: Text('🔒', style: TextStyle(fontSize: 22)))) : ProductIcon(p, size: 34, dim: out),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(p.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dim ? Colors.white38 : Colors.white))),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: dim || noStock ? Colors.white38 : const Color(0xFFFFD54F)))),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Tutorial extends StatelessWidget {
  const _Tutorial({required this.vm});
  final GameplayViewModel vm;

  Widget _step(String icon, String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child: Text(icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              Text(text, style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.25)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(maxHeight: 560),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2A1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('☕ Cara bermain', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: [
                      _step('🚪', '1. Pelanggan datang', 'Mereka masuk lewat pintu & menyebut pesanan. Pesanannya tertulis di balon & tiket (gambar + nama).'),
                      _step('☕', '2. Racik kopi', 'Ketuk kopi yang dipesan di bar bawah. Giling dengan ketuk cepat, lalu TAHAN & LEPAS di zona hijau.'),
                      _step('🥐', '3. Panggang roti', 'Buka 🔥 Oven → pilih roti & jumlah loyang → mini-game adonan. ANGKAT saat matang, jangan sampai gosong!'),
                      _step('👉', '4. Sajikan', 'Ketuk roti di bar bawah (atau ketuk gambar roti di tiket) untuk memberikannya ke pelanggan.'),
                      _step('🗑️', '5. Salah? Dibuang', 'Pesanan yang gagal / tidak dipesan otomatis masuk tempat sampah.'),
                      _step('🎯', '6. Capai target hari', 'Kumpulkan koin sampai target (bar hijau). 1-3 bintang = bonus. Kotak kuning di atas bar bawah selalu memberi petunjuk.'),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: vm.markTutorialSeen, child: const Text('Mulai bermain!'))),
              ]),
            ),
          ),
        ),
      );
}
