import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../core/dialog_lines.dart';
import '../data/models/customer.dart';
import '../data/models/decor.dart';
import '../data/models/game_event.dart';
import '../data/models/game_snapshot.dart';
import '../data/models/mission.dart';
import '../data/models/product.dart';
import '../data/models/upgrade.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';

/// Notifikasi per-frame untuk animasi (tidak memicu rebuild HUD).
class FrameClock extends ChangeNotifier {
  void tick() => notifyListeners();
}

class FloatingText {
  FloatingText(this.text, this.x, this.y, this.color);
  final String text;
  final double x;
  double y;
  final Color color;
  double age = 0;
  static const double life = 1.6;
  double get t => (age / life).clamp(0.0, 1.0).toDouble();
}

/// Benda yang melayang (pesanan ke pelanggan atau ke tong sampah).
class Flyer {
  Flyer(this.emoji, this.from, this.to, {this.trash = false, this.product});
  final Product? product;
  final String emoji;
  final Offset from;
  final Offset to;
  final bool trash;
  double t = 0;
}

enum DayPhase { open, closing, summary }

enum OvenState { idle, baking, ready, burnt }

enum BaristaFocus { idle, machine, oven }

class OvenSlot {
  Product? item;
  OvenState state = OvenState.idle;
  int trays = 1; // jumlah loyang (1 loyang = 3 roti)
  double doughQ = 0.8; // kualitas adonan dari mini-game
  double t = 0;
  double readyT = 0;
  double get total => item == null ? 0 : item!.bakeSeconds + (trays - 1) * 2.5;
  double get progress => item == null ? 0 : (t / total).clamp(0.0, 1.0).toDouble();
}

/// ViewModel inti gameplay (simulasi kafe). Tidak mengenal widget/audio:
/// View men-subscribe `events` dan membaca state lewat Provider.
class GameplayViewModel extends ChangeNotifier {
  GameplayViewModel(this._repo, this._cloud, this._auth, {Random? random})
      : _rng = random ?? Random();

  final GameRepository _repo;
  final CloudRepository _cloud;
  final AuthRepository _auth;
  final Random _rng;

  // ---------- konstanta dunia (koordinat scene 600 x 1300) ----------
  static const double dayLength = 150;
  static const double doorX = 510, doorY = 584;
  static const List<Offset> queueSlots = [
    Offset(350, 700), Offset(250, 748), Offset(150, 796), Offset(440, 748),
  ];
  static const List<Offset> tableSpots = [
    Offset(105, 950), Offset(495, 950), Offset(300, 950),
    Offset(105, 1090), Offset(495, 1090), Offset(300, 1090),
  ];
  static const Offset binPos = Offset(45, 700);
  static const Offset machinePos = Offset(366, 400);
  static const Offset displayPos = Offset(200, 410);
  static const Offset ovenPos = Offset(72, 390);
  static const double walkSpeed = 175;
  static int xpNeeded(int level) => 50 + 40 * level;

  // ---------- state ----------
  GameSnapshot _s = GameSnapshot();
  bool _ready = false;
  bool _paused = false;
  bool _disposed = false;
  DayPhase _phase = DayPhase.open;
  double _dayLeft = dayLength;
  double _closingT = 0;
  DayEvent _event = DayEvent.none;
  bool _eventFired = false;
  double _rushLeft = 0;
  int _combo = 0;
  int _nextId = 1;
  int _offlineEarnings = 0;
  double _spawnTimer = 1.5;
  double _feverLeft = 0;
  int? _selectedId;
  double _doorTimer = 0;
  double _binShake = 0;
  BaristaFocus _focus = BaristaFocus.idle;
  double _focusTimer = 0;
  String? _baristaBubble;
  double _baristaBubbleTime = 0;
  String? _bannerText;
  double _bannerTime = 0;
  int _dayEarned = 0, _dayServed = 0, _dayAngry = 0, _dayPerfect = 0, _dayHangout = 0, _dayTrashed = 0;
  final List<MissionState> _missions = [];
  final List<OvenSlot> _ovens = [];
  final Map<Product, double> _dq = {}; // kualitas rata-rata roti di etalase

  final List<Customer> _customers = [];
  final List<FloatingText> _floaters = [];
  final List<Flyer> _flyers = [];
  final FrameClock frame = FrameClock();
  final StreamController<GameEvent> _events = StreamController.broadcast();

  Timer? _saveDebounce;
  Timer? _cloudTimer;

