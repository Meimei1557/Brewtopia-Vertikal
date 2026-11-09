import 'dart:convert';

import 'package:brewtopia/core/background_service.dart';
import 'package:brewtopia/data/models/game_snapshot.dart';
import 'package:brewtopia/data/repositories/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('runIdleIncome menambah pendapatan pasif sesuai level & batas', () async {
    final snap = GameSnapshot(level: 3, totalEarned: 500, served: 10);
    SharedPreferences.setMockInitialValues({
      PrefKeys.snapshot: jsonEncode(snap.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    // Dipanggil dengan prefs tiruan: notifikasi dilewati karena belum 1 jam idle.
    final ok = await runIdleIncome(prefs: prefs, now: DateTime.now());
    expect(ok, isTrue);
    expect(prefs.getInt(PrefKeys.pendingIdle), 12 * 3);
  });

  test('runIdleIncome tidak berjalan bila dimatikan di pengaturan', () async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.bgEnabled: false,
      PrefKeys.snapshot: jsonEncode(GameSnapshot(level: 2, served: 5).toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    await runIdleIncome(prefs: prefs);
    expect(prefs.getInt(PrefKeys.pendingIdle), isNull);
  });
}
