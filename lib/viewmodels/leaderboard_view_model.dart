import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/leaderboard_entry.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';

enum LeaderboardStatus { loading, data, empty, error, unavailable }

class LeaderboardViewModel extends ChangeNotifier {
  LeaderboardViewModel(this._cloud, this._auth, this._prefs);
  final CloudRepository _cloud;
  final AuthRepository _auth;
  final SharedPreferences _prefs;

  LeaderboardStatus status = LeaderboardStatus.loading;
  List<LeaderboardEntry> entries = [];
  bool cityOnly = false;

  String? get city => _prefs.getString(PrefKeys.cloudCity);
  String? get myUid => _auth.currentUser?.uid;

  Future<void> load() async {
    if (!_auth.cloudAvailable) {
      status = LeaderboardStatus.unavailable;
      notifyListeners();
      return;
    }
    status = LeaderboardStatus.loading;
    notifyListeners();
    try {
      entries = await _cloud.topPlayers(city: cityOnly ? city : null);
      status = entries.isEmpty ? LeaderboardStatus.empty : LeaderboardStatus.data;
    } catch (_) {
      status = LeaderboardStatus.error;
    }
    notifyListeners();
  }

  Future<void> setCityOnly(bool v) async {
    cityOnly = v;
    await load();
  }
}
