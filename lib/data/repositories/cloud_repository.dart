import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/game_snapshot.dart';
import '../models/leaderboard_entry.dart';

abstract class CloudRepository {
  Future<GameSnapshot?> loadSave(String uid);
  Future<void> saveProgress(AppUser user, GameSnapshot s, {String? city});
  Future<List<LeaderboardEntry>> topPlayers({String? city, int limit = 20});
  Future<void> deletePlayer(String uid);
}

class FirestoreCloudRepository implements CloudRepository {
  final _col = FirebaseFirestore.instance.collection('players');

  @override
  Future<GameSnapshot?> loadSave(String uid) async {
    final doc = await _col.doc(uid).get();
    final data = doc.data();
    final save = data?['save'];
    if (save is Map) return GameSnapshot.fromJson(Map<String, dynamic>.from(save));
    return null;
  }

  @override
  Future<void> saveProgress(AppUser user, GameSnapshot s, {String? city}) {
    return _col.doc(user.uid).set({
      'name': user.displayName,
      'level': s.level,
      'totalEarned': s.totalEarned,
      'served': s.served,
      if (city != null) 'city': city,
      'updatedAt': FieldValue.serverTimestamp(),
      'save': s.toJson(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<LeaderboardEntry>> topPlayers({String? city, int limit = 20}) async {
    Query<Map<String, dynamic>> q = _col;
    if (city != null && city.isNotEmpty) q = q.where('city', isEqualTo: city);
    final snap = await q.orderBy('totalEarned', descending: true).limit(limit).get();
    return snap.docs.map((d) => LeaderboardEntry.fromMap(d.id, d.data())).toList();
  }

  @override
  Future<void> deletePlayer(String uid) => _col.doc(uid).delete();
}

class NoopCloudRepository implements CloudRepository {
  @override
  Future<void> deletePlayer(String uid) async {}
  @override
  Future<GameSnapshot?> loadSave(String uid) async => null;
  @override
  Future<void> saveProgress(AppUser user, GameSnapshot s, {String? city}) async {}
  @override
  Future<List<LeaderboardEntry>> topPlayers({String? city, int limit = 20}) async => [];
}
