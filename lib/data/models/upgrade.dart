import 'dart:math';
import 'package:flutter/material.dart';

enum UpgradeType { machine, oven, display, comfort, marketing }

extension UpgradeTypeX on UpgradeType {
  String get title => switch (this) {
        UpgradeType.machine => 'Mesin Kopi Pro',
        UpgradeType.oven => 'Slot Oven Baru',
        UpgradeType.display => 'Etalase Lebih Besar',
        UpgradeType.comfort => 'Kursi Nyaman',
        UpgradeType.marketing => 'Promosi Sosmed',
      };

  String get description => switch (this) {
        UpgradeType.machine => 'Zona hijau meracik lebih lebar & penggilingan lebih mudah.',
        UpgradeType.oven => 'Panggang lebih banyak roti sekaligus (+1 slot oven).',
        UpgradeType.display => 'Etalase menampung +3 roti lagi.',
        UpgradeType.comfort => 'Pelanggan 15% lebih sabar menunggu.',
        UpgradeType.marketing => 'Pelanggan datang 10% lebih sering.',
      };

  IconData get icon => switch (this) {
        UpgradeType.machine => Icons.coffee_maker,
        UpgradeType.oven => Icons.local_fire_department,
        UpgradeType.display => Icons.inventory_2,
        UpgradeType.comfort => Icons.chair_alt,
        UpgradeType.marketing => Icons.campaign,
      };

  int get baseCost => switch (this) {
        UpgradeType.machine => 120,
        UpgradeType.oven => 300,
        UpgradeType.display => 140,
        UpgradeType.comfort => 90,
        UpgradeType.marketing => 150,
      };

  int get maxLevel => switch (this) {
        UpgradeType.oven => 2,
        UpgradeType.display => 4,
        _ => 5,
      };

  int costForLevel(int currentLevel) => (baseCost * pow(1.8, currentLevel)).round();
}

enum StockItem { beans, milk, flour }

extension StockItemX on StockItem {
  String get label => switch (this) {
        StockItem.beans => 'Biji Kopi',
        StockItem.milk => 'Susu',
        StockItem.flour => 'Tepung',
      };
  IconData get icon => switch (this) {
        StockItem.beans => Icons.grain,
        StockItem.milk => Icons.water_drop,
        StockItem.flour => Icons.bakery_dining,
      };
  int get packSize => switch (this) {
        StockItem.beans => 10,
        StockItem.milk => 10,
        StockItem.flour => 5,
      };
  int get packCost => switch (this) {
        StockItem.beans => 36,
        StockItem.milk => 28,
        StockItem.flour => 30,
      };
}
