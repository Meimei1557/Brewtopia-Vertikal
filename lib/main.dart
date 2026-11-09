import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app/di.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/audio_service.dart';
import 'core/background_service.dart';
import 'core/voice_service.dart';
import 'viewmodels/auth_view_model.dart';
import 'viewmodels/settings_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Firebase: bila google-services.json belum ada, app tetap jalan (mode offline).
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase belum dikonfigurasi, mode offline: $e');
  }

  await setupDependencies(firebaseReady: firebaseReady);
  await getIt<AudioService>().init();
  await getIt<VoiceService>().init();
  await BackgroundService.init(); // daftarkan WorkManager (pendapatan pasif)

  runApp(const BrewtopiaApp());
}

class BrewtopiaApp extends StatefulWidget {
  const BrewtopiaApp({super.key});

  @override
  State<BrewtopiaApp> createState() => _BrewtopiaAppState();
}

class _BrewtopiaAppState extends State<BrewtopiaApp> with WidgetsBindingObserver {
  late final AuthViewModel _auth = getIt<AuthViewModel>();
  late final GoRouter _router = createRouter(_auth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // musik mengecil saat dialog diucapkan
    getIt<VoiceService>().onSpeaking = (s) => getIt<AudioService>().duck(s);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Saat app ke background (ditekan Home / pindah app), musik & suara ikut berhenti.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = getIt<AudioService>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      audio.pauseAll();
      getIt<VoiceService>().stop();
    } else if (state == AppLifecycleState.resumed) {
      audio.resumeAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: _auth),
        ChangeNotifierProvider<SettingsViewModel>.value(value: getIt<SettingsViewModel>()),
      ],
      child: MaterialApp.router(
        title: 'Brewtopia',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
      ),
    );
  }
}
