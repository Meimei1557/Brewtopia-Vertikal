import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_view_model.dart';
import '../viewmodels/gameplay_view_model.dart';
import '../viewmodels/leaderboard_view_model.dart';
import '../viewmodels/lobby_view_model.dart';
import '../viewmodels/locations_view_model.dart';
import '../views/game_screen.dart';
import '../views/leaderboard_screen.dart';
import '../views/lobby_screen.dart';
import '../views/locations_screen.dart';
import '../views/login_screen.dart';
import '../views/settings_screen.dart';
import '../views/splash_screen.dart';
import 'di.dart';

class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const lobby = '/lobby';
  static const game = '/game';
  static const leaderboard = '/leaderboard';
  static const settings = '/settings';
  static const locations = '/locations';
}

/// Navigasi deklaratif + auth guard (redirect otomatis mengikuti status login).
GoRouter createRouter(AuthViewModel auth) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!auth.initialized) return Routes.splash;
      if (!auth.isSignedIn) return loc == Routes.login ? null : Routes.login;
      if (loc == Routes.splash || loc == Routes.login) return Routes.lobby;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: Routes.lobby,
        builder: (_, __) => ChangeNotifierProvider<LobbyViewModel>(
          create: (_) => getIt<LobbyViewModel>()..init(),
          child: const LobbyScreen(),
        ),
      ),
      GoRoute(
        path: Routes.game,
        builder: (_, __) => ChangeNotifierProvider<GameplayViewModel>(
          create: (_) => getIt<GameplayViewModel>(),
          child: const GameScreen(),
        ),
      ),
      GoRoute(
        path: Routes.leaderboard,
        builder: (_, __) => ChangeNotifierProvider<LeaderboardViewModel>(
          create: (_) => getIt<LeaderboardViewModel>()..load(),
          child: const LeaderboardScreen(),
        ),
      ),
      GoRoute(
        path: Routes.locations,
        builder: (_, __) => ChangeNotifierProvider<LocationsViewModel>(
          create: (_) => getIt<LocationsViewModel>()..init(),
          child: const LocationsScreen(),
        ),
      ),
      GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
    ],
  );
}