  // ---------- getter ----------
  bool get isReady => _ready;
  GameSnapshot get snapshot => _s;
  int get money => _s.money;
  int get level => _s.level;
  int get xp => _s.xp;
  int get xpTarget => xpNeeded(_s.level);
  int get combo => _combo;
  int get served => _s.served;
  int get day => _s.day;
  double get reputation => _s.reputation;
  bool get bonusActive => _s.bonusActive;
  bool get tutorialSeen => _s.tutorialSeen;
  DayPhase get phase => _phase;
  double get dayLeft => _dayLeft;
  double get dayFraction => (1 - _dayLeft / dayLength).clamp(0.0, 1.0).toDouble();
  DayEvent get event => _event;
  bool get raining => _event == DayEvent.rain;
  bool get fever => _feverLeft > 0;
  int get dayEarned => _dayEarned;
  int get dayTarget => 100 + _s.day * 45;
  int get dayStars => _dayEarned >= dayTarget * 2 ? 3 : (_dayEarned >= dayTarget * 1.5 ? 2 : (_dayEarned >= dayTarget ? 1 : 0));
  int get beans => _s.beans;
  int get milk => _s.milk;
  int get flour => _s.flour;
  List<Customer> get customers => List.unmodifiable(_customers);
  List<Customer> get orders =>
      _customers.where((c) => c.state == CustState.ordering || c.state == CustState.waiting).toList();
  List<FloatingText> get floaters => List.unmodifiable(_floaters);
  List<Flyer> get flyers => List.unmodifiable(_flyers);
  List<OvenSlot> get ovens => List.unmodifiable(_ovens);
  List<MissionState> get missions => List.unmodifiable(_missions);
  Stream<GameEvent> get events => _events.stream;
  int? get selectedId => _selectedId;
  double get doorOpen {
    if (_doorTimer <= 0) return 0;
    final elapsed = 1.5 - _doorTimer;
    return min((elapsed / 0.25).clamp(0.0, 1.0), (_doorTimer / 0.4).clamp(0.0, 1.0)).toDouble();
  }
  double get binShake => _binShake;
  BaristaFocus get baristaFocus => _focus;
  String? get baristaBubble => _baristaBubbleTime > 0 ? _baristaBubble : null;
  bool get baristaFemale => _repo.baristaFemale;

  Future<void> toggleBarista() async {
    await _repo.setBaristaFemale(!_repo.baristaFemale);
    _baristaSay(_repo.baristaFemale ? 'Halo, aku Sari, barista barumu!' : 'Halo, aku Bima, barista barumu!');
    notifyListeners();
  }
  String? get bannerText => _bannerTime > 0 ? _bannerText : null;
  bool get missionClaimable => _missions.any((m) => m.done && !m.claimed);

  List<Product> get availableProducts => ProductX.availableAt(_s.level);
  int upgradeLevel(UpgradeType t) => _s.upgradeLevel(t);
  bool hasDecor(Decor d) => _s.hasDecor(d.name);
  int get aesthetic {
    var a = 0;
    for (final d in Decor.values) {
      if (_s.hasDecor(d.name)) a += d.aesthetic;
    }
    return a;
  }

  int get tableCount {
    var n = 2;
    for (final d in [Decor.table3, Decor.table4, Decor.table5, Decor.table6]) {
      if (_s.hasDecor(d.name)) n++;
    }
    return n;
  }

