import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/game_repository.dart';

/// Setiap efek suara punya jalur (channel), prioritas, dan jeda minimum supaya tidak bertumpuk.
enum Sfx {
  doorOpen('door_open', Ch.world, 1, 1300, 800),
  ding('ding', Ch.world, 1, 900, 400),
  ovenDing('oven_ding', Ch.world, 2, 1000, 800),
  grind('grind', Ch.craft, 1, 1400, 0),
  brew('brew', Ch.craft, 1, 2200, 0),
  steam('steam', Ch.craft, 1, 1600, 0),
  pour('pour', Ch.craft, 1, 1100, 0),
  coin('coin', Ch.reward, 1, 600, 250),
  combo('combo', Ch.reward, 3, 1300, 600),
  perfect('perfect', Ch.reward, 2, 1300, 600),
  trash('trash', Ch.fx, 2, 1000, 500),
  error('error', Ch.fx, 1, 600, 500),
  tap('tap', Ch.ui, 1, 90, 60),
  pop('pop', Ch.ui, 1, 130, 120),
  levelup('levelup', Ch.reward, 4, 2300, 1000),
  event('event', Ch.reward, 3, 1600, 1000),
  dayEnd('day_end', Ch.reward, 4, 2500, 1000);

  const Sfx(this.file, this.channel, this.priority, this.durationMs, this.cooldownMs);
  final String file;
  final Ch channel;
  final int priority;
  final int durationMs;
  final int cooldownMs;
}

enum Ch { ui, reward, world, fx, craft }

class _Channel {
  final AudioPlayer player = AudioPlayer();
  int priority = 0;
  DateTime busyUntil = DateTime.fromMillisecondsSinceEpoch(0);
}

/// Musik latar + efek suara.
/// - Tidak merebut audio focus (musik/dialog tidak saling mematikan).
/// - Volume keseluruhan mengikuti volume HP; slider di app hanya mengatur campuran relatif.
class AudioService {
  AudioService(this._prefs);
  final SharedPreferences _prefs;

  static const tracks = ['audio/cafe_bossa.ogg', 'audio/cafe_lofi.ogg', 'audio/bbg.ogg'];
  static const trackNames = ['Ceria', 'Santai', 'Klasik'];
  static const _trackKey = 'music_track_v2';

  final AudioPlayer _music = AudioPlayer();
  final Map<Ch, _Channel> _ch = {for (final c in Ch.values) c: _Channel()};
  final Map<Sfx, DateTime> _last = {};
  Timer? _watchdog;
  double _musicVol = 0.7;
  double _sfxVol = 1.0;
  int _track = 0;
  bool _wantMusic = false;
  bool _foreground = true;
  bool _ducked = false;

  double get musicVolume => _musicVol;
  double get sfxVolume => _sfxVol;
  int get track => _track;

  AudioContext _ctx(bool music) => AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: music ? AndroidContentType.music : AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none, // jangan rebut focus -> suara lain tidak mati
        ),
      );

  Future<void> init() async {
    _musicVol = _prefs.getDouble(PrefKeys.musicVol) ?? 0.7;
    _sfxVol = _prefs.getDouble(PrefKeys.sfxVol) ?? 1.0;
    _track = (_prefs.getInt(_trackKey) ?? 0).clamp(0, tracks.length - 1);
    try {
      await _music.setAudioContext(_ctx(true));
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVol);
      for (final c in _ch.values) {
        await c.player.setAudioContext(_ctx(false));
        await c.player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (_) {}
    // pengawas: bila musik berhenti sendiri saat app di depan, nyalakan lagi
    _watchdog = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_wantMusic && _foreground && _music.state != PlayerState.playing) {
        try {
          await _music.play(AssetSource(tracks[_track]), volume: _effMusic);
        } catch (_) {}
      }
    });
  }

  double get _effMusic => _musicVol * (_ducked ? 0.35 : 1.0);

  Future<void> startMusic() async {
    _wantMusic = true;
    _foreground = true;
    if (_music.state == PlayerState.playing) return;
    try {
      await _music.play(AssetSource(tracks[_track]), volume: _effMusic);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    _wantMusic = false;
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> setTrack(int i) async {
    _track = i.clamp(0, tracks.length - 1);
    await _prefs.setInt(_trackKey, _track);
    try {
      await _music.stop();
    } catch (_) {}
    if (_wantMusic) {
      try {
        await _music.play(AssetSource(tracks[_track]), volume: _effMusic);
      } catch (_) {}
    }
  }

  Future<void> nextTrack() => setTrack((_track + 1) % tracks.length);

  /// App ke background: semua suara berhenti.
  Future<void> pauseAll() async {
    _foreground = false;
    try {
      await _music.pause();
      for (final c in _ch.values) {
        await c.player.stop();
      }
    } catch (_) {}
  }

  /// App kembali ke depan: lanjutkan musik.
  Future<void> resumeAll() async {
    _foreground = true;
    if (!_wantMusic) return;
    try {
      if (_music.state == PlayerState.paused) {
        await _music.resume();
      } else if (_music.state != PlayerState.playing) {
        await _music.play(AssetSource(tracks[_track]), volume: _effMusic);
      }
    } catch (_) {}
  }

  /// Musik mengecil sementara saat dialog diucapkan.
  Future<void> duck(bool on) async {
    _ducked = on;
    try {
      await _music.setVolume(_effMusic);
    } catch (_) {}
  }

  Future<void> play(Sfx sfx, {double gain = 1.0}) async {
    if (_sfxVol <= 0 || !_foreground) return;
    final now = DateTime.now();
    final last = _last[sfx];
    if (last != null && now.difference(last).inMilliseconds < sfx.cooldownMs) return;
    final ch = _ch[sfx.channel]!;
    final busy = now.isBefore(ch.busyUntil);
    if (busy && sfx.priority < ch.priority) return; // jalur sedang memutar suara yang lebih penting
    _last[sfx] = now;
    ch.priority = sfx.priority;
    ch.busyUntil = now.add(Duration(milliseconds: sfx.durationMs));
    try {
      await ch.player.stop();
      await ch.player.play(AssetSource('sfx/${sfx.file}.wav'),
          volume: (_sfxVol * gain).clamp(0.0, 1.0).toDouble());
    } catch (_) {}
  }

  /// Suara proses meracik (giling/seduh/uap); hentikan dengan [stopLong].
  Future<void> playLong(Sfx sfx, {double gain = 1.0}) => play(sfx, gain: gain);

  Future<void> stopLong() async {
    final ch = _ch[Ch.craft]!;
    ch.busyUntil = DateTime.fromMillisecondsSinceEpoch(0);
    ch.priority = 0;
    try {
      await ch.player.stop();
    } catch (_) {}
  }

  Future<void> setMusicVolume(double v) async {
    _musicVol = v;
    await _prefs.setDouble(PrefKeys.musicVol, v);
    try {
      await _music.setVolume(_effMusic);
    } catch (_) {}
  }

  Future<void> setSfxVolume(double v) async {
    _sfxVol = v;
    await _prefs.setDouble(PrefKeys.sfxVol, v);
  }

  Future<void> dispose() async {
    _watchdog?.cancel();
    await _music.dispose();
    for (final c in _ch.values) {
      await c.player.dispose();
    }
  }
}
