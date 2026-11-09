import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/audio_service.dart';
import '../core/background_service.dart';
import '../core/notification_service.dart';
import '../core/system_volume.dart';
import '../core/voice_service.dart';
import '../data/models/customer.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';

const String appVersion = '2.1.0+3';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel(this._audio, this._voice, this._sysVolume, this._auth, this._cloud,
      this._game, this._notifications, this._prefs);

  final AudioService _audio;
  final VoiceService _voice;
  final SystemVolume _sysVolume;
  StreamSubscription<double>? _volSub;
  double systemVolume = 0.5;
  final AuthRepository _auth;
  final CloudRepository _cloud;
  final GameRepository _game;
  final NotificationService _notifications;
  final SharedPreferences _prefs;

  String? error;
  bool busy = false;
  bool baristaFemale = false;

  double get musicVolume => _audio.musicVolume;
  double get sfxVolume => _audio.sfxVolume;
  int get track => _audio.track;
  bool get voiceEnabled => _voice.enabled;
  bool get backgroundEnabled => _prefs.getBool(PrefKeys.bgEnabled) ?? true;
  String get userName => _auth.currentUser?.displayName ?? '-';
  String? get email => _auth.currentUser?.email;
  bool get isGuest => _auth.currentUser?.isGuest ?? true;
  bool get cloudAvailable => _auth.cloudAvailable;

  double get voiceVolume => _voice.volume;

  /// Mulai memantau volume HP (tombol volume ikut menggerakkan slider).
  Future<void> startWatching() async {
    baristaFemale = _game.baristaFemale;
    systemVolume = await _sysVolume.get();
    notifyListeners();
    await _volSub?.cancel();
    _volSub = _sysVolume.changes.listen((v) {
      systemVolume = v;
      notifyListeners();
    });
  }

  void stopWatching() {
    _volSub?.cancel();
    _volSub = null;
  }

  Future<void> setSystemVolume(double v) async {
    systemVolume = v;
    notifyListeners();
    systemVolume = await _sysVolume.set(v);
    notifyListeners();
  }

  Future<void> setVoiceVolume(double v) async {
    await _voice.setVolume(v);
    notifyListeners();
  }

  Future<void> speakTest(Gender g) => _voice.speak(
      g == Gender.male ? 'Halo kak, selamat datang di kafe kami!' : 'Hai kak, mau pesan apa hari ini?', g,
      priority: true);

  void previewSfx() => _audio.play(Sfx.coin);

  Future<void> setMusicVolume(double v) async {
    await _audio.setMusicVolume(v);
    notifyListeners();
  }

  Future<void> setSfxVolume(double v) async {
    await _audio.setSfxVolume(v);
    notifyListeners();
  }

  Future<void> setTrack(int i) async {
    await _audio.setTrack(i);
    notifyListeners();
  }

  Future<void> setVoiceEnabled(bool v) async {
    await _voice.setEnabled(v);
    notifyListeners();
  }

  Future<void> setBaristaFemale(bool v) async {
    await _game.setBaristaFemale(v); // tersimpan di preferensi & langsung dipakai game
    baristaFemale = v;
    notifyListeners();
  }

  Future<void> setBackgroundEnabled(bool on) async {
    await _prefs.setBool(PrefKeys.bgEnabled, on);
    if (on) {
      await _notifications.requestPermission();
      await BackgroundService.enable();
    } else {
      await BackgroundService.disable();
    }
    notifyListeners();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> resetLocalData() async {
    await _game.clear();
    notifyListeners();
  }

  /// Hapus akun + data cloud (wajib untuk aplikasi Play Store yang punya akun).
  Future<bool> deleteAccount() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final uid = _auth.currentUser?.uid;
      if (uid != null && !_auth.currentUser!.isLocalOnly) {
        await _cloud.deletePlayer(uid);
      }
      await _auth.deleteAccount();
      await _game.clear();
      return true;
    } on AuthException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Gagal menghapus akun. Coba lagi.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