  int get clothStyle => _s.hasDecor(Decor.cloth2.name) ? 2 : (_s.hasDecor(Decor.cloth1.name) ? 1 : 0);
  int get queueSlotCount => _s.level >= 6 ? 4 : 3;
  int stockOf(Product p) => _s.display[p.name] ?? 0;
  int get displayCount => _s.display.values.fold(0, (a, b) => a + b);
  int get displayCapacity => 6 + 3 * _s.upgradeLevel(UpgradeType.display);
  double get machineBonus => _s.upgradeLevel(UpgradeType.machine).toDouble();
  Customer? customerById(int id) {
    for (final c in _customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Petunjuk langkah berikutnya supaya pemain tidak bingung.
  String? get coachHint {
    if (!_ready || _phase == DayPhase.summary) return null;
    if (_phase == DayPhase.closing) return 'Kafe tutup. Selesaikan pesanan yang tersisa!';
    if (_ovens.any((o) => o.state == OvenState.ready)) {
      return '🔥 Roti matang! Ketuk oven (atau tombol 🔥 SIAP!) untuk mengangkat sebelum gosong.';
    }
    final list = orders;
    if (list.isEmpty) {
      if (_customers.any((c) => c.state == CustState.arriving)) return 'Pelanggan datang... siapkan diri!';
      if (displayCount < 3 && _s.flour > 0 && _ovens.any((o) => o.state == OvenState.idle)) {
        return '💡 Sambil menunggu: buka 🔥 Oven dan panggang roti supaya etalase terisi.';
      }
      return 'Menunggu pelanggan berikutnya...';
    }
    Customer? c;
    for (final x in list) {
      if (x.id == _selectedId) c = x;
    }
    c ??= list.firstWhere((x) => x.state == CustState.waiting, orElse: () => list.first);
    if (c.state == CustState.ordering) return '${c.name} sedang memesan...';
    final open = c.items.where((i) => !i.done).toList();
    if (open.isEmpty) return null;
    final p = open.first.product;
    if (p.isFood) {
      if (stockOf(p) > 0) return '👉 ${c.name} pesan ${p.label}. Ketuk ${p.label} di bar bawah untuk menyajikan.';
      if (_ovens.any((o) => o.item == p && o.state == OvenState.baking)) return '${p.label} sedang dipanggang, tunggu sebentar...';
      return '👉 ${c.name} pesan ${p.label}, stok kosong. Buka 🔥 Oven, pilih ${p.label}, lalu panggang!';
    }
    return '👉 ${c.name} pesan ${p.label}. Ketuk ${p.label} di bar bawah, lalu ikuti langkah meraciknya.';
  }

  int takeOfflineEarnings() {
    final v = _offlineEarnings;
    _offlineEarnings = 0;
    return v;
  }

  // ---------- lifecycle ----------
  Future<void> init() async {
    _s = await _repo.load();
    final idle = await _repo.takePendingIdleIncome(); // dihasilkan background task
    if (idle > 0) {
      _s.money += idle;
      _s.totalEarned += idle;
      _offlineEarnings = idle;
    }
    _initOvens();
    _ensureMissions();
    final reward = _dailyLogin();
    _pickEvent();
    _ready = true;
    await _repo.save(_s);
    _cloudTimer = Timer.periodic(const Duration(seconds: 45), (_) => _syncCloud());
    notifyListeners();
    if (reward != null) _emit(DailyReward(reward.$1, reward.$2));
    if (_event == DayEvent.rain) _banner(Lines.eventLine(DayEvent.rain));
  }

  void pause() {
    _paused = true;
    _flushSave();
    _syncCloud();
  }

  void resume() => _paused = false;

  void markTutorialSeen() {
    if (_s.tutorialSeen) return;
    _s.tutorialSeen = true;
    _scheduleSave();
    notifyListeners();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (int, int)? _dailyLogin() {
    final today = _dayKey(DateTime.now());
    if (_s.lastLoginDay == today) return null;
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    _s.streak = _s.lastLoginDay == yesterday ? _s.streak + 1 : 1;
    final int coins = 40 * (_s.streak > 7 ? 7 : _s.streak);
    _s.money += coins;
    _s.totalEarned += coins;
    _s.lastLoginDay = today;
    return (coins, _s.streak);
  }

  void _initOvens() {
    _ovens.clear();
    for (var i = 0; i < 2 + _s.upgradeLevel(UpgradeType.oven); i++) {
      _ovens.add(OvenSlot());
    }
  }

  void _ensureMissions() {
    final today = _dayKey(DateTime.now());
    final tier = _s.level < 3 ? 0 : (_s.level < 6 ? 1 : 2);
    var useTier = tier;
    if (_s.missionDay == null || !_s.missionDay!.startsWith(today)) {
      _s.missionDay = '$today|$tier';
      _s.missionProgress = [0, 0, 0];
      _s.missionClaimed = [false, false, false];
    } else {
      useTier = int.tryParse(_s.missionDay!.split('|').last) ?? tier;
    }
    final defs = generateMissions(today, useTier);
    _missions
      ..clear()
      ..addAll([
        for (var i = 0; i < defs.length; i++)
          MissionState(defs[i], _s.missionProgress[i], _s.missionClaimed[i]),
      ]);
  }

  void _track(MissionKind kind, int n, {bool setMax = false}) {
    for (var i = 0; i < _missions.length; i++) {
      final m = _missions[i];
      if (m.def.kind != kind || m.claimed) continue;
      final before = m.done;
      m.progress = setMax ? max(m.progress, n) : min(m.def.target, m.progress + n);
      if (m.progress > m.def.target) m.progress = m.def.target;
      _s.missionProgress[i] = m.progress;
      if (!before && m.done) _emit(MissionDone(m.def.label));
    }
  }

  bool claimMission(int i) {
    if (i < 0 || i >= _missions.length) return false;
    final m = _missions[i];
    if (!m.done || m.claimed) return false;
    m.claimed = true;
    _s.missionClaimed[i] = true;
    _s.money += m.def.reward;
    _s.totalEarned += m.def.reward;
    _emit(ToastEvent('Misi selesai! +${m.def.reward} koin'));
    _scheduleSave();
    notifyListeners();
    return true;
  }

  // ---------- hari & event ----------
  void _pickEvent() {
    _eventFired = false;
    _vipDone = false;
    _criticDone = false;
    _rushLeft = 0;
    _event = DayEvent.none;
    if (_s.day < 2) return;
    final r = _rng.nextDouble();
    if (r < 0.35) {
      _event = DayEvent.none;
    } else if (r < 0.55) {
      _event = DayEvent.rush;
    } else if (r < 0.70) {
      _event = DayEvent.vip;
    } else if (r < 0.80 && _s.level >= 3) {
      _event = DayEvent.critic;
    } else {
      _event = DayEvent.rain;
    }
  }

  void _banner(String text) {
    _bannerText = text;
    _bannerTime = 4;
    _emit(EventBanner(text));
    notifyListeners();
  }

  void _fireEventIfDue() {
    if (_eventFired || _event == DayEvent.none || _event == DayEvent.rain) return;
    final due = switch (_event) {
      DayEvent.rush => _dayLeft <= 105,
      DayEvent.vip => _dayLeft <= 100,
      DayEvent.critic => _dayLeft <= 85,
      _ => false,
    };
    if (!due) return;
    _eventFired = true;
    _banner(Lines.eventLine(_event));
    if (_event == DayEvent.rush) _rushLeft = 45;
    if (_event == DayEvent.vip) _spawnTimer = 0;
    if (_event == DayEvent.critic) _spawnTimer = 0;
  }

  void startNextDay() {
    if (_phase != DayPhase.summary) return;
    _s.day++;
    _dayEarned = _dayServed = _dayAngry = _dayPerfect = _dayHangout = _dayTrashed = 0;
    _dayLeft = dayLength;
    _closingT = 0;
    _feverLeft = 0;
    _phase = DayPhase.open;
    _customers.clear();
    _flyers.clear();
    _selectedId = null;
    _spawnTimer = 1.5;
    _pickEvent();
    _ensureMissions();
    _scheduleSave();
    notifyListeners();
    if (_event == DayEvent.rain) _banner(Lines.eventLine(DayEvent.rain));
  }

  void _endDay() {
    _phase = DayPhase.summary;
    final best = _dayEarned > _s.bestDayEarned;
    if (best) _s.bestDayEarned = _dayEarned;
    final stars = dayStars;
    final bonus = stars * 30;
    _s.money += bonus;
    _s.totalEarned += bonus;
    _emit(DayEnded(DaySummary(
      target: dayTarget,
      stars: stars,
      bonus: bonus,
      day: _s.day,
      earned: _dayEarned,
      customers: _dayServed,
      angry: _dayAngry,
      perfect: _dayPerfect,
      hangout: _dayHangout,
      trashed: _dayTrashed,
      reputation: _s.reputation,
      bestDay: best,
    )));
    _flushSave();
    notifyListeners();
  }

  // ---------- game loop ----------
  void tick(double dt) {
    if (!_ready || _paused) return;
    final double step = dt.clamp(0.0, 0.05).toDouble();

    _tickTimers(step);
    if (_phase != DayPhase.summary) {
      if (_phase == DayPhase.open) {
        _dayLeft -= step;
        _fireEventIfDue();
        if (_dayLeft <= 0) {
          _dayLeft = 0;
          _phase = DayPhase.closing;
          _closingT = 0;
          _banner('Kafe tutup! Layani pelanggan terakhir.');
        }
        _updateSpawning(step);
      } else {
        _closingT += step;
        if (_customers.isEmpty || _closingT > 30) _endDay();
      }
      _updateCustomers(step);
      _updateOvens(step);
    }
    frame.tick();
  }

  void _tickTimers(double dt) {
    if (_doorTimer > 0) _doorTimer = max(0, _doorTimer - dt);
    if (_binShake > 0) _binShake = max(0, _binShake - dt);
    if (_rushLeft > 0) _rushLeft = max(0, _rushLeft - dt);
    if (_feverLeft > 0) _feverLeft = max(0, _feverLeft - dt);
    if (_focusTimer > 0) {
      _focusTimer -= dt;
      if (_focusTimer <= 0) _focus = BaristaFocus.idle;
    }
    if (_baristaBubbleTime > 0) _baristaBubbleTime -= dt;
    if (_bannerTime > 0) {
      _bannerTime -= dt;
      if (_bannerTime <= 0) notifyListeners();
    }
    for (final f in _floaters) {
      f.age += dt;
      f.y -= 34 * dt;
    }
    _floaters.removeWhere((f) => f.age >= FloatingText.life);
    for (final f in _flyers) {
      f.t += dt / (f.trash ? 0.75 : 0.55);
    }
    _flyers.removeWhere((f) => f.t >= 1);
  }

  void _updateSpawning(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer > 0) return;
    final slot = _freeSlot();
    if (slot != -1) {
      CustomerTrait? forced;
      if (_event == DayEvent.vip && _eventFired && !_vipDone) {
        forced = CustomerTrait.vip;
        _vipDone = true;
      } else if (_event == DayEvent.critic && _eventFired && !_criticDone) {
        forced = CustomerTrait.critic;
        _criticDone = true;
      }
      _spawnCustomer(slot, forced: forced);
    }
    final boost = (0.8 + _s.reputation * 0.1 + aesthetic * 0.012) *
        (1 + 0.10 * _s.upgradeLevel(UpgradeType.marketing)) *
        (_rushLeft > 0 ? 1.9 : 1.0);
    final base = 8.0 - min(2.5, _s.day * 0.15);
    _spawnTimer = (base / boost) * (0.8 + _rng.nextDouble() * 0.4);
  }

  bool _vipDone = false;
  bool _criticDone = false;

  int _freeSlot() {
    final used = _customers.where((c) => c.inQueue).map((c) => c.slot).toSet();
    for (var i = 0; i < queueSlotCount; i++) {
      if (!used.contains(i)) return i;
    }
    return -1;
  }

  int _freeTable() {
    final used = _customers
        .where((c) => c.tableIndex >= 0 && (c.state == CustState.toTable || c.state == CustState.seated))
        .map((c) => c.tableIndex)
        .toSet();
    for (var i = 0; i < tableCount; i++) {
      if (!used.contains(i)) return i;
    }
    return -1;
  }

  List<Product> _rollItems(CustomerTrait trait) {
    final avail = availableProducts;
    final drinks = avail.where((p) => !p.isFood).toList();
    final foods = avail.where((p) => p.isFood).toList();
    final r = _rng.nextDouble();
    var n = (trait == CustomerTrait.vip || trait == CustomerTrait.critic)
        ? 2
        : (r < 0.55 ? 1 : (r < 0.92 ? 2 : 3));
    if (_s.level < 2) n = min(n, 2);
    final out = <Product>[];
    var guard = 0;
    while (out.length < n && guard++ < 20) {
      final wantFood = _rng.nextDouble() < 0.38 && foods.isNotEmpty;
      final pool = wantFood ? foods : drinks;
      final p = pool[_rng.nextInt(pool.length)];
      if (!out.contains(p)) out.add(p);
    }
    if (out.isEmpty) out.add(drinks.first);
    return out;
  }

  void _spawnCustomer(int slot, {CustomerTrait? forced}) {
    final variant = _rng.nextInt(8);
    final gender = variant < 4 ? Gender.male : Gender.female;
    final names = gender == Gender.male ? Names.male : Names.female;
    final tr = _rng.nextDouble();
    final trait = forced ??
        (tr < 0.14 ? CustomerTrait.impatient : (tr < 0.26 ? CustomerTrait.generous : CustomerTrait.normal));
    final products = _rollItems(trait);
    final traitMul = switch (trait) {
      CustomerTrait.impatient => 0.65,
      CustomerTrait.vip => 0.85,
      CustomerTrait.critic => 1.2,
      CustomerTrait.generous => 1.15,
      CustomerTrait.normal => 1.0,
    };
    final maxP = (26 + 5.0 * products.length) *
        (1 + 0.15 * _s.upgradeLevel(UpgradeType.comfort)) *
        traitMul;
    final c = Customer(
      id: _nextId++,
      variant: variant,
      name: names[_rng.nextInt(names.length)],
      trait: trait,
      items: products.map(OrderItem.new).toList(),
      slot: slot,
      maxPatience: maxP,
      x: doorX,
      y: doorY,
    );
    c.targetX = queueSlots[slot].dx;
    c.targetY = queueSlots[slot].dy;
    c.doorTriggered = true;
    _customers.add(c);
    _doorTimer = 1.5;
    _emit(const DoorOpened());
  }

  bool _moveToward(Customer c, double dt, double speed) {
    final dx = c.targetX - c.x, dy = c.targetY - c.y;
    final dist = sqrt(dx * dx + dy * dy);
    final step = speed * dt;
    c.walkPhase += dt * 9;
    if (dist <= step || dist < 1) {
      c.x = c.targetX;
      c.y = c.targetY;
      return true;
    }
    c.x += dx / dist * step;
    c.y += dy / dist * step;
    c.lean = (dx / dist) * 0.04;
    return false;
  }

  void _updateCustomers(double dt) {
    for (final c in List<Customer>.from(_customers)) {
      c.stateTime += dt;
      if (c.bubbleTime > 0) {
        c.bubbleTime -= dt;
        if (c.bubbleTime <= 0) c.bubble = null;
      }
      if (c.hop > 0) c.hop = max(0, c.hop - dt * 1.3);
      switch (c.state) {
        case CustState.arriving:
          if (_moveToward(c, dt, walkSpeed)) {
            c.state = CustState.ordering;
            c.stateTime = 0;
            c.lean = 0;
            _customerOrders(c);
          }
        case CustState.ordering:
          if (!c.askedBarista && c.stateTime > 1.9) {
            c.askedBarista = true;
            _baristaSay(Lines.baristaAck(_rng));
            _emit(const OrderTaken());
          }
          if (c.stateTime > 3.2) {
            c.state = CustState.waiting;
            c.stateTime = 0;
          }
        case CustState.waiting:
          {
            final rate = c.trait == CustomerTrait.impatient ? 1.25 : 1.0;
            c.patience -= dt * rate;
            if (c.patience <= 0) _leaveAngry(c);
          }
        case CustState.toTable:
          if (_moveToward(c, dt, walkSpeed * 0.8)) {
            c.state = CustState.seated;
            c.lean = 0;
            c.sitTimer = 16 + _rng.nextDouble() * 10 + aesthetic * 0.25;
            c.chatTimer = 2.5;
          }
        case CustState.seated:
          c.sitTimer -= dt;
          c.chatTimer -= dt;
          if (c.chatTimer <= 0) {
            c.chatTimer = 6 + _rng.nextDouble() * 4;
            final line = Lines.chat(_rng, c.gender);
            c.say(line, 3.6);
            if (_rng.nextDouble() < 0.25) _emit(Speak(line, c.gender));
          }
          if (c.sitTimer <= 0) _finishHangout(c);
        case CustState.leaving:
          if (!c.doorTriggered && (doorX - c.x).abs() + (doorY - c.y).abs() < 110) {
            c.doorTriggered = true;
            _doorTimer = 1.5;
            _emit(const DoorOpened());
          }
          if (_moveToward(c, dt, walkSpeed * 1.1)) c.gone = true;
      }
    }
    final removed = _customers.where((c) => c.gone).map((c) => c.id).toList();
    if (removed.isNotEmpty) {
      _customers.removeWhere((c) => c.gone);
      if (_selectedId != null && removed.contains(_selectedId)) _selectedId = null;
      notifyListeners();
    }
  }

  void _customerOrders(Customer c) {
    final text = Lines.order(_rng, c.gender, c.trait, c.items.map((e) => e.product).toList());
    c.say(text, 4.2);
    _emit(Speak(text, c.gender, priority: true));
    notifyListeners();
  }

  void _leaveAngry(Customer c) {
    c.angry = true;
    c.state = CustState.leaving;
    c.doorTriggered = false;
    c.slot = -1;
    c.targetX = doorX;
    c.targetY = doorY;
    _combo = 0;
    _dayAngry++;
    _addRep(c.trait == CustomerTrait.critic ? -0.4 : -0.25);
    final line = Lines.complain(_rng, c.gender);
    c.say(line, 3.2);
    _float('😠', c.x, c.y - 200, Colors.redAccent);
    _emit(Speak(line, c.gender));
    _emit(const CustomerAngry());
    notifyListeners();
  }

  void _finishHangout(Customer c) {
    final bonus = (5 + _rng.nextInt(7) + aesthetic * 0.6).round();
    _s.money += bonus;
    _s.totalEarned += bonus;
    _dayEarned += bonus;
    _dayHangout++;
    _track(MissionKind.hangout, 1);
    _track(MissionKind.earn, bonus);
    _addRep(0.03);
    _float('+$bonus 🪑', c.x, c.targetY - 150, const Color(0xFFB2DFDB));
    final bye = Lines.goodbyeCustomer(_rng);
    c.say(bye, 2.8);
    _emit(Speak(bye, c.gender));
    _baristaSay(Lines.goodbyeBarista(_rng), speak: false);
    _emit(HangoutDone(bonus));
    c.state = CustState.leaving;
    c.doorTriggered = false;
    c.tableIndex = -1;
    c.targetX = doorX;
    c.targetY = doorY;
    _scheduleSave();
    notifyListeners();
  }

  // ---------- pesanan ----------
  void focusCustomer(int id) {
    _selectedId = id;
    notifyListeners();
  }

  void selectCustomer(int? id) {
    _selectedId = id == _selectedId ? null : id;
    notifyListeners();
  }

  Customer? _findMatch(Product p) {
    final cands = _customers
        .where((c) => c.state == CustState.waiting && c.items.any((i) => !i.done && i.product == p))
        .toList();
    if (cands.isEmpty) return null;
    for (final c in cands) {
      if (c.id == _selectedId) return c;
    }
    cands.sort((a, b) => a.patience.compareTo(b.patience));
    return cands.first;
  }

  /// Mulai meracik minuman: bahan langsung terpakai. Mengembalikan pesan error bila gagal.
  String? startCraft(Product p) {
    if (_phase == DayPhase.summary) return 'Hari sudah berakhir.';
    if (p.isFood) return 'Roti dipanggang di oven.';
    if (_s.beans < 1) return 'Biji kopi habis! Beli stok di Toko.';
    if (_s.milk < p.milkNeed) return 'Susu habis! Beli stok di Toko.';
    _s.beans -= 1;
    _s.milk -= p.milkNeed;
    _setFocus(BaristaFocus.machine, 40);
    _scheduleSave();
    notifyListeners();
    return null;
  }

  /// Hasil meracik dari mini-game. [quality] 0..1.
  void finishCraft(Product p, double quality) {
    _setFocus(BaristaFocus.idle, 0);
    if (quality < 0.25) {
      _trash(p, 'gagal', machinePos);
      return;
    }
    final c = _findMatch(p);
    if (c == null) {
      _trash(p, 'tidak ada yang memesan', machinePos);
      return;
    }
    _deliverTo(c, p, quality, machinePos);
  }

  /// Sajikan roti dari etalase.
  bool serveFood(Product p, {int? customerId}) {
    if (!p.isFood || _phase == DayPhase.summary) return false;
    if (customerId != null) _selectedId = customerId;
    final stock = stockOf(p);
    if (stock <= 0) {
      _emit(ToastEvent('Stok ${p.label} habis. Panggang dulu di oven!'));
      return false;
    }
    final c = _findMatch(p);
    if (c == null) {
      _emit(ToastEvent('Tidak ada pelanggan yang memesan ${p.label}.'));
      return false;
    }
    if (stock - 1 <= 0) {
      _s.display.remove(p.name);
    } else {
      _s.display[p.name] = stock - 1;
    }
    _deliverTo(c, p, _dq[p] ?? 0.85, displayPos);
    return true;
  }

  void _deliverTo(Customer c, Product p, double q, Offset from) {
    final item = c.items.firstWhere((i) => !i.done && i.product == p);
    item.done = true;
    item.quality = q;
    _flyers.add(Flyer(p.emoji, from, Offset(c.x, c.y - 120), product: p));
    _emit(ItemDelivered(p, q));
    if (c.allDone) {
      _completeOrder(c);
    } else {
      _float('✔', c.x, c.y - 210, Colors.lightGreenAccent);
    }
    _scheduleSave();
    notifyListeners();
  }

  void _trash(Product p, String reason, Offset from) {
    _combo = 0;
    _dayTrashed++;
    _flyers.add(Flyer(p.emoji, from, binPos + const Offset(0, -60), trash: true, product: p));
    _binShake = 0.9;
    _baristaSay(Lines.wrong(_rng));
    _emit(Trashed(p, reason));
    notifyListeners();
  }

  void _completeOrder(Customer c) {
    final avgQ = c.items.map((i) => i.quality).reduce((a, b) => a + b) / c.items.length;
    var base = 0.0;
    for (final i in c.items) {
      base += i.product.price * (0.55 + 0.45 * i.quality);
    }
    var tipRate = (0.12 + 0.30 * c.patienceFraction) * avgQ;
    if (c.trait == CustomerTrait.generous) tipRate *= 1.8;
    _combo = avgQ >= 0.45 ? _combo + 1 : 0;
    _s.bestCombo = max(_s.bestCombo, _combo);
    if (_combo > 0 && _combo % 5 == 0) {
      _feverLeft = 12;
      _banner('🔥 FEVER! Pendapatan x1.5 selama 12 detik!');
    }
    final feverMul = _feverLeft > 0 ? 1.5 : 1.0;
    final comboMul = 1 + 0.08 * min(max(_combo - 1, 0), 6);
    final bonusMul = _s.bonusActive ? 1.5 : 1.0;
    final traitMul = switch (c.trait) {
      CustomerTrait.vip => 1.8,
      CustomerTrait.critic => 1.4,
      _ => 1.0,
    };
    var earned = ((base + base * tipRate) * comboMul * bonusMul * traitMul * feverMul).round();
    if (c.trait == CustomerTrait.critic) {
      if (avgQ >= 0.8) {
        earned += 80;
        _addRep(0.3);
      } else {
        _addRep(-0.2);
      }
    }
    _s.money += earned;
    _s.totalEarned += earned;
    _s.served++;
    _dayEarned += earned;
    _dayServed++;
    final perfects = c.items.where((i) => i.quality >= 0.85).length;
    _dayPerfect += perfects;
    _addRep(0.03 + (avgQ >= 0.85 ? 0.04 : 0));
    _track(MissionKind.serve, 1);
    if (perfects > 0) _track(MissionKind.perfect, perfects);
    _track(MissionKind.earn, earned);
    _track(MissionKind.combo, _combo, setMax: true);
    _float('+$earned', c.x, c.y - 220, const Color(0xFFFFD54F));
    final thanks = Lines.thanks(_rng, c.gender, avgQ);
    c.say(thanks, 3.4);
    _emit(Speak(thanks, c.gender));
    _emit(OrderServed(earned, _combo, avgQ));
    c.hop = 1;
    _gainXp(8 * c.items.length + (avgQ >= 0.85 ? 6 : 0));

    final t = _freeTable();
    final chance = 0.6 + aesthetic * 0.012 + (raining ? 0.25 : 0.0);
    c.slot = -1;
    c.doorTriggered = false;
    if (t != -1 && _rng.nextDouble() < chance) {
      c.state = CustState.toTable;
      c.tableIndex = t;
      c.targetX = tableSpots[t].dx;
      c.targetY = tableSpots[t].dy - 30;
    } else {
      c.state = CustState.leaving;
      c.targetX = doorX;
      c.targetY = doorY;
    }
  }

  void _gainXp(int n) {
    _s.xp += n;
    while (_s.xp >= xpNeeded(_s.level)) {
      _s.xp -= xpNeeded(_s.level);
      _s.level++;
      final bonus = _s.level * 60;
      _s.money += bonus;
      _s.totalEarned += bonus;
      final unlocked = Product.values.where((p) => p.unlockLevel == _s.level).map((p) => p.label).toList();
      _emit(LevelUp(_s.level, bonus, unlocked.isEmpty ? '' : 'Menu baru: ${unlocked.join(', ')}'));
    }
  }

  void _addRep(double d) => _s.reputation = (_s.reputation + d).clamp(1.0, 5.0).toDouble();

  // ---------- oven ----------
  void _updateOvens(double dt) {
    for (final o in _ovens) {
      switch (o.state) {
        case OvenState.idle:
          break;
        case OvenState.baking:
          o.t += dt;
          if (o.t >= o.total) {
            o.state = OvenState.ready;
            o.readyT = 0;
            _emit(const OvenReady());
            notifyListeners();
          }
        case OvenState.ready:
          o.readyT += dt;
          if (o.readyT > 7) {
            o.state = OvenState.burnt;
            o.readyT = 0;
            _combo = 0;
            _dayTrashed++;
            _flyers.add(Flyer('💨', ovenPos, binPos + const Offset(0, -60), trash: true));
            _baristaSay(Lines.burnt(_rng));
            _emit(const OvenBurnt());
            notifyListeners();
          }
        case OvenState.burnt:
          o.readyT += dt;
          if (o.readyT > 4) {
            o.state = OvenState.idle;
            o.item = null;
            notifyListeners();
          }
      }
    }
  }

  /// Mulai memanggang [trays] loyang (1 loyang = 3 roti). [doughQuality] dari mini-game adonan.
  String? startBake(int slot, Product food, {int trays = 1, double doughQuality = 0.8}) {
    if (slot < 0 || slot >= _ovens.length) return 'Slot oven tidak ada.';
    final o = _ovens[slot];
    if (o.state != OvenState.idle) return 'Oven sedang dipakai.';
    if (!food.isFood) return 'Hanya roti yang dipanggang.';
    final n = trays.clamp(1, 3);
    if (_s.flour < n) return 'Tepung kurang (butuh $n). Beli stok di Toko.';
    _s.flour -= n;
    if (doughQuality < 0.25) {
      _trash(food, 'adonan gagal', ovenPos);
      _scheduleSave();
      return 'Adonan gagal, terbuang. Coba lagi!';
    }
    o
      ..item = food
      ..state = OvenState.baking
      ..trays = n
      ..doughQ = doughQuality
      ..t = 0
      ..readyT = 0;
    _setFocus(BaristaFocus.oven, 1.8);
    _emit(const BakeStarted());
    _scheduleSave();
    notifyListeners();
    return null;
  }

  String? collectOven(int slot) {
    if (slot < 0 || slot >= _ovens.length) return null;
    final o = _ovens[slot];
    if (o.state == OvenState.burnt) {
      o.state = OvenState.idle;
      o.item = null;
      notifyListeners();
      return 'Roti gosong dibuang.';
    }
    if (o.state != OvenState.ready) return null;
    final p = o.item!;
    final space = displayCapacity - displayCount;
    if (space <= 0) return 'Etalase penuh! Sajikan dulu rotinya ke pelanggan.';
    final yieldN = 3 * o.trays;
    final add = min(yieldN, space);
    final timing = (1.0 - o.readyT * 0.055).clamp(0.4, 1.0).toDouble();
    final q = (0.45 * o.doughQ + 0.55 * timing).clamp(0.3, 1.0).toDouble();
    final old = stockOf(p);
    _dq[p] = ((_dq[p] ?? 0.85) * old + q * add) / (old + add);
    _s.display[p.name] = old + add;
    o
      ..state = OvenState.idle
      ..item = null;
    _setFocus(BaristaFocus.oven, 1.4);
    _float('+$add ${p.emoji}', ovenPos.dx, ovenPos.dy - 90, Colors.white);
    _emit(BakeCollected(q >= 0.85));
    _track(MissionKind.bake, 1);
    _scheduleSave();
    notifyListeners();
    return add < yieldN
        ? 'Etalase penuh, hanya $add yang muat. Ketuk ${p.label} untuk menyajikan.'
        : '${p.label} x$add masuk etalase. Ketuk ${p.label} di bar bawah untuk menyajikan ke pelanggan.';
  }

  // ---------- toko ----------
  bool buyUpgrade(UpgradeType t) {
    final lvl = _s.upgradeLevel(t);
    if (lvl >= t.maxLevel) return false;
    final cost = t.costForLevel(lvl);
    if (_s.money < cost) {
      _emit(const NotEnoughCoins());
      return false;
    }
    _s.money -= cost;
    _s.upgrades[t.name] = lvl + 1;
    if (t == UpgradeType.oven) _ovens.add(OvenSlot());
    _emit(UpgradeBought(t));
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool buyDecor(Decor d) {
    if (_s.hasDecor(d.name)) return false;
    if (_s.level < d.levelNeeded) {
      _emit(ToastEvent('Butuh level ${d.levelNeeded}.'));
      return false;
    }
    if (_s.money < d.cost) {
      _emit(const NotEnoughCoins());
      return false;
    }
    // meja harus dibeli berurutan
    final order = [Decor.table3, Decor.table4, Decor.table5, Decor.table6];
    final idx = order.indexOf(d);
    if (idx > 0 && !_s.hasDecor(order[idx - 1].name)) {
      _emit(ToastEvent('Beli ${order[idx - 1].title} dulu.'));
      return false;
    }
    _s.money -= d.cost;
    _s.decor.add(d.name);
    _emit(Purchased(d.title));
    _scheduleSave();
    notifyListeners();
    return true;
  }

  bool buyStock(StockItem item) {
    final total = switch (item) {
      StockItem.beans => _s.beans,
      StockItem.milk => _s.milk,
      StockItem.flour => _s.flour,
    };
    if (total + item.packSize > 99) {
      _emit(ToastEvent('Gudang ${item.label} penuh.'));
      return false;
    }
    if (_s.money < item.packCost) {
      _emit(const NotEnoughCoins());
      return false;
    }
    _s.money -= item.packCost;
    switch (item) {
      case StockItem.beans:
        _s.beans += item.packSize;
      case StockItem.milk:
        _s.milk += item.packSize;
      case StockItem.flour:
        _s.flour += item.packSize;
    }
    _emit(Purchased('${item.label} +${item.packSize}'));
    _scheduleSave();
    notifyListeners();
    return true;
  }

  // ---------- util ----------
  void _setFocus(BaristaFocus f, double seconds) {
    _focus = f;
    _focusTimer = seconds;
  }

  void _baristaSay(String text, {bool speak = true}) {
    _baristaBubble = text;
    _baristaBubbleTime = 3.4;
    if (speak) {
      _emit(Speak(text, _repo.baristaFemale ? Gender.female : Gender.male));
    }
  }

  void _float(String text, double x, double y, Color c) => _floaters.add(FloatingText(text, x, y, c));

  void _emit(GameEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), _flushSave);
  }

  Future<void> _flushSave() async {
    _saveDebounce?.cancel();
    if (!_ready) return;
    await _repo.save(_s);
    await _repo.setCloudDirty(true);
  }

  Future<void> _syncCloud() async {
    final user = _auth.currentUser;
    if (!_ready || user == null || user.isLocalOnly) return;
    try {
      await _cloud.saveProgress(user, _s, city: _repo.cachedCity);
      await _repo.setCloudDirty(false);
    } catch (_) {
      await _repo.setCloudDirty(true); // background task akan mencoba lagi
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudTimer?.cancel();
    _saveDebounce?.cancel();
    if (_ready) {
      _repo.save(_s);
      _syncCloud();
    }
    _events.close();
    frame.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
