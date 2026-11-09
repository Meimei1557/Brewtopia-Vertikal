import 'dart:math';

enum MissionKind { serve, perfect, bake, earn, combo, hangout }

class MissionDef {
  const MissionDef(this.kind, this.target, this.reward);
  final MissionKind kind;
  final int target;
  final int reward;

  String get label => switch (kind) {
        MissionKind.serve => 'Layani $target pelanggan',
        MissionKind.perfect => 'Buat $target pesanan SEMPURNA',
        MissionKind.bake => 'Panggang $target loyang roti',
        MissionKind.earn => 'Kumpulkan $target koin',
        MissionKind.combo => 'Capai combo x$target',
        MissionKind.hangout => '$target pelanggan nongkrong di meja',
      };

  String get icon => switch (kind) {
        MissionKind.serve => '🧑‍🤝‍🧑',
        MissionKind.perfect => '⭐',
        MissionKind.bake => '🥐',
        MissionKind.earn => '🪙',
        MissionKind.combo => '🔥',
        MissionKind.hangout => '🪑',
      };
}

class MissionState {
  MissionState(this.def, this.progress, this.claimed);
  final MissionDef def;
  int progress;
  bool claimed;
  bool get done => progress >= def.target;
}

const _targets = {
  MissionKind.serve: [8, 12, 18],
  MissionKind.perfect: [2, 4, 6],
  MissionKind.bake: [2, 3, 5],
  MissionKind.earn: [150, 300, 500],
  MissionKind.combo: [3, 5, 7],
  MissionKind.hangout: [3, 5, 8],
};
const _rewards = [80, 130, 200];

/// Misi harian: 3 misi acak tapi konsisten untuk tanggal yang sama.
List<MissionDef> generateMissions(String dayKey, int tier) {
  var seed = 17;
  for (final c in dayKey.codeUnits) {
    seed = (seed * 31 + c) & 0x7fffffff;
  }
  final rnd = Random(seed);
  final kinds = MissionKind.values.toList()..shuffle(rnd);
  return kinds.take(3).map((k) => MissionDef(k, _targets[k]![tier], _rewards[tier])).toList();
}
