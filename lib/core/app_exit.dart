import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../app/di.dart';
import 'audio_service.dart';
import 'voice_service.dart';

/// Keluar dari aplikasi dengan benar: hentikan musik & suara, tutup aktivitas, paksa keluar bila perlu.
Future<void> exitApp() async {
  try {
    await getIt<AudioService>().stopMusic();
    await getIt<VoiceService>().stop();
  } catch (_) {}
  await SystemNavigator.pop();
  Timer(const Duration(milliseconds: 450), () => exit(0));
}
