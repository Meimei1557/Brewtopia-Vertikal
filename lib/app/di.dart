import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/audio_service.dart';
import '../core/location_service.dart';
import '../core/notification_service.dart';
import '../core/system_volume.dart';
import '../core/voice_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/gameplay_view_model.dart';
import '../viewmodels/leaderboard_view_model.dart';
import '../viewmodels/lobby_view_model.dart';
import '../viewmodels/locations_view_model.dart';
import '../viewmodels/settings_view_model.dart';

final GetIt getIt = GetIt.instance;

/// Dependency Injection: semua service/repository/viewmodel didaftarkan di sini.
Future<void> setupDependencies({required bool firebaseReady}) async {
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // Services
  getIt.registerLazySingleton<AudioService>(() => AudioService(getIt()));
  getIt.registerLazySingleton<VoiceService>(() => VoiceService(getIt()));
  getIt.registerLazySingleton<SystemVolume>(() => SystemVolume());
  getIt.registerLazySingleton<LocationService>(() => LocationService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());

  // Repositories (abstraksi -> implementasi; mudah diganti saat testing)
  getIt.registerLazySingleton<GameRepository>(() => LocalGameRepository(getIt()));
  getIt.registerLazySingleton<AuthRepository>(() =>
      firebaseReady ? FirebaseAuthRepository() : OfflineAuthRepository());
  getIt.registerLazySingleton<CloudRepository>(() =>
      firebaseReady ? FirestoreCloudRepository() : NoopCloudRepository());

  // ViewModels
  getIt.registerLazySingleton<AuthViewModel>(() => AuthViewModel(getIt()));
  getIt.registerLazySingleton<SettingsViewModel>(() => SettingsViewModel(
      getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));
  getIt.registerFactory<LobbyViewModel>(() => LobbyViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory<LocationsViewModel>(() => LocationsViewModel(getIt(), getIt()));
  getIt.registerFactory<GameplayViewModel>(
      () => GameplayViewModel(getIt(), getIt(), getIt()));
  getIt.registerFactory<LeaderboardViewModel>(
      () => LeaderboardViewModel(getIt(), getIt(), getIt()));
}
