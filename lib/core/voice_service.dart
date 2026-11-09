import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/customer.dart';

class _Line {
  _Line(this.text, this.gender);
  final String text;
  final Gender gender;
}

/// Suara dialog (text-to-speech Android) dengan ANTREAN: satu kalimat selesai dulu baru berikutnya,
/// tidak pernah memotong kalimat yang sedang diucapkan. Pria: nada rendah, wanita: nada tinggi.
class VoiceService {
  VoiceService(this._prefs);
  final SharedPreferences _prefs;
  static const _keyOn = 'voice_enabled';
  static const _keyVol = 'voice_volume';

  final FlutterTts _tts = FlutterTts();
  final List<Map<String, String>> _idVoices = [];
  final List<_Line> _queue = [];
  bool _ready = false;
  bool _initializing = false;
  bool _running = false;
  bool enabled = true;
  double volume = 1.0;

  /// Dipanggil true/false saat mulai/selesai bicara (dipakai untuk mengecilkan musik).
  void Function(bool speaking)? onSpeaking;

  Future<void> init() async {
    if (_ready || _initializing) return;
    _initializing = true;
    enabled = _prefs.getBool(_keyOn) ?? true;
    volume = _prefs.getDouble(_keyVol) ?? 1.0;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('id-ID');
      try {
        await _tts.setQueueMode(1); // tambah ke antrean, jangan memotong
      } catch (_) {}
      final voices = await _tts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final loc = (v['locale'] ?? '').toString();
            if (loc.toLowerCase().replaceAll('_', '-').startsWith('id')) {
              _idVoices.add({'name': (v['name'] ?? '').toString(), 'locale': loc});
            }
          }
        }
      }
      _ready = true;
    } catch (e) {
      debugPrint('TTS tidak tersedia: $e');
    }
    _initializing = false;
  }

  Future<void> setEnabled(bool v) async {
    enabled = v;
    await _prefs.setBool(_keyOn, v);
    if (!v) await stop();
  }

  Future<void> setVolume(double v) async {
    volume = v;
    await _prefs.setDouble(_keyVol, v);
  }

  Future<void> stop() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Masukkan kalimat ke antrean. Antrean maksimal 2; kalimat penting boleh menggeser yang menunggu.
  Future<void> speak(String text, Gender gender, {bool priority = false}) async {
    if (!enabled) return;
    if (!_ready) {
      await init();
      if (!_ready) return;
    }
    if (_queue.length >= 2) {
      if (!priority) return;
      _queue.removeLast();
    }
    _queue.add(_Line(text, gender));
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    onSpeaking?.call(true);
    while (_queue.isNotEmpty && enabled) {
      final l = _queue.removeAt(0);
      final started = DateTime.now();
      try {
        if (_idVoices.isNotEmpty) {
          final idx = l.gender == Gender.female ? 0 : (_idVoices.length > 1 ? 1 : 0);
          await _tts.setVoice(_idVoices[idx]);
        }
        await _tts.setPitch(l.gender == Gender.female ? 1.3 : 0.78);
        await _tts.setSpeechRate(l.gender == Gender.female ? 0.52 : 0.47);
        await _tts.setVolume(volume);
        await _tts.speak(l.text).timeout(const Duration(seconds: 14));
      } catch (_) {}
      // cadangan: bila plugin tidak menunggu selesai, tunggu perkiraan durasi bicara
      final est = Duration(milliseconds: 500 + l.text.length * 62);
      final el = DateTime.now().difference(started);
      if (el < est * 0.6) await Future<void>.delayed(est - el);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    _running = false;
    onSpeaking?.call(false);
  }
}
