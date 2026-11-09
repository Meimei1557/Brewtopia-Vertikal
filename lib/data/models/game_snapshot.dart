import 'upgrade.dart';

/// Tempat/kafe favorit pemain untuk check-in (geolocation).
class CafeSpot {
  CafeSpot({required this.name, required this.lat, required this.lng, this.lastCheckInDay});
  String name;
  double lat;
  double lng;
  String? lastCheckInDay;

  Map<String, dynamic> toJson() =>
      {'name': name, 'lat': lat, 'lng': lng, 'lastCheckInDay': lastCheckInDay};

  factory CafeSpot.fromJson(Map<String, dynamic> j) => CafeSpot(
        name: j['name'] as String? ?? 'Kafe',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        lastCheckInDay: j['lastCheckInDay'] as String?,
      );
}

/// Seluruh progres game yang disimpan (lokal & cloud).
class GameSnapshot {
  GameSnapshot({
    this.money = 150,
    this.level = 1,
    this.xp = 0,
    this.totalEarned = 0,
    this.served = 0,
    this.bestCombo = 0,
    Map<String, int>? upgrades,
    this.tutorialSeen = false,
    this.day = 1,
    this.reputation = 3.0,
    this.beans = 14,
    this.milk = 10,
    this.flour = 5,
    Map<String, int>? display,
    List<String>? decor,
    List<CafeSpot>? spots,
    this.bonusUntilMs = 0,
    this.missionDay,
    List<int>? missionProgress,
    List<bool>? missionClaimed,
    this.lastLoginDay,
    this.streak = 0,
    this.bestDayEarned = 0,
    this.baristaFemale = false,
    int? lastPlayedMs,
  })  : upgrades = upgrades ?? {},
        display = display ?? {},
        decor = decor ?? [],
        spots = spots ?? [],
        missionProgress = missionProgress ?? [0, 0, 0],
        missionClaimed = missionClaimed ?? [false, false, false],
        lastPlayedMs = lastPlayedMs ?? DateTime.now().millisecondsSinceEpoch;

  int money;
  int level;
  int xp;
  int totalEarned;
  int served;
  int bestCombo;
  Map<String, int> upgrades;
  bool tutorialSeen;
  int day;
  double reputation;
  int beans;
  int milk;
  int flour;
  Map<String, int> display; // nama produk -> jumlah di etalase
  List<String> decor; // nama Decor yang sudah dibeli
  List<CafeSpot> spots;
  int bonusUntilMs;
  String? missionDay;
  List<int> missionProgress;
  List<bool> missionClaimed;
  String? lastLoginDay;
  int streak;
  int bestDayEarned;
  bool baristaFemale;
  int lastPlayedMs;

  int upgradeLevel(UpgradeType t) => upgrades[t.name] ?? 0;
  bool hasDecor(String name) => decor.contains(name);

  bool get hasProgress => totalEarned > 0 || level > 1 || served > 0;
  bool get bonusActive => DateTime.now().millisecondsSinceEpoch < bonusUntilMs;

  Map<String, dynamic> toJson() => {
        'money': money,
        'level': level,
        'xp': xp,
        'totalEarned': totalEarned,
        'served': served,
        'bestCombo': bestCombo,
        'upgrades': upgrades,
        'tutorialSeen': tutorialSeen,
        'day': day,
        'reputation': reputation,
        'beans': beans,
        'milk': milk,
        'flour': flour,
        'display': display,
        'decor': decor,
        'spots': spots.map((e) => e.toJson()).toList(),
        'bonusUntilMs': bonusUntilMs,
        'missionDay': missionDay,
        'missionProgress': missionProgress,
        'missionClaimed': missionClaimed,
        'lastLoginDay': lastLoginDay,
        'streak': streak,
        'bestDayEarned': bestDayEarned,
        'baristaFemale': baristaFemale,
        'lastPlayedMs': lastPlayedMs,
      };

  factory GameSnapshot.fromJson(Map<String, dynamic> j) {
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    List<int> ints(String k) =>
        ((j[k] as List?) ?? const [0, 0, 0]).map((e) => (e as num).toInt()).toList();
    List<bool> bools(String k) =>
        ((j[k] as List?) ?? const [false, false, false]).map((e) => e == true).toList();
    return GameSnapshot(
      money: i('money', 150),
      level: i('level', 1),
      xp: i('xp', 0),
      totalEarned: i('totalEarned', 0),
      served: i('served', 0),
      bestCombo: i('bestCombo', 0),
      upgrades: ((j['upgrades'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      tutorialSeen: j['tutorialSeen'] as bool? ?? false,
      day: i('day', 1),
      reputation: (j['reputation'] as num?)?.toDouble() ?? 3.0,
      beans: i('beans', 14),
      milk: i('milk', 10),
      flour: i('flour', 5),
      display: ((j['display'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      decor: ((j['decor'] as List?) ?? const []).map((e) => e.toString()).toList(),
      spots: ((j['spots'] as List?) ?? const [])
          .map((e) => CafeSpot.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bonusUntilMs: i('bonusUntilMs', 0),
      missionDay: j['missionDay'] as String?,
      missionProgress: ints('missionProgress'),
      missionClaimed: bools('missionClaimed'),
      lastLoginDay: j['lastLoginDay'] as String?,
      streak: i('streak', 0),
      bestDayEarned: i('bestDayEarned', 0),
      baristaFemale: j['baristaFemale'] as bool? ?? false,
      lastPlayedMs: (j['lastPlayedMs'] as num?)?.toInt(),
    );
  }

  GameSnapshot copy() => GameSnapshot.fromJson(toJson());
}
