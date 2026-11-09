import 'package:flutter/foundation.dart';
import '../data/models/game_snapshot.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/cloud_repository.dart';
import '../data/repositories/game_repository.dart';

class LobbyViewModel extends ChangeNotifier {
  LobbyViewModel(this._repo, this._cloud, this._auth);

  final GameRepository _repo;
  final CloudRepository _cloud;
  final AuthRepository _auth;

  GameSnapshot snapshot = GameSnapshot();
  bool loading = true;
  bool syncing = false;

  String get playerName => _auth.currentUser?.displayName ?? 'Barista';
  bool get cloudAvailable => _auth.cloudAvailable;

  Future<void> init() async {
    snapshot = await _repo.load();
    loading = false;
    notifyListeners();
    await _syncWithCloud();
  }

  /// Ambil save cloud; pakai yang progresnya lebih jauh (totalEarned lebih besar).
  Future<void> _syncWithCloud() async {
    final user = _auth.currentUser;
    if (user == null || user.isLocalOnly) return;
    syncing = true;
    notifyListeners();
    try {
      final remote = await _cloud.loadSave(user.uid);
      if (remote != null && remote.totalEarned > snapshot.totalEarned) {
        await _repo.save(remote);
        snapshot = remote;
      } else if (snapshot.hasProgress) {
        await _cloud.saveProgress(user, snapshot, city: _repo.cachedCity);
      }
    } catch (_) {
      // offline: abaikan, background task akan menyinkronkan nanti
    }
    syncing = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    snapshot = await _repo.load();
    notifyListeners();
  }

  Future<void> newGame() async {
    await _repo.clear();
    snapshot = GameSnapshot();
    notifyListeners();
  }
}
