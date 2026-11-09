import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/models/app_user.dart';
import '../data/models/game_snapshot.dart';
import '../data/models/upgrade.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';
import 'notification_service.dart';

const String taskIdleIncome = 'brewtopia.idle_income';
const String taskCloudSync = 'brewtopia.cloud_sync';
const String _uniqueIdle = 'brewtopia_idle_income_periodic';
const String _uniqueSync = 'brewtopia_cloud_sync_oneoff';

/// Entry point isolate background (dijalankan oleh WorkManager, bukan oleh UI).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      switch (task) {
        case taskIdleIncome:
          return await runIdleIncome();
        case taskCloudSync:
          return await runCloudSync();
      }
    } catch (e) {
      debugPrint('Background task $task gagal: $e');
      return task == taskCloudSync ? false : true; // false => WorkManager retry
    }
    return true;
  });
}

/// Kafe tetap menghasilkan koin (pasif) selama pemain pergi + kirim notifikasi.
/// Dipisah dari callbackDispatcher agar bisa diuji.
Future<bool> runIdleIncome({SharedPreferences? prefs, DateTime? now}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.reload();
  if (!(p.getBool(PrefKeys.bgEnabled) ?? true)) return true;
  final raw = p.getString(PrefKeys.snapshot);
  if (raw == null) return true;
  final s = GameSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  if (!s.hasProgress) return true;

  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final perRun = 12 * s.level + 8 * s.upgradeLevel(UpgradeType.marketing);
  final cap = 600 + 400 * s.level; // batas akumulasi pendapatan pasif
  final pending = min(cap, (p.getInt(PrefKeys.pendingIdle) ?? 0) + perRun);
  await p.setInt(PrefKeys.pendingIdle, pending);

  final lastNotif = p.getInt(PrefKeys.lastNotifMs) ?? 0;
  final idleHours = (nowMs - s.lastPlayedMs) / 3600000.0;
  if (nowMs - lastNotif > 6 * 3600000 && idleHours >= 1) {
    final n = NotificationService();
    final body = idleHours >= 24
        ? 'Pelangganmu merindukan kopi buatanmu! $pending koin menunggu diambil.'
        : 'Kafemu menghasilkan $pending koin saat kamu pergi. Ayo kumpulkan!';
    await n.show(1001, 'Brewtopia', body);
    await p.setInt(PrefKeys.lastNotifMs, nowMs);
  }
  return true;
}

/// Mengunggah progres ke Firestore dari background bila sebelumnya gagal/offline.
Future<bool> runCloudSync() async {
  final p = await SharedPreferences.getInstance();
  await p.reload();
  if (!(p.getBool(PrefKeys.cloudDirty) ?? false)) return true;
  final raw = p.getString(PrefKeys.snapshot);
  if (raw == null) return true;

  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return true;

  final snap = GameSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  final name = p.getString(PrefKeys.cloudName) ?? user.displayName ?? 'Barista';
  await FirestoreCloudRepository().saveProgress(
    AppUser(uid: user.uid, displayName: name, isGuest: user.isAnonymous),
    snap,
    city: p.getString(PrefKeys.cloudCity),
  );
  await p.setBool(PrefKeys.cloudDirty, false);
  return true;
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(PrefKeys.bgEnabled) ?? true) await enable();
  }

  static Future<void> enable() async {
    await Workmanager().registerPeriodicTask(
      _uniqueIdle,
      taskIdleIncome,
      frequency: const Duration(hours: 1),
    );
  }

  static Future<void> disable() async {
    await Workmanager().cancelByUniqueName(_uniqueIdle);
  }

  /// Dijadwalkan saat app ke background agar progres tidak hilang bila sync gagal.
  static Future<void> scheduleCloudSync() async {
    await Workmanager().registerOneOffTask(
      _uniqueSync,
      taskCloudSync,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}
