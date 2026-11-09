enum Decor {
  table3, table4, table5, table6,
  plantBig, plantSmall, rug, frames, neon, stringLights, pendantLamps, jukebox,
  cloth1, cloth2,
}

extension DecorX on Decor {
  String get title => switch (this) {
        Decor.table3 => 'Meja ke-3',
        Decor.table4 => 'Meja ke-4',
        Decor.table5 => 'Meja ke-5',
        Decor.table6 => 'Meja ke-6',
        Decor.plantBig => 'Tanaman Besar',
        Decor.plantSmall => 'Tanaman Kecil',
        Decor.rug => 'Karpet Cantik',
        Decor.frames => 'Bingkai Dinding',
        Decor.neon => 'Neon OPEN',
        Decor.stringLights => 'Lampu Hias',
        Decor.pendantLamps => 'Lampu Gantung',
        Decor.jukebox => 'Jukebox Retro',
        Decor.cloth1 => 'Taplak Mint',
        Decor.cloth2 => 'Taplak Pink',
      };

  String get desc => switch (this) {
        Decor.table3 || Decor.table4 || Decor.table5 || Decor.table6 =>
          'Tambah tempat nongkrong. Lebih banyak pelanggan bisa duduk.',
        Decor.jukebox => 'Ketuk jukebox untuk ganti lagu.',
        Decor.cloth1 || Decor.cloth2 => 'Ganti warna taplak semua meja.',
        _ => 'Mempercantik kafe dan menarik lebih banyak pelanggan.',
      };

  String get emoji => switch (this) {
        Decor.table3 || Decor.table4 || Decor.table5 || Decor.table6 => '🪑',
        Decor.plantBig || Decor.plantSmall => '🪴',
        Decor.rug => '🟫',
        Decor.frames => '🖼️',
        Decor.neon => '💡',
        Decor.stringLights => '✨',
        Decor.pendantLamps => '🏮',
        Decor.jukebox => '🎵',
        Decor.cloth1 || Decor.cloth2 => '🎨',
      };

  int get cost => switch (this) {
        Decor.table3 => 150,
        Decor.table4 => 250,
        Decor.table5 => 400,
        Decor.table6 => 600,
        Decor.plantBig => 120,
        Decor.plantSmall => 80,
        Decor.rug => 200,
        Decor.frames => 150,
        Decor.neon => 250,
        Decor.stringLights => 180,
        Decor.pendantLamps => 300,
        Decor.jukebox => 400,
        Decor.cloth1 => 100,
        Decor.cloth2 => 160,
      };

  int get levelNeeded => switch (this) {
        Decor.table3 => 2,
        Decor.table4 => 3,
        Decor.table5 => 5,
        Decor.table6 => 6,
        Decor.jukebox => 4,
        Decor.pendantLamps => 3,
        Decor.neon => 3,
        _ => 1,
      };

  /// Poin estetika: menaikkan jumlah pelanggan, tip, dan lama nongkrong.
  int get aesthetic => switch (this) {
        Decor.table3 || Decor.table4 || Decor.table5 || Decor.table6 => 1,
        Decor.plantBig => 4,
        Decor.plantSmall => 2,
        Decor.rug => 5,
        Decor.frames => 3,
        Decor.neon => 4,
        Decor.stringLights => 4,
        Decor.pendantLamps => 5,
        Decor.jukebox => 4,
        Decor.cloth1 || Decor.cloth2 => 2,
      };
}
