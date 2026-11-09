import 'package:flutter/material.dart';

enum Drink { espresso, americano, cappuccino, latte, macchiato }

extension DrinkX on Drink {
  String get label => switch (this) {
        Drink.espresso => 'Espresso',
        Drink.americano => 'Americano',
        Drink.cappuccino => 'Cappuccino',
        Drink.latte => 'Latte',
        Drink.macchiato => 'Macchiato',
      };

  int get price => switch (this) {
        Drink.espresso => 15,
        Drink.americano => 20,
        Drink.cappuccino => 28,
        Drink.latte => 32,
        Drink.macchiato => 40,
      };

  /// Level minimum untuk membuka minuman ini.
  int get unlockLevel => switch (this) {
        Drink.espresso => 1,
        Drink.americano => 1,
        Drink.cappuccino => 2,
        Drink.latte => 3,
        Drink.macchiato => 4,
      };

  Color get color => switch (this) {
        Drink.espresso => const Color(0xFF4E342E),
        Drink.americano => const Color(0xFF6D4C41),
        Drink.cappuccino => const Color(0xFFA1887F),
        Drink.latte => const Color(0xFFBCAAA4),
        Drink.macchiato => const Color(0xFFD7A86E),
      };

  static List<Drink> availableAt(int level) =>
      Drink.values.where((d) => d.unlockLevel <= level).toList();
}
