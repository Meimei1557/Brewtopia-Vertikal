import 'package:flutter/material.dart';

enum CraftStep { grind, extract, pour, steam, knead, shape, glaze }

enum Product { espresso, americano, macchiato, cappuccino, latte, doughnut, croissant, cheesecake }

extension ProductX on Product {
  bool get isFood =>
      this == Product.doughnut || this == Product.croissant || this == Product.cheesecake;

  String get label => switch (this) {
        Product.espresso => 'Espresso',
        Product.americano => 'Americano',
        Product.macchiato => 'Macchiato',
        Product.cappuccino => 'Cappuccino',
        Product.latte => 'Latte',
        Product.doughnut => 'Donat',
        Product.croissant => 'Croissant',
        Product.cheesecake => 'Cheesecake',
      };

  /// Kata yang diucapkan saat dialog.
  String get spoken => switch (this) {
        Product.espresso => 'espresso',
        Product.americano => 'americano',
        Product.macchiato => 'macchiato',
        Product.cappuccino => 'cappuccino',
        Product.latte => 'latte',
        Product.doughnut => 'donat',
        Product.croissant => 'croissant',
        Product.cheesecake => 'cheesecake',
      };

  String get emoji => switch (this) {
        Product.doughnut => '🍩',
        Product.croissant => '🥐',
        Product.cheesecake => '🍰',
        _ => '☕',
      };

  int get price => switch (this) {
        Product.espresso => 12,
        Product.americano => 15,
        Product.macchiato => 20,
        Product.cappuccino => 22,
        Product.latte => 25,
        Product.doughnut => 10,
        Product.croissant => 14,
        Product.cheesecake => 20,
      };

  int get unlockLevel => switch (this) {
        Product.espresso => 1,
        Product.americano => 1,
        Product.doughnut => 1,
        Product.macchiato => 2,
        Product.croissant => 2,
        Product.cappuccino => 3,
        Product.cheesecake => 3,
        Product.latte => 4,
      };

  int get milkNeed => switch (this) {
        Product.macchiato => 1,
        Product.cappuccino => 1,
        Product.latte => 2,
        _ => 0,
      };

  /// Langkah mini-game meracik (hanya minuman).
  List<CraftStep> get steps => switch (this) {
        Product.espresso => const [CraftStep.grind, CraftStep.extract],
        Product.americano => const [CraftStep.grind, CraftStep.extract, CraftStep.pour],
        Product.macchiato => const [CraftStep.grind, CraftStep.extract, CraftStep.steam],
        Product.cappuccino => const [CraftStep.grind, CraftStep.extract, CraftStep.steam],
        Product.latte => const [CraftStep.grind, CraftStep.extract, CraftStep.steam, CraftStep.pour],
        Product.doughnut => const [CraftStep.knead, CraftStep.glaze],
        Product.croissant => const [CraftStep.knead, CraftStep.shape],
        Product.cheesecake => const [CraftStep.knead, CraftStep.glaze],
      };

  String get iconAsset => 'assets/icons/$name.png';

  /// Resep singkat yang ditampilkan saat meracik.
  String get recipe => switch (this) {
        Product.espresso => 'Espresso = giling biji + seduh',
        Product.americano => 'Americano = espresso + air panas',
        Product.macchiato => 'Macchiato = espresso + sedikit busa susu',
        Product.cappuccino => 'Cappuccino = espresso + susu uap + busa tebal',
        Product.latte => 'Latte = espresso + banyak susu + tuang halus',
        Product.doughnut => 'Donat = uleni adonan + beri glasir, lalu panggang',
        Product.croissant => 'Croissant = uleni + lipat berlapis, lalu panggang',
        Product.cheesecake => 'Cheesecake = aduk adonan + glasir stroberi, lalu panggang',
      };

  double get bakeSeconds => switch (this) {
        Product.doughnut => 9,
        Product.croissant => 11,
        Product.cheesecake => 14,
        _ => 0,
      };

  Color get color => switch (this) {
        Product.espresso => const Color(0xFF4E342E),
        Product.americano => const Color(0xFF6D4C41),
        Product.macchiato => const Color(0xFFD7A86E),
        Product.cappuccino => const Color(0xFFA1887F),
        Product.latte => const Color(0xFFBCAAA4),
        Product.doughnut => const Color(0xFFE88BA6),
        Product.croissant => const Color(0xFFE0A24A),
        Product.cheesecake => const Color(0xFFF2D9A0),
      };

  static List<Product> availableAt(int level) =>
      Product.values.where((p) => p.unlockLevel <= level).toList();
}

extension CraftStepX on CraftStep {
  String get label => switch (this) {
        CraftStep.grind => 'Giling biji',
        CraftStep.extract => 'Seduh espresso',
        CraftStep.pour => 'Tuang air/susu',
        CraftStep.steam => 'Uap susu',
        CraftStep.knead => 'Uleni adonan',
        CraftStep.shape => 'Lipat berlapis',
        CraftStep.glaze => 'Beri glasir',
      };
  String get emoji => switch (this) {
        CraftStep.grind => '⚙️',
        CraftStep.extract => '☕',
        CraftStep.pour => '🥛',
        CraftStep.steam => '♨️',
        CraftStep.knead => '👐',
        CraftStep.shape => '🥐',
        CraftStep.glaze => '🍓',
      };
}
