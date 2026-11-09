import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_snapshot.dart';

/// Kunci SharedPreferences dibagi dengan background isolate.
class PrefKeys {
  static const snapshot = 'game_snapshot';
  static const pendingIdle = 'pending_idle_income';
  static const cloudDirty = 'cloud_dirty';
  static const cloudUid = 'cloud_uid';
  static const cloudName = 'cloud_name';
  static const cloudCity = 'cloud_city';
  static const lastNotifMs = 'last_notif_ms';
  static const bgEnabled = 'bg_enabled';
  static const musicVol = 'music_volume';
  static const sfxVol = 'sfx_volume';
  static const barista = 'barista_female';
}

abstract class GameRepository {
  Future<GameSnapshot> load();
  Future<void> save(GameSnapshot s);
  Future<int> takePendingIdleIncome();
  Future<void> setCloudDirty(bool dirty, {String? uid, String? name, String? city});
  Future<void> rememberCity(String city);
  String? get cachedCity;
  bool get baristaFemale;
  Future<void> setBaristaFemale(bool v);
  Future<void> clear();
}

class LocalGameRepository implements GameRepository {
  LocalGameRepository(this._prefs);
  final SharedPreferences _prefs;

  @override
  Future<GameSnapshot> load() async {
    await _prefs.reload(); // background isolate bisa mengubah nilai
    final raw = _prefs.getString(PrefKeys.snapshot);
    if (raw == null) return GameSnapshot();
    try {
      return GameSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return GameSnapshot();
    }
  }

  @override
  Future<void> save(GameSnapshot s) async {
    s.lastPlayedMs = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setString(PrefKeys.snapshot, jsonEncode(s.toJson()));
  }

  @override
  Future<int> takePendingIdleIncome() async {
    await _prefs.reload();
    final v = _prefs.getInt(PrefKeys.pendingIdle) ?? 0;
    if (v > 0) await _prefs.setInt(PrefKeys.pendingIdle, 0);
    return v;
  }

  @override
  Future<void> setCloudDirty(bool dirty,
      {String? uid, String? name, String? city}) async {
    await _prefs.setBool(PrefKeys.cloudDirty, dirty);
    if (uid != null) await _prefs.setString(PrefKeys.cloudUid, uid);
    if (name != null) await _prefs.setString(PrefKeys.cloudName, name);
    if (city != null) await _prefs.setString(PrefKeys.cloudCity, city);
  }

  @override
  Future<void> rememberCity(String city) => _prefs.setString(PrefKeys.cloudCity, city);

  @override
  String? get cachedCity => _prefs.getString(PrefKeys.cloudCity);

  @override
  bool get baristaFemale => _prefs.getBool(PrefKeys.barista) ?? false;

  @override
  Future<void> setBaristaFemale(bool v) => _prefs.setBool(PrefKeys.barista, v);

  @override
  Future<void> clear() async {
    await _prefs.remove(PrefKeys.snapshot);
    await _prefs.remove(PrefKeys.pendingIdle);
    await _prefs.remove(PrefKeys.cloudDirty);
  }
}
